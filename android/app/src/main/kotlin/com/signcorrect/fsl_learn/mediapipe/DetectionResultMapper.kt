package com.signcorrect.fsl_learn.mediapipe

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

/**
 * Maps MediaPipe's HandLandmarkerResult into the application's
 * DetectionResult model.
 *
 * This is the only place in the application that knows about
 * MediaPipe's result models.
 */
object DetectionResultMapper {

    fun map(
        result: HandLandmarkerResult,
        inferenceTimeMs: Long
    ): DetectionResult {

        val handCount = result.landmarks().size

        val handedness = result.handedness()
            .firstOrNull()
            ?.firstOrNull()

        val landmarks =
            result.landmarks()
                .firstOrNull()
                ?.map(::mapLandmark)
                ?: emptyList()

        return DetectionResult(
            handCount = handCount,
            handedness =
    when (handedness?.categoryName()) {
        "Left" -> "Right"
        "Right" -> "Left"
        else -> handedness?.categoryName()
    },
            handednessConfidence =
                handedness?.score() ?: 0f,
            landmarks = landmarks,
            inferenceTimeMs = inferenceTimeMs
        )
    }

    private fun mapLandmark(
        landmark: NormalizedLandmark
    ): Landmark {

        return Landmark(
            x = landmark.x(),
            y = landmark.y(),
            z = landmark.z()
        )
    }
}