import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:io';

class CameraService {
  static Future<List<String>> captureEmergencyPhotos() async {
    List<String> base64Images = [];
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return [];

      // Try to find back and front cameras
      CameraDescription? backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      CameraDescription? frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Capture from back camera
      base64Images.add(await _takePicture(backCamera));

      // Capture from front camera (if different)
      if (frontCamera != backCamera) {
        base64Images.add(await _takePicture(frontCamera));
      }
    } catch (e) {
      print("Camera Capture Error: $e");
    }
    return base64Images;
  }

  static Future<String> _takePicture(CameraDescription camera) async {
    final controller = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
    await controller.initialize();
    final image = await controller.takePicture();
    await controller.dispose();

    final bytes = await File(image.path).readAsBytes();
    return base64Encode(bytes);
  }

  static Future<String?> captureSpecificCamera({required bool isFront}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;

      CameraDescription? targetCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == (isFront ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => cameras.first,
      );

      return await _takePicture(targetCamera);
    } catch (e) {
      print("Specific Camera Capture Error: $e");
      return null;
    }
  }
}
