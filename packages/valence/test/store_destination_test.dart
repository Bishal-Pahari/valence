import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valence/src/config.dart';

void main() {
  test('R31 store destination is compiled identity with no page supplied URL', () {
    const config = ValenceConfig(appId: 'com.example.app', keyring: {}, bridgeVersion: 17, iosAppId: '123456789');
    // The exact strings the runtime passes, not lowercase literals it never produces: Flutter spells
    // the enum member `iOS`, so hand-writing 'ios' here passed while every real iOS device fell through
    // to null, hiding the only button on the blocking screen.
    expect(TargetPlatform.iOS.name, 'iOS');
    expect(valenceStoreUrl(config, TargetPlatform.android.name).toString(), 'https://play.google.com/store/apps/details?id=com.example.app');
    expect(valenceStoreUrl(config, TargetPlatform.iOS.name).toString(), 'https://apps.apple.com/app/id123456789');
    expect(valenceStoreUrl(config, 'linux'), isNull);
    expect(valenceStoreUrl(const ValenceConfig(appId: 'a', keyring: {}, bridgeVersion: 1), TargetPlatform.iOS.name), isNull);
    expect(config.copyWith().iosAppId, '123456789');
  });
}
