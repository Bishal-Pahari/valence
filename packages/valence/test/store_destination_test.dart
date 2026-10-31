import 'package:flutter_test/flutter_test.dart';
import 'package:valence/src/config.dart';

void main() {
  test('R31 store destination is compiled identity with no page supplied URL', () {
    const config = ValenceConfig(appId: 'com.example.app', keyring: {}, bridgeVersion: 17, iosAppId: '123456789');
    expect(valenceStoreUrl(config, 'android').toString(), 'https://play.google.com/store/apps/details?id=com.example.app');
    expect(valenceStoreUrl(config, 'ios').toString(), 'https://apps.apple.com/app/id123456789');
    expect(valenceStoreUrl(config, 'linux'), isNull);
    expect(valenceStoreUrl(const ValenceConfig(appId: 'a', keyring: {}, bridgeVersion: 1), 'ios'), isNull);
    expect(config.copyWith().iosAppId, '123456789');
  });
}
