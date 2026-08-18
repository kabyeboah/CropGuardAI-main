import 'dart:typed_data';

/// Placeholder out-of-distribution gate.
/// Returns true (accept) by default. When a binary "is this a leaf?"
/// classifier is trained, drop it in here without touching routing logic.
abstract class OODGate {
  Future<bool> isPlantImage(String imagePath);
  Future<bool> isPlantBytes(Uint8List rgbaBytes, int width, int height);
}

class AlwaysAcceptOODGate implements OODGate {
  @override
  Future<bool> isPlantImage(String imagePath) async => true;

  @override
  Future<bool> isPlantBytes(Uint8List rgbaBytes, int width, int height) async => true;
}

