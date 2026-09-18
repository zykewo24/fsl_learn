package com.signcorrect.fsl_learn.mediapipe

/**
 * Represents the result of a single hand detection inference.
 *
 * This model is independent of MediaPipe and is the only detection model
 * exposed to the rest of the application.
 */
data class DetectionResult(

    /**
     * Number of hands detected in the current frame.
     */
    val handCount: Int,

    /**
     * Detected hand label.
     *
     * Examples:
     * - "Left"
     * - "Right"
     * - null (no hand detected)
     */
    val handedness: String?,

    /**
     * Confidence score of the handedness classification.
     *
     * Range:
     * 0.0f - 1.0f
     */
    val handednessConfidence: Float,

    /**
     * All detected landmarks.
     *
     * MediaPipe returns 21 landmarks for each detected hand.
     */
    val landmarks: List<Landmark>,

    /**
     * Time required to perform inference.
     */
    val inferenceTimeMs: Long
)