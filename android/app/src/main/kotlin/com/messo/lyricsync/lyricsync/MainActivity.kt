package com.messo.lyricsync.lyricsync

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.messo.lyricsync/system"
    private var methodChannel: MethodChannel? = null
    private var isPipMode = false
    private var autoPipEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "keepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(true)
                    }
                }
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val isLandscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
                            val rational = if (isLandscape) Rational(16, 9) else Rational(4, 3)
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                builder.setAutoEnterEnabled(true)
                            }
                            val entered = enterPictureInPictureMode(builder.build())
                            result.success(entered)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.message, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "setAutoPip" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    autoPipEnabled = enable
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val isLandscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
                            val rational = if (isLandscape) Rational(16, 9) else Rational(4, 3)
                            val builder = PictureInPictureParams.Builder()
                                .setAspectRatio(rational)
                                .setAutoEnterEnabled(enable)
                            setPictureInPictureParams(builder.build())
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUTO_PIP_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isPipSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    result.success(supported)
                }
                "isPipActive" -> {
                    result.success(isPipMode)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoPipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !isPipMode) {
            try {
                val isLandscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
                val rational = if (isLandscape) Rational(16, 9) else Rational(4, 3)
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    builder.setAutoEnterEnabled(true)
                }
                enterPictureInPictureMode(builder.build())
            } catch (e: Exception) {
                // Ignore background transition exception
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isPipMode = isInPictureInPictureMode
        methodChannel?.invokeMethod("onPipModeChanged", mapOf("inPip" to isInPictureInPictureMode))
    }
}
