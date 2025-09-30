package com.example.meshtalk

import androidx.annotation.NonNull;
import androidx.core.os.postDelayed
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.security.Policy
import java.util.*
import android.os.ParcelUuid

import android.util.Log

val UUID = ParcelUuid.fromString("86411acb-96e9-45a1-90f2-e392533ef877")

//BLT class
class BluetoothLeController(public val activity : Activity) {
  private val bluetoothManager = activity.getSystemService(android.content.Context.BLUETOOTH_SERVICE) as BluetoothManager
  private var isScanning : Boolean = false
  private var Scanner : BluetoothLeScanner? = null
  private lateinit var mScanCallback : ScanCallback
  private var scanFilter: ScanFilter? = null
  val scanFilterList = arrayListOf(ScanFilter.Builder().setServiceUuid(UUID).build())
  private val handler = Handler(Looper.getMainLooper())
  var scanResults = mutableListOf<ScanResult>()
  private val adapter: BluetoothAdapter? = bluetoothManager.adapter
  private val scanner: BluetoothLeScanner? = adapter?.bluetoothLeScanner
  private val advertiser: BluetoothLeAdvertiser? = adapter?.bluetoothLeAdvertiser
  private lateinit var mAdvertiseCallback : AdvertiseCallback

  //スキャン停止までの時間
  private val SCAN_PERIOD: Long = 3000

  //scanを始める
  fun scanLeDevice(onResult: (Map<String, String>) -> Unit) {
    if(!isScanning) {
      handler.postDelayed({
        isScanning = false
        stopScanLeDevice()
        Log.d("BLE","スキャンストップ")
        if (scanResults.isEmpty()) {
          Log.d("BLE", "検出されたデバイスはありません")
          onResult(mapOf(
            "status" to "device_not_found",
            "message" to "検出されたデバイスはありません"
          ))
        }else {
          for (result in scanResults) {
            val name = result.device.name ?: "Unknown"
            val address = result.device.address
            val rssi = result.rssi
            Log.d("BLE", "デバイス名: $name, アドレス: $address, RSSI: $rssi")
            onResult(mapOf(
              "status" to "scan_successful",
              "message" to "デバイスのスキャン完了"
            ))
          }
        }
      }, SCAN_PERIOD)
      isScanning = true

      val scanSettings: ScanSettings = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
        .build()

      mScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int,result:ScanResult) {
          //前に取得したことがない&&信号強度が強いもののみ
          if (result.rssi >= -70 && scanResults.none { it.device.address == result.device.address }) {
            scanResults.add(result)
          }
        }
        override fun onScanFailed(errorCode: Int) {
          super.onScanFailed(errorCode)
        }
      }
      if (!isScanning || scanner == null) {
        onResult(mapOf(
          "status" to "app_error",
          "message" to "予期せぬエラーが発生しました"
        ))
        return
      }
      scanner.startScan(scanFilterList,scanSettings,mScanCallback)
    }
  }
  //scanStop関数
  fun stopScanLeDevice() {
    if (!isScanning || scanner == null) return
    scanner.stopScan(mScanCallback)
  }

  //Bluetoothの権限の確認&BluetoothがONになっているかどうかを調べる関数
  //TODO

  //アドバタイズの開始
  fun startAdvertising(onResult: (Map<String, String>) -> Unit) {
    if (advertiser == null) {
      Log.e("BLE_AD", "このデバイスはBLEアドバタイズに対応していません")
      onResult(mapOf(
        "status" to "not_used_ble",
        "message" to "このデバイスは対応していないバージョンです"
      ))
      return
    }

    val advertiseSetting = AdvertiseSettings.Builder()
        .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
        .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
        .setConnectable(true)
        .build()

    val advertiseData = AdvertiseData.Builder()
        .setIncludeDeviceName(true)
        .addServiceUuid(ParcelUuid.fromString("86411acb-96e9-45a1-90f2-e392533ef877"))
        .build()

    mAdvertiseCallback = object : AdvertiseCallback() {
      override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
        Log.d("BLE_AD", "アドバタイズ開始成功")
        onResult(mapOf(
          "status" to "advertise_started",
          "message" to "アドバタイズを開始しました"
        ))
      }
      override fun onStartFailure(errorCode: Int) {
        Log.e("BLE_AD", "アドバタイズ失敗: $errorCode")
        onResult(mapOf(
          "status" to "advertise_failed",
          "message" to "アドバタイズに失敗しました（コード: $errorCode）"
        ))
      }
    }
    advertiser.startAdvertising(advertiseSetting, advertiseData, mAdvertiseCallback)
  }
  //アドバタイズ終了
  fun isBluetoothEnabled(): Boolean {
    return adapter?.isEnabled == true
  } 
}


class MainActivity : FlutterActivity() {
  private val CHANNEL = "meshtalk.flutter.dev/contact"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->
        when (call.method) {
          "sendMessage" -> {
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
                "not_used_ble" -> {
                  result.error("DEVICE_NOT_BLE", resultMap["message"], null)
                }
                "advertise_failed" -> {
                  result.error("FAILD_ADVERTISING", resultMap["message"], null)
                }
              }
            }
          }
          else -> result.notImplemented()
        }
    }
  }
}



