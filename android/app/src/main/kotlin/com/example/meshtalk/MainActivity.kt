package com.example.meshtalk

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

//これでネイティブ側のプログラムを実行してる
class MainActivity: FlutterActivity() {
    private val CHANNEL = "meshtalk.flutter.dev/contact"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            //実行させる内容↓
            if (call.method == "sendMessage") {
              val message = call.argument<String>("message")
              println("受信したメッセージ: $message")
              result.success("Kotlin側で受信しました: $message")
            } else {
                result.notImplemented()
            }
        }
    }
}
