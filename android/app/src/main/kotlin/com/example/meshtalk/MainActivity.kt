package com.example.meshtalk

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*


//これでネイティブ側のプログラムを実行してる
class MainActivity: FlutterActivity() {
    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("e12244c3-b36f-0c72-5345-884ccec7aeb4") 
    }
    private val CHANNEL = "meshtalk.flutter.dev/contact"
    private lateinit var bluetoothAdapter: BluetoothAdapter
    private lateinit var bluetoothLeScanner: BluetoothLeScanner
    private val handler = Handler(Looper.getMainLooper())
    private var scanRetryCount = 0
    private val MAX_SCAN_RETRIES = 2
    private val foundDevices = mutableMapOf<String, BluetoothDevice>()


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            //実行させる内容↓
            if (call.method == "sendMessage") {

                startScanAndSend()
                result.success("送信できました")
            } else {
                result.notImplemented()
            }
        }
    }

      private fun startScanAndSend() {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter.bluetoothLeScanner //機能取り出し

         scanRetryCount = 0 //リトライカウント初期化
         foundDevices.clear() //見つかったデバイスリストをクリア
            startScan() //スキャン開始
}
private fun startScan() {
     val SCAN_PERIOD: Long = 10000 // スキャン時間10秒
     handler.postDelayed({
        bluetoothLeScanner.stopScan(scanCallback)//指定時間後にスキャン停止
        
        if (foundDevices.isEmpty()) {        //デバイスが見つからなかった場合
             if (scanRetryCount < MAX_SCAN_RETRIES) {  //リトライカウントが上限より少ない場合
             scanRetryCount++//リトライカウント増加
              startScan()//リトライ

            } else { //２度リトライしても見つからなかった場合
                result.success("デバイスが見つかりませんでした") //Flutter側に通知
            }
             } else {  //デバイスが見つかった場合

                deviceQueue.addAll(foundDevices.values)
                connectAndSend() //接続してメッセージ送信
             } 
        }, SCAN_PERIOD)
        val scanFilter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()