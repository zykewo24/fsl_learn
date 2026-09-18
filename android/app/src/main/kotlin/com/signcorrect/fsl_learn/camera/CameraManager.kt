package com.signcorrect.fsl_learn.camera

import android.content.Context
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val onFrameAvailable: (ImageProxy) -> Unit,
    initialLensFacing: Int = CameraSelector.LENS_FACING_FRONT
) {

    companion object {
        // Modest analysis resolution: hand landmarking accuracy is
        // unaffected at this size, while bitmap conversion + inference cost
        // scale with pixel count.
        private const val ANALYSIS_WIDTH = 640
        private const val ANALYSIS_HEIGHT = 480
    }

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null

    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null

    private val cameraExecutor: ExecutorService =
        Executors.newSingleThreadExecutor()

    // Set once release() starts so analyzer frames already queued on the
    // executor are dropped instead of being processed against a released
    // camera / landmarker.
    @Volatile
    private var released = false

    private var lensFacing = initialLensFacing

    fun currentLensFacing(): Int = lensFacing

    fun startCamera(previewView: PreviewView) {

        val cameraProviderFuture =
            ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({

            cameraProvider = cameraProviderFuture.get()

            bindCameraUseCases(previewView)

        }, ContextCompat.getMainExecutor(context))
    }

    fun switchCamera(previewView: PreviewView) {

        lensFacing =
            if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                CameraSelector.LENS_FACING_BACK
            } else {
                CameraSelector.LENS_FACING_FRONT
            }

        bindCameraUseCases(previewView)
    }

    private fun bindCameraUseCases(
        previewView: PreviewView
    ) {

        val provider = cameraProvider ?: return

        provider.unbindAll()

        preview = Preview.Builder()
            .build()
            .also {
                it.surfaceProvider = previewView.surfaceProvider
            }

        imageAnalysis =
    ImageAnalysis.Builder()
        .setBackpressureStrategy(
            ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST
        )
        // Lower resolution and frame rate cut the per-frame cost of bitmap
        // conversion and MediaPipe inference dramatically. Hand landmarking
        // does not need full camera resolution.
        .setTargetResolution(
            android.util.Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT)
        )
        .setOutputImageFormat(
            ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888
        )
        .build()
        .also { analysis ->

            analysis.setAnalyzer(
                cameraExecutor
            ) { imageProxy ->

                if (released) {
                    imageProxy.close()
                    return@setAnalyzer
                }

                onFrameAvailable(imageProxy)

            }
        }

        val selector =
            CameraSelector.Builder()
                .requireLensFacing(lensFacing)
                .build()

        camera =
            provider.bindToLifecycle(
                lifecycleOwner,
                selector,
                preview,
                imageAnalysis
            )
    }

    fun stopCamera() {
        cameraProvider?.unbindAll()
    }

    fun release() {

        released = true

        stopCamera()

        cameraExecutor.shutdownNow()

        preview = null
        imageAnalysis = null
        camera = null
        cameraProvider = null
    }
}