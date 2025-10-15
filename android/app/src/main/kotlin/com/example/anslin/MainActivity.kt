package com.example.meshtalk

import androidx.annotation.NonNull;
import androidx.core.os.postDelayed;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.le.*;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothProfile;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import java.security.Policy;
import java.util.*;
import android.os.ParcelUuid;
import android.content.Context;
import android.Manifest;
import android.content.pm.PackageManager;
import androidx.core.content.ContextCompat;


import android.util.Log

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString

object MessageBridge {

    //メッセージを一時的に保管
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
        activityHandler = handler

        if (messageQueue.isNotEmpty()) {

            messageQueue.forEach { jsonData ->
                handler(jsonData)
            }
            messageQueue.clear()
        }
    }
}

@Serializable
data class DisasterMessage(
    @SerialName("MD")
    val messageContent: String,

    @SerialName("t_p_n")
    val toPhoneNumber: String,

    @SerialName("type")
    val messageType: String,

    @SerialName("f_p_n")
    val fromPhoneNumber: String,

    @SerialName("TTL")
    val timeToLive: Int
)

val ConnectUUID = ParcelUuid.fromString("86411acb-96e9-45a1-90f2-e392533ef877")
val READ_CHARACTERISTIC_UUID = ParcelUuid.fromString("a3f9c1d2-96e9-45a1-90f2-e392533ef877")
val WRITE_CHARACTERISTIC_UUID = ParcelUuid.fromString("7e4b8a90-96e9-45a1-90f2-e392533ef877")
val NOTIFY_CHARACTERISTIC_UUID = ParcelUuid.fromString("1d2e3f4a-96e9-45a1-90f2-e392533ef877")

//BLT class
class BluetoothLeController(public val activity : Activity) {
    private val bluetoothManager = activity.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val context: Context = activity
    private var isScanning : Boolean = false
    private var isAdvertising : Boolean  = false
    private var scanFilter: ScanFilter? = null
    private val handler = Handler(Looper.getMainLooper())
    private val adapter: BluetoothAdapter? = bluetoothManager.adapter
    private val scanner: BluetoothLeScanner? = adapter?.bluetoothLeScanner
    private val advertiser: BluetoothLeAdvertiser? = adapter?.bluetoothLeAdvertiser
    private var bluetoothGatt: BluetoothGatt? = null
    private val GattServer: BluetoothGattServer?
    var scanResults = mutableListOf<ScanResult>()
    private lateinit var mScanCallback : ScanCallback
    private lateinit var mAdvertiseCallback : AdvertiseCallback
    private lateinit var mGattServerCallback : BluetoothGattServerCallback
    init {
        adapter?.name = "AL"
        // 修正: mGattServerCallbackをGattServerよりも先に初期化します
        mGattServerCallback = object : BluetoothGattServerCallback() {}
        GattServer = bluetoothManager.openGattServer(context,mGattServerCallback)
    }


    //スキャン停止までの時間
    private val SCAN_PERIOD: Long = 3000
    private val ADVERTISE_PERIOD: Long = 60 * 1000

    //================= セントラル（メッセージ受信者） =================
    fun scanLeDevice(onResult: (Map<String, String>) -> Unit) {
        // BluetoothがOnになっているか
        if (adapter?.isEnabled != true) {
            onResult(mapOf(
                "status" to "Bluetooth_off",
                "message" to "Bluetoothがオフになっています。設定からオンにしてください。"
            ))
            return
        }
        //権限チェック
        checkPermissions(context) { permissionResult ->
            if (permissionResult != null) {
                onResult(mapOf(
                    "status" to "no_permissions",
                    "message" to "通信に必要な権限がありません。設定から許可してください。"
                ))
            }
        }
        //スキャン結果リセット
        scanResults.clear()
        if(!isScanning) {
            handler.postDelayed({
                try{
                    scanner?.stopScan(mScanCallback)
                    isScanning = false
                    Log.d("BLE","スキャンストップ")
                    if (scanResults.isEmpty()) {
                        Log.d("BLE", "検出されたデバイスはありません")
                        onResult(mapOf(
                            "status" to "device_not_found",
                            "message" to "通信相手が見つかりませんでした。近くにあるか確認してください。"
                        ))
                    }else {
                        for (result in scanResults) {
                            val name = result.scanRecord?.deviceName ?: result.device.name ?: "Unknown"
                            val uuids = result.scanRecord?.serviceUuids
                            val address = result.device.address
                            val rssi = result.rssi
                            Log.d("BLE", "デバイス名: $name, アドレス: $address, RSSI: $rssi, UUID: $uuids")
                            onResult(mapOf(
                                "status" to "scan_successful",
                                "message" to "デバイスのスキャン完了"
                            ))
                            //Gatt通信開始
                            try {
                                connect(address)
                            }catch(e: Exception){
                                onResult(mapOf(
                                    "status" to "Gatt_start_failed",
                                    "message" to "通信を正しく開始することができませんでした: ${e.message}"
                                ))
                            }
                        }
                    }
                }catch (e: Exception) {
                    Log.e("BLE", "スキャン停止時に例外: ${e.message}")
                }
            }, SCAN_PERIOD)
            isScanning = true

            //スキャン設定
            val scanSettings: ScanSettings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
                .build()

            val scanFilterList = arrayListOf<ScanFilter>()
            val scanUuidFilter : ScanFilter = ScanFilter.Builder()
                .setServiceUuid(ConnectUUID)
                .build()
            scanFilterList.add(scanUuidFilter)

            //コールバック
            mScanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int,result:ScanResult) {
                    Log.d("BLE","$result")
                    //前に取得したことがない&&信号強度が強いもののみ
                    if (result.rssi >= -90 && scanResults.none { it.device.address == result.device.address }) {
                        val uuids = result.scanRecord?.serviceUuids
                        if (uuids?.contains(ConnectUUID) == true) {
                            Log.d("BLE","$result")
                        }
                        scanResults.add(result)
                    }
                }
                override fun onScanFailed(errorCode: Int) {
                    super.onScanFailed(errorCode)
                    Log.d("BLE","スキャンに失敗しました（コード: $errorCode）")
                    onResult(mapOf(
                        "status" to "scan_failed",
                        "message" to "通信の準備に失敗しました。もう一度お試しください。（コード: $errorCode）"
                    ))
                }
            }
            if (!isScanning || scanner == null) {
                onResult(mapOf(
                    "status" to "app_error",
                    "message" to "通信中に予期せぬエラーが発生しました。アプリを再起動してください。"
                ))
                return
            }
            scanner.stopScan(mScanCallback)
            scanner.startScan(scanFilterList,scanSettings,mScanCallback)
        }else{
            Log.d("BLE","スキャンは既に実行されています")
            onResult(mapOf(
                "status" to "scan_failed",
                "message" to "スキャンは既に実行されています"
            ))
        }
    }


    //================= ペリフェラル（メッセージ送信者） =================
    fun startAdvertising(onResult: (Map<String, String>) -> Unit) {
        if (advertiser == null) {
            Log.e("BLE_AD", "このデバイスはBLEアドバタイズに対応していません")
            onResult(mapOf(
                "status" to "not_use_ble",
                "message" to "この端末はBLE通信に対応していません。"
            ))
            return
        }

        checkPermissions(context) { result ->
            if (result != null) {
                onResult(mapOf(
                    "status" to "no_permissions",
                    "message" to "権限が不足しています"
                ))
                return@checkPermissions // ← このラムダだけ抜ける = この関数だけ実行しない
            }
        }
        // BluetoothがOnになっているか
        if (adapter?.isEnabled != true) {
            onResult(mapOf(
                "status" to "Bluetooth_off",
                "message" to "BluetoothがOFFになっています"
            ))
            return
        }

        //アドバタイズ設定
        val advertiseSetting = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .build()

        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ConnectUUID)
            .build()

        //コールバック
        mAdvertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.d("BLE_AD", "アドバタイズ開始成功")
                onResult(mapOf(
                    "status" to "advertise_started",
                    "message" to "アドバタイズを開始しました"
                ))
                handler.postDelayed({
                    advertiser.stopAdvertising(mAdvertiseCallback)
                    Log.e("BLE_AD", "アドバタイズの停止")
                    onResult(mapOf(
                        "status" to "advertise_stopped",
                        "message" to "アドバタイズは正常に終了しました。"
                    ))
                },ADVERTISE_PERIOD)
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e("BLE_AD", "アドバタイズ失敗: $errorCode")
                onResult(mapOf(
                    "status" to "advertise_failed",
                    "message" to "通信の開始に失敗しました。もう一度お試しください。（コード: $errorCode）"
                ))
            }
        }
        advertiser.stopAdvertising(mAdvertiseCallback)
        advertiser.startAdvertising(advertiseSetting, advertiseData, mAdvertiseCallback)
    }
    //================= GATT通信 =================
    //TODOTODOTODOTODO
    private fun connect(address: String) {
        val device: BluetoothDevice? = adapter?.getRemoteDevice(address)
        Log.d("Gatt","デバイスと通信開始")
        bluetoothGatt = device?.connectGatt(context, false, bluetoothGattCallback)
    }

    //Gatt接続、コールバック
    private val bluetoothGattCallback = object : BluetoothGattCallback() {

        //ペリフェラルとの接続状態が変化したとき
        override fun onConnectionStateChange(gatt: BluetoothGatt,status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d("Gatt","接続成功")
                bluetoothGatt?.discoverServices()
            }
        }

        //サービスが検出されたとき
        override fun onServicesDiscovered(gatt: BluetoothGatt,status: Int) {
            super.onServicesDiscovered(gatt, status)
            Log.d("Gatt","サービス検出 gatt: $gatt, status: $status")
            //対象のサービスの取得
        }
    }

}


//================= スキャン =================
fun checkPermissions(context: Context, onResult: (String?) -> Unit) {
    val requiredPermissions = listOf(
        Manifest.permission.BLUETOOTH,
        Manifest.permission.BLUETOOTH_ADVERTISE,
        Manifest.permission.BLUETOOTH_CONNECT,
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.POST_NOTIFICATIONS
    )

    val missing = requiredPermissions.filter {
        ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
    }

    if (missing.isEmpty()) {
        onResult(null) // すべて許可されているとき
    } else {
        val message = "Missing permissions: ${missing.joinToString(", ")}"
        onResult(message)
    }
}


class MainActivity : FlutterActivity() {
    private val CHANNEL = "meshtalk.flutter.dev/contact"
    private lateinit var channel: MethodChannel
    //FlutterとKotlin間の通信チャネルを設定

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMessage" -> {
                    //["message", "to_phone_number", "message_type", "from_phone_number", "TTL"]に変える
                    val message = call.argument<String>("message") ?: ""
                    val phoneNum = call.argument<String>("phoneNum") ?: ""
                    val messageType = call.argument<String>("messageType") ?: ""
                    val targetPhoneNum = call.argument<String>("targetPhoneNum") ?: ""
                    val TTL = 150
                    val separator = "*****"

                    val disaster_message_data = messageType + separator + phoneNum +separator + targetPhoneNum + separator + TTL + separator + message
                    Log.d("MainActivity", disaster_message_data)
                    val bleController = BluetoothLeController(this)
                    bleController.scanLeDevice { resultMap ->
                        when (resultMap["status"]) {
                            "scan_successful" -> {
                                result.success(resultMap["message"])
                            }
                            "device_not_found" -> {
                                result.error("DEVICE_NOT_FOUND", resultMap["message"], null)
                            }
                            "app_error" -> {
                                result.error("APP_ERROR", resultMap["message"], null)
                            }
                            "Bluetooth_off" -> {
                                result.error("BLUETOOTH_OFF", resultMap["message"], null)
                            }
                            "no_permissions" -> {
                                result.error("NO_PERMISSIONS", resultMap["message"], null)
                            }
                            "scan_failed" -> {
                                result.error("SCAN_FAILED", resultMap["message"], null)
                            }
                            "Gatt_start_failed" -> {
                                result.error("GATT_START_FAILED", resultMap["message"], null)
                            }
                            else -> {
                                result.error("UNKNOWN_STATUS", "予期せぬエラーが発生しました。", null)
                            }
                        }
                    }
                }
                "startAdvertising" -> {
                    val bleController = BluetoothLeController(this)
                    bleController.startAdvertising { resultMap ->
                        when (resultMap["status"]) {
                            "advertise_started" -> {
                                result.success(resultMap["message"])
                            }
                            "advertise_failed" -> {
                                result.error("FAILED_ADVERTISING", resultMap["message"], null)
                            }
                            "not_use_ble" -> {
                                result.error("DEVICE_NOT_BLE", resultMap["message"], null)
                            }
                            "no_permissions" -> {
                                result.error("NO_PERMISSIONS", resultMap["message"], null)
                            }
                            "advertise_stopped" -> {
                                result.success(resultMap["message"])
                            }
                            "Bluetooth_off" -> {
                                result.error("BLUETOOTH_OFF", resultMap["message"], null)
                            }
                            else -> {
                                result.error("UNKNOWN_STATUS", "予期せぬエラーが発生しました", null)
                            }
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

    //================= メッセージ処理 =================
    private fun message_separate_Json(jsonData: String) {
        println("▶️ データ処理を開始します...")
        try {
            val packet = Json.decodeFromString<DisasterMessage>(jsonData)

            val message: String = packet.messageContent
            val to_phone_number: String = packet.toPhoneNumber
            val message_type: String = packet.messageType
            val from_phone_number: String = packet.fromPhoneNumber
            val TTL: Int = packet.timeToLive

            val MY_PHONE_NUMBER = "01234567890" // 例として固定値を使用

            println(" [受信] type:$message_type, to:$to_phone_number, from:$from_phone_number, TTL:$TTL")

            when (message_type) {
                "1" -> {// SNS
                    println(" [処理]Type 1 (SNS) を受信")

                    displayMessageOnFlutter(packet) // Flutter側に表示を依頼

                    if (TTL > 0) {
                        println("TTLが残っているため、他の端末へ転送します。")
                        relayMessage(packet)
                    }
                }


                "2" -> {// 宛先指定
                    if (to_phone_number == MY_PHONE_NUMBER) {  // MY_PHONE_NUMBERはアプリ内で定義されていると仮定
                        println(" [処理]Type 2 (自分宛)を受信")

                        displayMessageOnFlutter(packet) // Flutter側に表示を依頼

                        //自治体端末であればデータをためるコードをここに追加
                    } else {
                        println("  -> 宛先が違うため、転送のみ行います。")
                        if (TTL > 0){
                            relayMessage(packet)
                            println("  -> TTLが残っているため、他の端末へ転送します。")
                              }
                    }
                }


                "3" ->  { // 自治体へ
                    println("✅ [処理]Type 3: 転送処理を行います。")
                    //自治体端末である場合、Flutterを呼び出して表示させるコードをここに追加
                    if (TTL > 0){
                        relayMessage(packet)
                        println("  -> TTLが残っているため、他の端末へ転送します。")
                    }
                }


                "4" -> { // 自治体から
                    println("[処理]Type 4: Flutterに表示")

                    displayMessageOnFlutter(packet)

                    if (TTL > 0){
                        relayMessage(packet)
                        println("  -> TTLが残っているため、他の端末へ転送します。")
                    }
                }


                else -> println(" [不明] メッセージタイプです。内容: $message")
            }
            println("✅ データ処理が完了しました。")
        }

        catch (e: Exception) {
            println("❗️ データ処理中にエラーが発生しました: ${e.message}")
        }
    }

    private fun displayMessageOnFlutter(packet: DisasterMessage) {
        val dataForFlutter = mapOf(
            "type" to packet.messageType,
            "message" to packet.messageContent,
            "from" to packet.fromPhoneNumber
            // 他にUI表示で必要なデータがあれば追加
        )
        runOnUiThread {
            channel.invokeMethod("displayMessage", dataForFlutter)
        }
    }
    private fun relayMessage(receivedPacket: DisasterMessage) {

        // 現在のTTLの値を取得し、そこから1を引く
        val newTtl = receivedPacket.timeToLive - 1

        println("[転送処理] TTLを ${receivedPacket.timeToLive} から $newTtl に変更します。")

        // TTLの値だけを新しいものに入れ替えた、メッセージデータの完璧なコピーを作成する
        val packetToRelay = receivedPacket.copy(timeToLive = newTtl)

        // 新しく作成したデータオブジェクトを、送信用のJSON文字列に変換（エンコード）する
        val jsonToRelay = Json.encodeToString(DisasterMessage.serializer(), packetToRelay)

        println("転送用のJSON文字列: $jsonToRelay")

        // TODO: ここにBluetoothでデータを送信する関数を呼び出すコードを書く
    }
}