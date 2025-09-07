package com.example.meshtalk

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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

                val disaster_message_data = messageType + phoneNum + targetPhoneNum + TTL + message

                result.success("出力されたデータはこれです $disaster_message_data")
            } else {
                result.notImplemented()
            }
        }
    }
}
