package com.example.meshtalk

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.AdvertisingSetCallback;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanSettings
import android.Manifest;
import java.security.Policy
import java.util.*

//BLT class
class BluetoothLeController(public val activity : Activity) {
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var enable : Boolean = false
    private var Scanner : BluetoothLeScanner? = null
    private lateinit var mScanCallback : ScanCallback
    private val permissions = arrayOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN, Manifest.permission.ACCESS_FINE_LOCATION)
    private var scanFilter: ScanFilter? = null
    private var scanFilterList: ArrayList<ScanFilter> = ArrayList()

    fun ScanStart() {
        if (enable) return;
    }




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
            if (call.method == "createMessage") {
                val message = call.argument<String>("message")
                val phoneNum = call.argument<String>("phoneNum")
                val messageType = call.argument<String>("messageType")
                val targetPhoneNum = call.argument<String>("targetPhoneNum")
                val TTL = 150
                val separator = "";/:""

                val disaster_message_data = messageType + separator + phoneNum +separator + targetPhoneNum + separator + TTL + separator + message
            } else {
                result.notImplemented()
            }

            if (call.method == "sendMessage") {
              val bluetoothStatus = true
            } else {
                result.notImplemented()
            }
        }
    }
}



