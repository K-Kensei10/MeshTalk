package com.example.meshtalk

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattServer
import android.bluetooth.le.*
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
import android.os.Handler
import android.os.Looper
import java.util.*
import android.os.ParcelUuid
import android.content.Context
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.util.Log
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString // encodeToStringを明示的にインポート

// --- MessageBridge (変更なし) ---
object MessageBridge {
    private val messageQueue = mutableListOf<String>()
    private var activityHandler: ((jsonData: String) -> Unit)? = null
    fun onMessageReceived(jsonData: String) {
        activityHandler?.let { handler ->
            handler(jsonData)
        } ?: run {
            messageQueue.add(jsonData)
        }
    }
    fun registerActivityHandler(handler: (jsonData: String) -> Unit) {
        Log.d("MessageBridge", "🟢 担当者（UI）が出社し、連絡先を登録しました。")
        activityHandler = handler
        if (messageQueue.isNotEmpty()) {
            Log.d("MessageBridge", "📬 待合室に溜まっていた ${messageQueue.size} 件のメッセージを処理します。")
            messageQueue.forEach { jsonData ->
                handler(jsonData)
            }
            messageQueue.clear()
        }
    }
}

// --- DisasterMessage (変更なし) ---
@Serializable
data class DisasterMessage(
    @SerialName("MD") val messageContent: String,
    @SerialName("t_p_n") val toPhoneNumber: String,
    @SerialName("type") val messageType: String,
    @SerialName("f_p_n") val fromPhoneNumber: String,
    @SerialName("TTL") val timeToLive: Int
)

// --- UUIDs (変更なし) ---
val ConnectUUID = ParcelUuid.fromString("86411acb-96e9-45a1-90f2-e392533ef877")
val READ_CHARACTERISTIC_UUID = ParcelUuid.fromString("a3f9c1d2-96e9-45a1-90f2-e392533ef877")
val WRITE_CHARACTERISTIC_UUID = ParcelUuid.fromString("7e4b8a90-96e9-45a1-90f2-e392533ef877")
val NOTIFY_CHARACTERISTIC_UUID = ParcelUuid.fromString("1d2e3f4a-96e9-45a1-90f2-e392533ef877")

// --- BluetoothLeController (変更なし) ---
class BluetoothLeController(public val activity : Activity) {
    private val bluetoothManager = activity.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val context: Context = activity
    private var isScanning : Boolean = false
    private var isAdvertising : Boolean  = false
    private val handler = Handler(Looper.getMainLooper())
    private val adapter: BluetoothAdapter? = bluetoothManager.adapter
    private val scanner: BluetoothLeScanner? = adapter?.bluetoothLeScanner
    private val advertiser: BluetoothLeAdvertiser? = adapter?.bluetoothLeAdvertiser
    private var bluetoothGatt: BluetoothGatt? = null
    private lateinit var mGattServerCallback : BluetoothGattServerCallback
    private val GattServer: BluetoothGattServer?
    var scanResults = mutableListOf<ScanResult>()
    private lateinit var mScanCallback : ScanCallback
    private lateinit var mAdvertiseCallback : AdvertiseCallback
    init {
        adapter?.name = "AL"
        mGattServerCallback = object : BluetoothGattServerCallback() { /* ... */ }
        GattServer = bluetoothManager.openGattServer(context, mGattServerCallback)
    }

    private val SCAN_PERIOD: Long = 3000
    private val ADVERTISE_PERIOD: Long = 60 * 1000

    fun scanLeDevice(onResult: (Map<String, String>) -> Unit) {
        if (adapter?.isEnabled != true) {
            onResult(mapOf("status" to "Bluetooth_off", "message" to "Bluetoothがオフになっています。設定からオンにしてください。"))
            return
        }
        checkPermissions(context) { permissionResult ->
            if (permissionResult != null) {
                onResult(mapOf("status" to "no_permissions", "message" to "通信に必要な権限がありません。設定から許可してください。"))
            }
        }
        scanResults.clear()
        if(!isScanning) {
            handler.postDelayed({
                try{
                    scanner?.stopScan(mScanCallback)
                    isScanning = false
                    Log.d("BLE","スキャンストップ")
                    if (scanResults.isEmpty()) {
                        Log.d("BLE", "検出されたデバイスはありません")
                        onResult(mapOf("status" to "device_not_found", "message" to "通信相手が見つかりませんでした。近くにあるか確認してください。"))
                    } else {
                        for (result in scanResults) {
                            val name = result.scanRecord?.deviceName ?: result.device.name ?: "Unknown"
                            val address = result.device.address
                            Log.d("BLE", "デバイス名: $name, アドレス: $address")
                            onResult(mapOf("status" to "scan_successful", "message" to "デバイスのスキャン完了"))
                            try {
                                connect(address)
                            } catch(e: Exception){
                                onResult(mapOf("status" to "Gatt_start_failed", "message" to "通信を正しく開始することができませんでした: ${e.message}"))
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("BLE", "スキャン停止時に例外: ${e.message}")
                }
            }, SCAN_PERIOD)
            isScanning = true
            val scanSettings: ScanSettings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
            val scanFilterList = arrayListOf<ScanFilter>()
            val scanUuidFilter : ScanFilter = ScanFilter.Builder().setServiceUuid(ConnectUUID).build()
            scanFilterList.add(scanUuidFilter)
            mScanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int,result:ScanResult) {
                    if (result.rssi >= -90 && scanResults.none { it.device.address == result.device.address }) {
                        scanResults.add(result)
                    }
                }
                override fun onScanFailed(errorCode: Int) {
                    super.onScanFailed(errorCode)
                    onResult(mapOf("status" to "scan_failed", "message" to "通信の準備に失敗しました。（コード: $errorCode）"))
                }
            }
            if (!isScanning || scanner == null) {
                onResult(mapOf("status" to "app_error", "message" to "通信中に予期せぬエラーが発生しました。"))
                return
            }
            scanner.stopScan(mScanCallback)
            scanner.startScan(scanFilterList,scanSettings,mScanCallback)
        } else {
            onResult(mapOf("status" to "scan_failed", "message" to "スキャンは既に実行されています"))
        }
    }

    fun startAdvertising(onResult: (Map<String, String>) -> Unit) {
        if (advertiser == null) {
            onResult(mapOf("status" to "not_use_ble", "message" to "この端末はBLE通信に対応していません。"))
            return
        }
        checkPermissions(context) { result ->
            if (result != null) {
                onResult(mapOf("status" to "no_permissions", "message" to "権限が不足しています"))
                return@checkPermissions
            }
        }
        if (adapter?.isEnabled != true) {
            onResult(mapOf("status" to "Bluetooth_off", "message" to "BluetoothがOFFになっています"))
            return
        }
        val advertiseSetting = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .build()
        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ConnectUUID)
            .build()
        mAdvertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                onResult(mapOf("status" to "advertise_started", "message" to "アドバタイズを開始しました"))
                handler.postDelayed({
                    advertiser.stopAdvertising(mAdvertiseCallback)
                    onResult(mapOf("status" to "advertise_stopped", "message" to "アドバタイズは正常に終了しました。"))
                },ADVERTISE_PERIOD)
            }
            override fun onStartFailure(errorCode: Int) {
                onResult(mapOf("status" to "advertise_failed", "message" to "通信の開始に失敗しました。（コード: $errorCode）"))
            }
        }
        advertiser.stopAdvertising(mAdvertiseCallback)
        advertiser.startAdvertising(advertiseSetting, advertiseData, mAdvertiseCallback)
    }

    private fun connect(address: String) {
        val device: BluetoothDevice? = adapter?.getRemoteDevice(address)
        Log.d("Gatt","デバイスと通信開始")
        bluetoothGatt = device?.connectGatt(context, false, bluetoothGattCallback)
    }

    private val bluetoothGattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt,status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d("Gatt","接続成功")
                bluetoothGatt?.discoverServices()
            }
        }
        override fun onServicesDiscovered(gatt: BluetoothGatt,status: Int) {
            super.onServicesDiscovered(gatt, status)
            Log.d("Gatt","サービス検出 gatt: $gatt, status: $status")
        }
    }
}

// --- checkPermissions (変更なし) ---
fun checkPermissions(context: Context, onResult: (String?) -> Unit) {
    val requiredPermissions = listOf(
        Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADVERTISE,
        Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.POST_NOTIFICATIONS
    )
    val missing = requiredPermissions.filter {
        ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
    }
    if (missing.isEmpty()) {
        onResult(null)
    } else {
        onResult("Missing permissions: ${missing.joinToString(", ")}")
    }
}

// 🏠🏠🏠 ここからが MainActivity 🏠🏠🏠
class MainActivity : FlutterActivity() {
    private val CHANNEL = "meshtalk.flutter.dev/contact"
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            val bleController = BluetoothLeController(this)
            when (call.method) {
                "sendMessage" -> {
                    val message = call.argument<String>("message") ?: ""
                    val phoneNum = call.argument<String>("phoneNum") ?: ""
                    val messageType = call.argument<String>("messageType") ?: ""
                    val targetPhoneNum = call.argument<String>("targetPhoneNum") ?: ""
                    val TTL = 150
                    val separator = "*****"
                    val disaster_message_data = messageType + separator + phoneNum + separator + targetPhoneNum + separator + TTL + separator + message
                    Log.d("MainActivity", disaster_message_data)
                    bleController.scanLeDevice { resultMap ->
                         when (resultMap["status"]) {
                            "scan_successful" -> result.success(resultMap["message"])
                            else -> result.error(resultMap["status"]?.uppercase() ?: "UNKNOWN_ERROR", resultMap["message"], null)
                        }
                    }
                }
                "startAdvertising" -> {
                    bleController.startAdvertising { resultMap ->
                        when (resultMap["status"]) {
                            "advertise_started", "advertise_stopped" -> result.success(resultMap["message"])
                            else -> result.error(resultMap["status"]?.uppercase() ?: "UNKNOWN_ERROR", resultMap["message"], null)
                        }
                    }
                }

                "routeToMessageBridge" -> {
                     val data = call.argument<String>("data")
                    if (data != null) {
                        MessageBridge.onMessageReceived(data)
                        result.success("メッセージをキューに転送しました。")
                    } else {
                        result.error("DATA_NULL", "データがありません。", null)
                    }
                }
                else -> result.notImplemented()
            }
        } 

        MessageBridge.registerActivityHandler { jsonData ->
            runOnUiThread {
                message_separate_Json(jsonData)
            }
        }
    } 

    private fun message_separate_Json(jsonData: String) {
        println("▶️ データ処理を開始します...")
        try {
            val packet = Json.decodeFromString<DisasterMessage>(jsonData)
            val MY_PHONE_NUMBER = "01234567890" // 例
            println("📦 [受信] type:${packet.messageType}, to:${packet.toPhoneNumber}, from:${packet.fromPhoneNumber}, TTL:${packet.timeToLive}")
            when (packet.messageType) {
                "1" -> {
                    println(" [処理]Type 1 (SNS) を受信")
                    displayMessageOnFlutter(packet)
                    if (packet.timeToLive > 0) {
                        println("TTLが残っているため、他の端末へ転送します。")
                        relayMessage(packet)
                    }
                }
                "2" -> {
                    if (packet.toPhoneNumber == MY_PHONE_NUMBER) {
                        println(" [処理]Type 2 (自分宛)を受信")
                        displayMessageOnFlutter(packet)
                    } else {
                        println("   -> 宛先が違うため、転送のみ行います。")
                        if (packet.timeToLive > 0){
                            relayMessage(packet)
                            println("   -> TTLが残っているため、他の端末へ転送します。")
                        }
                    }
                }
                "3" -> {
                    println("✅ [処理]Type 3: 転送処理を行います。")
                    if (packet.timeToLive > 0){
                        relayMessage(packet)
                        println("   -> TTLが残っているため、他の端末へ転送します。")
                    }
                }
                "4" -> {
                    println("[処理]Type 4: Flutterに表示")
                    displayMessageOnFlutter(packet)
                    if (packet.timeToLive > 0){
                        relayMessage(packet)
                        println("   -> TTLが残っているため、他の端末へ転送します。")
                    }
                }
                else -> println(" [不明] メッセージタイプです。")
            }
            println("✅ データ処理が完了しました。")
        } catch (e: Exception) {
            println("❗️ データ処理中にエラーが発生しました: ${e.message}")
        }
    }

    private fun displayMessageOnFlutter(packet: DisasterMessage) {
        val dataForFlutter = mapOf(
            "type" to packet.messageType,
            "message" to packet.messageContent,
            "from" to packet.fromPhoneNumber
        )
        runOnUiThread {
            channel.invokeMethod("displayMessage", dataForFlutter)
        }
    }

    // ✨✨✨ ここが修正された関数です ✨✨✨
    private fun relayMessage(receivedPacket: DisasterMessage) {
        val newTtl = receivedPacket.timeToLive - 1
        println("✈️ [転送処理] TTLを ${receivedPacket.timeToLive} から $newTtl に変更します。")
        val packetToRelay = receivedPacket.copy(timeToLive = newTtl)
        
        // 正しい「鍵」である DisasterMessage.serializer() を第一引数に渡します
        val jsonToRelay = Json.encodeToString(DisasterMessage.serializer(), packetToRelay)
        
        println("転送用のJSON文字列: $jsonToRelay")
        // TODO: Bluetooth送信関数を呼び出す
    }
}