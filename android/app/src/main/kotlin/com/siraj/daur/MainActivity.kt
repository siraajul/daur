package com.siraj.daur

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 12+ fades its splash out before the app fades in. Flutter's first frame redraws
        // the same icon (lib/splash.dart), so cut straight to it instead.
        if (Build.VERSION.SDK_INT >= 31) splashScreen.setOnExitAnimationListener { it.remove() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // the live fasting notification (FastLive.kt), driven from lib/live.dart
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daur/fast").setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    FastLive.show(
                        this,
                        (call.argument<Number>("from")!!).toLong(),
                        call.argument<Int>("goal")!!,
                        call.argument<List<Int>>("hours")!!,
                        call.argument<List<String>>("names")!!,
                    )
                    result.success(null)
                }
                "cancel" -> {
                    FastLive.cancel(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
