package com.signcorrect.fsl_learn

import com.signcorrect.fsl_learn.platform.CameraPreviewFactory
import com.signcorrect.fsl_learn.platform.DetectionEventStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

class MainActivity : FlutterActivity() {

    companion object {
        private const val CAMERA_VIEW_TYPE = "camera_preview"

        private const val DETECTION_CHANNEL =
            "com.signcorrect.fsl_learn/detections"

        private const val CAMERA_CONTROL_CHANNEL =
            "com.signcorrect.fsl_learn/camera"

        // SharedPreferences key the Flutter side uses for the camera lens.
        // The Flutter shared_preferences plugin prefixes Android keys with
        // "flutter.", so match it here to persist across app restarts.
        private const val PREFS_LENS_KEY = "flutter.settings_cameraLens"

        private const val LENS_FRONT = "front"
        private const val LENS_BACK = "back"
    }

    private lateinit var cameraPreviewFactory: CameraPreviewFactory

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        cameraPreviewFactory = CameraPreviewFactory(this)
        cameraPreviewFactory.lensFacing = loadInitialLensFacing()

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                CAMERA_VIEW_TYPE,
                cameraPreviewFactory
            )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DETECTION_CHANNEL
        ).setStreamHandler(
            DetectionEventStream
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CAMERA_CONTROL_CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "setLensFacing" -> {
                    val facing = call.arguments
                    when (facing) {
                        0 -> setLensFacing(androidx.camera.core.CameraSelector.LENS_FACING_FRONT, LENS_FRONT)
                        1 -> setLensFacing(androidx.camera.core.CameraSelector.LENS_FACING_BACK, LENS_BACK)
                        else -> result.error("badArgs", "lensFacing must be 0 (front) or 1 (back)", null)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun loadInitialLensFacing(): Int {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val stored = prefs.getString(PREFS_LENS_KEY, null)
            if (stored == LENS_BACK) {
                androidx.camera.core.CameraSelector.LENS_FACING_BACK
            } else {
                androidx.camera.core.CameraSelector.LENS_FACING_FRONT
            }
        } catch (_: Exception) {
            androidx.camera.core.CameraSelector.LENS_FACING_FRONT
        }
    }

    private fun setLensFacing(lensFacing: Int, storedValue: String) {
        cameraPreviewFactory.lensFacing = lensFacing
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putString(PREFS_LENS_KEY, storedValue).apply()
        } catch (_: Exception) {
            // Ignore persistence failures; in-memory preference still applies.
        }
    }
}
