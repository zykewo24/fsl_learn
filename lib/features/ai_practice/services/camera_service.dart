import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  CameraDescription? _frontCamera;
  CameraDescription? _backCamera;
  CameraDescription? _currentCamera;

  CameraController? get controller => _controller;

  bool get isInitialized =>
      _controller?.value.isInitialized ?? false;

  bool get isFrontCamera =>
      _currentCamera?.lensDirection ==
      CameraLensDirection.front;

  bool get isBackCamera =>
      _currentCamera?.lensDirection ==
      CameraLensDirection.back;

  Future<void> initialize() async {
    if (_frontCamera == null && _backCamera == null) {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras found.');
      }

      for (final camera in cameras) {
        switch (camera.lensDirection) {
          case CameraLensDirection.front:
            _frontCamera ??= camera;
            break;

          case CameraLensDirection.back:
            _backCamera ??= camera;
            break;

          default:
            break;
        }
      }

      _currentCamera =
          _backCamera ??
          _frontCamera ??
          cameras.first;
    }

    await _createController(_currentCamera!);
  }

  Future<void> _createController(
    CameraDescription camera,
  ) async {
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    _currentCamera = camera;
  }

  Future<void> switchCamera() async {
    if (_frontCamera == null || _backCamera == null) {
      return;
    }

    if (_controller?.value.isStreamingImages ?? false) {
      await stopImageStream();
    }

    final nextCamera =
        isBackCamera ? _frontCamera! : _backCamera!;

    await _createController(nextCamera);
  }

  Future<void> startImageStream(
    Function(CameraImage image) onFrame,
  ) async {
    if (_controller == null) {
      throw Exception('Camera not initialized.');
    }

    if (_controller!.value.isStreamingImages) {
      return;
    }

    await _controller!.startImageStream(onFrame);
  }

  Future<void> stopImageStream() async {
    if (_controller == null) return;

    if (!_controller!.value.isStreamingImages) {
      return;
    }

    await _controller!.stopImageStream();
  }

  Future<void> dispose() async {
    await stopImageStream();

    await _controller?.dispose();
    _controller = null;
  }
}