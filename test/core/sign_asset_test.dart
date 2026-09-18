import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/core/utils/sign_asset.dart';

void main() {
  test('greeting labels resolve to bundled greeting assets', () {
    expect(
      resolveSignAssetPath('KUMASTA'),
      'assets/fsl/greetings/kumusta.png',
    );
    expect(
      resolveSignAssetPath('salamat'),
      'assets/fsl/greetings/salamat.png',
    );
    expect(
      resolveSignAssetPath('Paalam'),
      'assets/fsl/greetings/paalam.png',
    );
  });

  test('letters and numbers still resolve to their existing assets', () {
    expect(resolveSignAssetPath('A'), 'assets/fsl/alphabet/a.png');
    expect(resolveSignAssetPath('7'), 'assets/fsl/numbers/7.png');
    expect(resolveSignAssetPath('ONE'), 'assets/fsl/numbers/1.png');
  });

  test('everyday communication labels resolve to bundled everyday assets',
      () {
    expect(
      resolveSignAssetPath('YES'),
      'assets/fsl/everyday/yes.png',
    );
    expect(
      resolveSignAssetPath('no'),
      'assets/fsl/everyday/no.png',
    );
    expect(
      resolveSignAssetPath('PLEASE'),
      'assets/fsl/everyday/please.png',
    );
    expect(
      resolveSignAssetPath('SORRY'),
      'assets/fsl/everyday/sorry.png',
    );
    expect(
      resolveSignAssetPath('EXCUSE_ME'),
      'assets/fsl/everyday/excuse_me.png',
    );
    expect(
      resolveSignAssetPath('GOOD_MORNING'),
      'assets/fsl/everyday/good_morning.png',
    );
    expect(
      resolveSignAssetPath('GOOD_NIGHT'),
      'assets/fsl/everyday/good_night.png',
    );
    expect(
      resolveSignAssetPath('LOVE'),
      'assets/fsl/everyday/love.png',
    );
    expect(
      resolveSignAssetPath('WELCOME'),
      'assets/fsl/everyday/welcome.png',
    );
    expect(
      resolveSignAssetPath('WATER'),
      'assets/fsl/everyday/water.png',
    );
    expect(
      resolveSignAssetPath('EAT'),
      'assets/fsl/everyday/eat.png',
    );
    expect(
      resolveSignAssetPath('DRINK'),
      'assets/fsl/everyday/drink.png',
    );
  });

  test('colors labels resolve to bundled colors assets', () {
    expect(resolveSignAssetPath('RED'), 'assets/fsl/colors/red.png');
    expect(resolveSignAssetPath('blue'), 'assets/fsl/colors/blue.png');
    expect(resolveSignAssetPath('GREEN'), 'assets/fsl/colors/green.png');
    expect(resolveSignAssetPath('ORANGE'), 'assets/fsl/colors/orange.png');
    expect(resolveSignAssetPath('purple'), 'assets/fsl/colors/purple.png');
    expect(resolveSignAssetPath('YELLOW'), 'assets/fsl/colors/yellow.png');
  });

  test('animals labels resolve to bundled animals assets', () {
    expect(resolveSignAssetPath('BIRD'), 'assets/fsl/animals/bird.png');
    expect(resolveSignAssetPath('cat'), 'assets/fsl/animals/cat.png');
    expect(resolveSignAssetPath('COW'), 'assets/fsl/animals/cow.png');
    expect(resolveSignAssetPath('FROG'), 'assets/fsl/animals/frog.png');
    expect(resolveSignAssetPath('lion'), 'assets/fsl/animals/lion.png');
    expect(resolveSignAssetPath('FISH'), 'assets/fsl/animals/fish.png');
  });

  test('unknown labels return null', () {
    expect(resolveSignAssetPath('QWERTY'), isNull);
  });
}
