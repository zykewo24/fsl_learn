import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/ai_practice/recognition/hand_geometry.dart';

import '../support/alphabet_poses.dart';

void main() {
  test('palm width is normalized to a stable scale', () {
    final g = HandGeometry.fromLandmarks(AlphabetPoses.a());

    expect(g.rawPalmWidth, greaterThan(0.1));
    expect(g.indexTipDist, lessThan(8.0));
    expect(g.thumbTipDist, lessThan(8.0));
  });

  test('extension flags describe an open B hand', () {
    final g = HandGeometry.fromLandmarks(AlphabetPoses.b());

    expect(g.indexExtended, isTrue);
    expect(g.middleExtended, isTrue);
    expect(g.ringExtended, isTrue);
    expect(g.pinkyExtended, isTrue);
    expect(g.thumbExtended, isFalse);
  });

  test('extension flags describe a closed A fist', () {
    final g = HandGeometry.fromLandmarks(AlphabetPoses.a());

    expect(g.indexExtended, isFalse);
    expect(g.middleExtended, isFalse);
    expect(g.ringExtended, isFalse);
    expect(g.pinkyExtended, isFalse);
    expect(g.thumbExtended, isTrue);
  });

  test('direction features detect a forward-pointing index', () {
    final g = HandGeometry.fromLandmarks(AlphabetPoses.g());

    expect(g.indexForward, isTrue);
    expect(g.indexUp, isFalse);
    expect(g.indexSideways, isFalse);
  });

  test('direction features detect a downward-pointing index', () {
    final g = HandGeometry.fromLandmarks(AlphabetPoses.p());

    expect(g.indexDown, isTrue);
    expect(g.indexUp, isFalse);
  });

  test('crossed detection distinguishes R fingers', () {
    final r = HandGeometry.fromLandmarks(AlphabetPoses.r());
    final u = HandGeometry.fromLandmarks(AlphabetPoses.u());

    expect(r.indexMiddleCrossed, isTrue);
    expect(u.indexMiddleCrossed, isFalse);
  });

  test('bend ratio captures the hooked X index', () {
    final x = HandGeometry.fromLandmarks(AlphabetPoses.x());
    final l = HandGeometry.fromLandmarks(AlphabetPoses.l());

    expect(x.indexBendRatio, inInclusiveRange(0.88, 1.10));
    expect(l.indexBendRatio, greaterThan(1.5));
  });
}