import 'package:fsl_learn/features/ai_practice/models/landmark.dart';

class V {
  final double x;
  final double y;
  final double z;

  const V(this.x, this.y, this.z);

  V lerp(V b, double t) => V(x + (b.x - x) * t, y + (b.y - y) * t, z + (b.z - z) * t);
}

/// Builds synthetic 21-landmark hands in image-like coordinates
/// (x right, y down, z depth) so the recognizer can be tested without a
/// camera. Palm faces the camera, fingers point up by default.
///
/// MediaPipe index layout:
/// 0 wrist, 1-4 thumb, 5-8 index, 9-12 middle, 13-16 ring, 17-20 pinky.
class SyntheticHand {
  final List<V> p = List.generate(21, (_) => const V(0, 0, 0));

  SyntheticHand() {
    p[0] = const V(0.50, 0.63, 0.00);
    _setThumbBase();
    _setFingerMcps();
  }

  void _setThumbBase() {
    p[1] = const V(0.41, 0.56, 0.00);
    p[2] = const V(0.43, 0.52, 0.02);
    p[3] = const V(0.44, 0.48, 0.04);
  }

  void _setFingerMcps() {
    p[5] = const V(0.46, 0.55, 0.03);
    p[9] = const V(0.51, 0.54, 0.03);
    p[13] = const V(0.56, 0.545, 0.03);
    p[17] = const V(0.60, 0.56, 0.025);
  }

  static const Map<String, int> fingerMcp = {
    'index': 5,
    'middle': 9,
    'ring': 13,
    'pinky': 17,
  };

  /// Positions PIP/DIP/TIP for a finger given the fingertip target.
  /// The MCP joint is already fixed at hand creation time.
  void finger(
    String name, {
    required V tip,
    V? pip,
    V? dip,
    double pipT = 0.4,
    double dipT = 0.7,
  }) {
    final mcpIdx = fingerMcp[name]!;
    final mcp = p[mcpIdx];
    p[mcpIdx + 1] = pip ?? mcp.lerp(tip, pipT);
    p[mcpIdx + 2] = dip ?? mcp.lerp(tip, dipT);
    p[mcpIdx + 3] = tip;
  }

  void setThumbTip(double x, double y, double z) {
    p[4] = V(x, y, z);
  }

  List<Landmark> build() {
    return p.map((v) => Landmark(x: v.x, y: v.y, z: v.z)).toList();
  }
}