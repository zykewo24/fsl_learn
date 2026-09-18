package com.signcorrect.fsl_learn.platform

import android.content.Context
import androidx.camera.core.CameraSelector
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CameraPreviewFactory(
    private val lifecycleOwner: LifecycleOwner
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    // Preferred lens facing, shared across all created previews. Set via the
    // MethodChannel (MainActivity) and read when each CameraPreview is built.
    @Volatile
    var lensFacing: Int = CameraSelector.LENS_FACING_FRONT

    override fun create(
        context: Context,
        viewId: Int,
        args: Any?
    ): PlatformView {

        return CameraPreview(
            context = context,
            lifecycleOwner = lifecycleOwner,
            initialLensFacing = lensFacing
        )
    }
}
