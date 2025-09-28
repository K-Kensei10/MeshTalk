package com.example.meshtalk

import androidx.annotation.NonNull;
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
import java.security.Policy
import java.util.*
import android.util.Log
val UUID = "86411acb-96e9-45a1-90f2-e392533ef877"

//BLT class
class BluetoothLeController(public val activity : Activity) {
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var isScanning : Boolean = false
    private var Scanner : BluetoothLeScanner? = null
    private lateinit var mScanCallback : ScanCallback
    private var scanFilter: ScanFilter? = null
    private var scanFilterList: ArrayList<ScanFilter> = ArrayList()

    fun StartScan() {
        if(isScanning) return
        val scanSettings: ScanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        mScanCallback = object : ScanCallback() {
          override fun onScanResult(callbackType: Int,result:ScanResult) {
            super.onScanResult(callbackType, result)
            Log.d("scanResult", "${result.device.address} ${result.device.name}")
          }
          override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
          }
        }
        var adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) return;
        var scanner = adapter.bluetoothLeScanner
        if (scanner == null) return;
        scanner.startScan(scanFilterList,scanSettings,mScanCallback)
        isScanning = true
    }
    //TODO
    //scanStop関数



}


// これでネイティブ側のプログラムを実行してる
class MainActivity : FlutterActivity() {
    private val CHANNEL = "meshtalk.flutter.dev/contact"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            // 実行させる内容↓
            if (call.method == "sendMessage") {
                val message = call.argument<String>("message") ?: ""
                val phoneNum = call.argument<String>("phoneNum") ?: ""
                val messageType = call.argument<String>("messageType") ?: ""
                val targetPhoneNum = call.argument<String>("targetPhoneNum") ?: ""
                val TTL = 150
                val separator = "*****"

                val disaster_message_data = messageType + separator + phoneNum +separator + targetPhoneNum + separator + TTL + separator + message
                Log.d("MainActivity", disaster_message_data)
                val bleController = BluetoothLeController(this)
                bleController.StartScan()
            } else {
                result.notImplemented()
            }
        }
    }
}



