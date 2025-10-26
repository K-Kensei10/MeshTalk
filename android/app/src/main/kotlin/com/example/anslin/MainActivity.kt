package com.example.anslin

import androidx.annotation.NonNull;
import androidx.core.os.postDelayed;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;
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
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothProfile;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.Parcelable;
import java.security.Policy;
import java.util.*;
import android.os.ParcelUuid;
import android.content.Context;
import android.Manifest;
import android.content.pm.PackageManager;
import androidx.core.content.ContextCompat;


import android.util.Log

val CONNECT_UUID = UUID.fromString("86411acb-96e9-45a1-90f2-e392533ef877")
val READ_CHARACTERISTIC_UUID = UUID.fromString("a3f9c1d2-96e9-45a1-90f2-e392533ef877")
val WRITE_CHARACTERISTIC_UUID = UUID.fromString("7e4b8a90-96e9-45a1-90f2-e392533ef877")
val NOTIFY_CHARACTERISTIC_UUID = UUID.fromString("1d2e3f4a-96e9-45a1-90f2-e392533ef877")

//Flutter
class MainActivity : FlutterActivity() {
  private val CHANNEL = "anslin.flutter.dev/contact"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->
        when (call.method) {
          "startCatchMessage" -> {
            val bleController = BluetoothLeController(this)
            bleController.ScanAndConnect { resultMap ->
              when (resultMap["status"]) {
                "RECEIVE_MESSAGE_SUCCESSFUL" -> {
                    result.success(resultMap["message"])
                }
                "device_not_found" -> {
                    result.error("DEVICE_NOT_FOUND", resultMap["message"], null)
                }
                else -> {
                    result.error("UNKNOWN_STATUS", "予期せぬエラーが発生しました。", null)
                }
              }
            }
          }
          "startSendMessage" -> {
            val messageData = call.arguments as? String
            val bleController = BluetoothLeController(this)
            bleController.SendingMessage(messageData!!) { resultMap ->
              when (resultMap["status"]) {
                "SEND_MESSAGE_SUCCESSFUL" -> {
                    result.success("メッセージが送信されました。")
                }
                "ADVERTISE_FAILED" -> {
                    result.error("FAILED_ADVERTISING", resultMap["message"], null)
                }
                else -> {
                    result.error("UNKNOWN_STATUS", "予期せぬエラーが発生しました", null)
                }
              }
            }
          }
        else -> result.notImplemented()
      }
    }
  }
}


//BLE class
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
  private var scanResults = mutableListOf<ScanResult>()
  private lateinit var mScanCallback : ScanCallback
  private lateinit var mAdvertiseCallback : AdvertiseCallback
  private lateinit var mGattServerCallback : BluetoothGattServerCallback
  private lateinit var mBluetoothGattServer: BluetoothGattServer
  private var scanResultCallback: ((Map<String, String>) -> Unit)? = null
  init {adapter?.name = "AL"}


  //スキャン停止までの時間
  private val SCAN_PERIOD: Long = 3 * 1000
  private val ADVERTISE_PERIOD: Long = 60 * 1000

  //characteristic
  private var readCharacteristic: BluetoothGattCharacteristic? = null
  private var writeCharacteristic: BluetoothGattCharacteristic? = null
  private var notifyCharacteristic: BluetoothGattCharacteristic? = null

  //================= セントラル（メッセージ受信者） =================
  fun ScanAndConnect(onResult: (Map<String, String>) -> Unit) {
    var scanCount = 0
    scanResultCallback = onResult

    //権限チェック
    checkPermissions(context) { PermissionResult ->
      if (PermissionResult != null) {
        Log.d("Scan","通信に必要な権限がありません。設定から許可してください。")
        return@checkPermissions
      }
      // BluetoothがOnになっているか
      if (adapter?.isEnabled != true) {
        Log.d("Scan","BluetoothがOFFになっています。設定からONにしてください。")
      return@checkPermissions
      }
      //スキャン結果リセット
      scanResults.clear()
      //スキャン結果
      if(!isScanning) {
        handler.postDelayed({
          try{
            scanner?.stopScan(mScanCallback)
            isScanning = false
            Log.d("Scan","スキャンストップ")
            if (scanResults.isEmpty()) {
              if (scanCount < 2) {
                Log.d("scan","$scanCount")
                scanCount ++
                startBleScan()
              }else{
                scanResults.clear()
                Log.d("Scan", "検出されたデバイスはありません")
                onResult(mapOf(
                  "status" to "DEVICE_NOT_FOUND",
                  "message" to "デバイスが付近に見つかりませんでした。"
                ))
              }
            }else {
              for (result in scanResults) {//スキャンしたデバイスの数だけ表示する
                val name = result.scanRecord?.deviceName ?: result.device.name ?: "Unknown"
                val uuids = result.scanRecord?.serviceUuids
                val address = result.device.address
                val rssi = result.rssi
                Log.d("Scan", "デバイス名: $name, アドレス: $address, RSSI: $rssi, UUID: $uuids")
                //Gatt通信開始
                try {
                  bluetoothGatt?.disconnect()
                  bluetoothGatt?.close()
                  bluetoothGatt = null
                  connect(address)
                }catch(e: Exception){
                  Log.d("Gatt", "通信を正しく開始することができませんでした: ${e.message}")
                }
              }
            }
          }catch (e: Exception) {
            Log.e("Scan", "スキャン停止時に例外: ${e.message}")
            scanner?.stopScan(mScanCallback)
            isScanning = false
          }
        }, SCAN_PERIOD)
        startBleScan()
      }else{
        Log.d("Scan","予期せぬエラーが発生しました")
      }
    }
  }

  //================= デバイススキャン =================
  fun startBleScan() {
    //スキャン設定
    val scanSettings: ScanSettings = ScanSettings.Builder()
      .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
      .build()
    val scanFilterList = arrayListOf<ScanFilter>()
    val scanUuidFilter : ScanFilter = ScanFilter.Builder()
      .setServiceUuid(ParcelUuid(CONNECT_UUID))
      .build()
    scanFilterList.add(scanUuidFilter)

    //コールバック
    mScanCallback = object : ScanCallback() {
      override fun onScanResult(callbackType: Int,result:ScanResult) {
        Log.d("Scan","$result")
        //前に取得したことがない&&信号強度が強いもののみ
        if (result.rssi >= -100 && scanResults.none { it.device.address == result.device.address }) {
          val uuids = result.scanRecord?.serviceUuids
          if (uuids?.contains(ParcelUuid(CONNECT_UUID)) == true) {
            Log.d("Scan","$result")
          }
          scanResults.add(result)
        }
      }
      override fun onScanFailed(errorCode: Int) {
        super.onScanFailed(errorCode)
        Log.d("Scan","スキャンに失敗しました（コード: $errorCode）")
        isScanning = false
      }
    }
    if (!isScanning || scanner == null) {
      Log.d("Scan","通信中に予期せぬエラーが発生しました。")
      return
    }
    try {
      scanner.stopScan(mScanCallback)
      scanner.startScan(scanFilterList,scanSettings,mScanCallback)
      isScanning = true
    }catch (e: Exception) {
      Log.d("Scan","スキャン開始時に予期せぬエラーが発生しました。${e.message}")
    }
  }


  //================= ペリフェラル（メッセージ送信者） =================
  fun SendingMessage(messageData: String,onResult: (Map<String, String>) -> Unit) {
    //権限チェック
    if (advertiser == null) {
      Log.e("Advertise", "このデバイスはBLEアドバタイズに対応していません")
      return
    }
    checkPermissions(context) { result ->
      if (result != null) {
        Log.d("Advertise","通信に必要な権限がありません。設定から許可してください。")
        return@checkPermissions
      }
      // BluetoothがOnになっているか
      if (adapter?.isEnabled != true) {
        Log.d("Advertise","BluetoothがOFFになっています。設定からONにしてください。")
      return@checkPermissions
      }
      //セントラル側が切断した後の処理
      val mGattServerCallback = object : BluetoothGattServerCallback() {
      override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
        if (newState == BluetoothProfile.STATE_DISCONNECTED) {
          Log.d("GATT", "セントラルが切断しました")
          //変数初期化
          readCharacteristic = null
          writeCharacteristic = null
          notifyCharacteristic = null
          mBluetoothGattServer.clearServices()
          mBluetoothGattServer.close()
          onResult(mapOf(
              "status" to "SEND_MESSAGE_SUCCESSFUL"
          ))
          }else if(newState == BluetoothProfile.STATE_CONNECTED) {
            Log.d("GATT", "セントラルと交信しています")
          }
        }
        override fun onCharacteristicReadRequest(
          device: BluetoothDevice,
          requestId: Int,
          offset: Int,
          characteristic: BluetoothGattCharacteristic
        ) {
          val value = characteristic.value ?: byteArrayOf()
          val responseValue = if (offset < value.size) value.copyOfRange(offset, value.size) else byteArrayOf()
          mBluetoothGattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, responseValue) 
        }
      }
      
      
      //Gatt通信用
      mBluetoothGattServer = bluetoothManager.openGattServer(context, mGattServerCallback)
      //Gattサービスの取得
      var BluetoothGattService = BluetoothGattService(CONNECT_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY);

      //キャラクタリスティック
      writeCharacteristic = BluetoothGattCharacteristic(WRITE_CHARACTERISTIC_UUID, BluetoothGattCharacteristic.PROPERTY_WRITE, BluetoothGattCharacteristic.PERMISSION_WRITE)
      readCharacteristic = BluetoothGattCharacteristic(READ_CHARACTERISTIC_UUID, BluetoothGattCharacteristic.PROPERTY_READ, BluetoothGattCharacteristic.PERMISSION_READ)

      //メッセージデータの書き込み
      //message, to_phone_number, message_type, from_phone_number, TTL
      readCharacteristic?.let { readChar ->
        readChar.value = messageData.toByteArray(Charsets.UTF_8)
      }
      
      // サービスに追加
      BluetoothGattService.addCharacteristic(readCharacteristic)
      BluetoothGattService.addCharacteristic(writeCharacteristic)


      //Gattキャラクタリスティックの追加
      mBluetoothGattServer.addService(BluetoothGattService)

      //アドバタイズ設定
      val advertiseSetting = AdvertiseSettings.Builder()
          .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
          .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
          .setConnectable(true)
          .build()

      val advertiseData = AdvertiseData.Builder()
          .setIncludeDeviceName(true)
          .addServiceUuid(ParcelUuid(CONNECT_UUID))
          .build()

      //コールバック
      mAdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
          handler.postDelayed({
            advertiser.stopAdvertising(mAdvertiseCallback)
            Log.e("Advertise", "アドバタイズの停止")
          },ADVERTISE_PERIOD)
        }
        override fun onStartFailure(errorCode: Int) {
          Log.e("Advertise", "アドバタイズ失敗: $errorCode")
          advertiser.stopAdvertising(mAdvertiseCallback)
          onResult(mapOf(
            "status" to "ADVERTISE_FAILED",
            "message" to "通信の開始に失敗しました。もう一度お試しください。（コード: $errorCode）"
          ))
        }
      }
      advertiser.stopAdvertising(mAdvertiseCallback)
      handler.postDelayed({
        advertiser.startAdvertising(advertiseSetting, advertiseData, mAdvertiseCallback)
      }, 300)
    }
  }

  //================= GATT通信 =================
  private fun connect(address: String): Boolean {
    adapter?.let { adapter ->
      try {
        val device: BluetoothDevice? = adapter.getRemoteDevice(address)
        // connect to the GATT server on the device
        bluetoothGatt = device?.connectGatt(context, false, bluetoothGattCallback)
        return true
      } catch (exception: IllegalArgumentException) {
        Log.d("GATT", "デバイスが見つかりませんでした。")
        return false
      }
    } ?: run {
      Log.d("GATT", "Bluetoothが使用できません。")
      return false
    }
  }
  
  //Gatt接続、コールバック
  private val bluetoothGattCallback = object : BluetoothGattCallback() {

    //ペリフェラルとの接続状態が変化したとき
    override fun onConnectionStateChange(gatt: BluetoothGatt,status: Int, newState: Int) {
      if (newState == BluetoothProfile.STATE_CONNECTED) {
        Log.d("Gatt","接続成功")
        //gatt通信量のサイズ変更
        gatt.requestMtu(512)
        handler.postDelayed({
          gatt.discoverServices()
        }, 200)
      }
    }

    override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
      if (status == BluetoothGatt.GATT_SUCCESS) {
        Log.d("Gatt", "MTU変更成功: $mtu バイト")
      } else {
        Log.e("Gatt", "MTU変更失敗")
      }
      bluetoothGatt?.discoverServices()
    }


    //サービスが検出されたとき
    override fun onServicesDiscovered(gatt: BluetoothGatt?,status: Int) {
      super.onServicesDiscovered(gatt, status)
      gatt?: return
      Log.d("Gatt","サービス検出 gatt: $gatt, status: $status")
      //対象のサービスの取得
      val service: BluetoothGattService? = gatt.getService(CONNECT_UUID)
      if (service == null) {
        Log.e("GATT", "指定されたサービスが見つかりません: $CONNECT_UUID")
        return
      }
      readCharacteristic = service.getCharacteristic(READ_CHARACTERISTIC_UUID)
      if (readCharacteristic != null) {
        Log.d("GATT", "Read Characteristic取得成功")
        Handler(Looper.getMainLooper()).postDelayed({
            bluetoothGatt?.readCharacteristic(readCharacteristic)
        }, 300)
      }
      writeCharacteristic = service.getCharacteristic(WRITE_CHARACTERISTIC_UUID)
      if (writeCharacteristic != null) {
        Log.d("GATT", "Write Characteristic取得成功")
      }
    }

    @Deprecated("Deprecated in API level 33")
    override fun onCharacteristicRead(
      gatt: BluetoothGatt,
      characteristic: BluetoothGattCharacteristic,
      status: Int
    ) 
    {
      if (status == BluetoothGatt.GATT_SUCCESS) {
        val data: ByteArray? = characteristic.getValue()
        val message = data?.let { String(it, Charsets.UTF_8) } ?: ""
        Log.d("BLE_READ", "受信メッセージ: $message")
        scanResultCallback?.invoke(
          mapOf(
            "status" to "RECEIVE_MESSAGE_SUCCESSFUL",
            "message" to message
          )
        )
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
      } else {
        Log.e("BLE_READ", "読み取り失敗 status: $status")
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
      }
    }

    fun getSupportedGattServices(): List<BluetoothGattService?>? {
      return bluetoothGatt?.services
    }
  }
}


//================= パーミッション確認 =================
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
    onResult(null)
    return
  } else {
    val message = "Missing permissions: ${missing.joinToString(", ")}"
    onResult(message)
  }
}
