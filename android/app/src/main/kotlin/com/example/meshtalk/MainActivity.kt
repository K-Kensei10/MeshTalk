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

    //スキャン停止までの時間
    private val SCAN_PERIOD: Long = 300

    //scanを始める
    fun scanLeDevice(onResult: (Boolean) -> Unit) {
        if(!isScanning) {
          handler.postDelayed({
            isScanning = false
            stopScanLeDevice()
            Log.d("BLE","スキャンストップ")
            if (scanResults.isEmpty()) {
              Log.d("BLE", "検出されたデバイスはありません")
              onResult(false)
            }else {
              for (result in scanResults) {
                val name = result.device.name ?: "Unknown"
                val address = result.device.address
                val rssi = result.rssi
                Log.d("BLE", "デバイス名: $name, アドレス: $address, RSSI: $rssi")
                onResult(true)
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
            onResult(false)
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
            bleController.scanLeDevice { success ->
              if (success) {
                result.success("scan_success")
                //アドバタイズの処理
              }else {
                result.error("SCAN_FAILD", "No devices found", null)
              }
            }
          }
        }
        else -> result.notImplemented()
    }
  }
}



