package com.signcorrect.fsl_learn.platform

import android.content.Context
import android.util.Log
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageProxy
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.signcorrect.fsl_learn.camera.CameraManager
import com.signcorrect.fsl_learn.mediapipe.HandLandmarkerHelper
import io.flutter.plugin.platform.PlatformView
import com.signcorrect.fsl_learn.mediapipe.DetectionResultMapper
import com.signcorrect.fsl_learn.platform.DetectionEventStream

class CameraPreview(
    context: Context,
    lifecycleOwner: LifecycleOwner,
    initialLensFacing: Int
) : PlatformView,
    HandLandmarkerHelper.LandmarkerListener {

    companion object {
        private const val TAG = "CameraPreview"
    }

    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    private val handLandmarkerHelper =
        HandLandmarkerHelper(
            context = context,
            runningMode = RunningMode.LIVE_STREAM,
            handLandmarkerHelperListener = this
        )

    // Whether the currently-bound camera is the front (selfie) camera. Only
    // front camera frames need horizontal mirroring before MediaPipe.
    @Volatile
    private var isFrontCamera: Boolean =
        initialLensFacing == CameraSelector.LENS_FACING_FRONT

    private val cameraManager = CameraManager(
        context = context,
        lifecycleOwner = lifecycleOwner,
        initialLensFacing = initialLensFacing,
        onFrameAvailable = { imageProxy: ImageProxy ->

            handLandmarkerHelper.detectLiveStream(
                imageProxy = imageProxy,
                isFrontCamera = isFrontCamera
            )
        }
    )

    init {
        cameraManager.startCamera(previewView)
    }

    override fun getView(): View = previewView

    override fun dispose() {

        // Tear down the landmarker first. clearHandLandmarker() marks the
        // helper as closed (under a lock), so any analyzer frame still in
        // flight will be dropped instead of crashing on a closed task graph.
        handLandmarkerHelper.clearHandLandmarker()

        // Then stop the camera and its analyzer executor (drops stragglers).
        cameraManager.release()
    }

    override fun onResults(
    resultBundle: HandLandmarkerHelper.ResultBundle
) {

    val result =
        resultBundle.results.firstOrNull()
            ?: return

    val detection =
        DetectionResultMapper.map(
            result,
            resultBundle.inferenceTime
        )
    DetectionEventStream.send(
        mapOf(
            "handCount" to detection.handCount,
            "handedness" to detection.handedness,
            "confidence" to detection.handednessConfidence,
            "inferenceTimeMs" to detection.inferenceTimeMs,
            "landmarks" to detection.landmarks.map {

                mapOf(
                    "x" to it.x,
                    "y" to it.y,
                    "z" to it.z
                )

            }
        )
    )
}

    override fun onError(
        error: String,
        errorCode: Int
    ) {

        Log.e(
            TAG,
            error
        )
    }
}