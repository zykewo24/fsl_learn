package com.signcorrect.fsl_learn.mediapipe

/**
 * Represents a single hand landmark.
 *
 * This is an application-level model that is independent of MediaPipe's
 * internal landmark classes. Keeping our own model prevents Flutter and
 * the rest of the application from depending directly on MediaPipe APIs.
 */
data class Landmark(

    /**
     * Normalized X coordinate.
     * Range: 0.0 to 1.0
     */
    val x: Float,

    /**
     * Normalized Y coordinate.
     * Range: 0.0 to 1.0
     */
    val y: Float,

    /**
     * Relative depth coordinate.
     */
    val z: Float
)