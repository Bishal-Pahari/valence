import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'log.dart';
import 'wire.dart';

/// The reserved key the bearer token is stored at (contracts §4.4).
///
/// It is inside the reserved `valence.` namespace, which [ValenceSecure.get] refuses — so the page can
/// set, replace and clear the token, and can ask whether one exists, but can never read it back.
const secureAuthTokenKey = 'valence.auth.token';

/// The reserved key the opaque account id is stored at (contracts §4.4).
///
/// Also inside the reserved `valence.` namespace. It is written only by `auth.setToken` and read back
/// only by `auth.account`, which is deliberate: the page chose the value, so reading it back tells it
/// nothing it did not already know, and it is what makes "is this the same user?" answerable after a
/// cold start.
const secureAuthAccountKey = 'valence.auth.account';

/// Keystore-backed storage for the few strings that must not sit in the SQLite file (contracts §4.4).
///
/// Android: an AES-GCM record whose key is wrapped by a hardware-backed Keystore key (`minSdk 23`).
/// iOS: the Keychain, at `first_unlock_this_device`, so a background sync before the first unlock after a
/// reboot finds no token rather than failing — **written and unverified, like every iOS path here.**
final class ValenceSecure {
  /// Creates the store. Pass [storage] in tests, or let the platform default stand.
  ValenceSecure({FlutterSecureStorage? storage, ValenceLogger log = defaultValenceLogger})
      : _storage = storage ??
            const FlutterSecureStorage(
              // first_unlock_this_device, not the default after_first_unlock: the item must not travel to
              // another device in an iCloud Keychain backup, and a background launch after a reboot still
              // needs it once the user has unlocked once.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            ),
        _log = log;

  final FlutterSecureStorage _storage;
  final ValenceLogger _log;

  /// `secure.get`. Refuses the reserved `valence.` prefix.
  Future<String?> get(String key) async {
    _refuseReserved(key);
    return read(key);
  }

  /// `secure.set`. Refuses the reserved prefix. The value is non-null: [delete] is the only delete (§4.4).
  Future<void> set(String key, String value) async {
    _refuseReserved(key);
    await write(key, value);
  }

  /// `secure.delete`. Refuses the reserved prefix.
  Future<void> delete(String key) async {
    _refuseReserved(key);
    await write(key, null);
  }

  /// `auth.setToken`. A null [token] clears it.
  Future<void> setAuthToken(String? token) =>
      write(secureAuthTokenKey, token == null || token.isEmpty ? null : token);

  /// The account id recorded beside the token, or null when the app has never named one (§4.4).
  Future<String?> authAccount() => read(secureAuthAccountKey);

  /// Records the account id, or clears it. Host-side only; the page reaches it through `auth.setToken`.
  Future<void> setAuthAccount(String? account) =>
      write(secureAuthAccountKey, account == null || account.isEmpty ? null : account);

  /// `auth.hasToken`. The only thing the page may learn about the stored token.
  Future<bool> hasAuthToken() async => (await read(secureAuthTokenKey)) != null;

  /// The token the sync driver attaches as `Authorization: Bearer` (§4.4, §5.3).
  Future<String?> authToken() => read(secureAuthTokenKey);

  /// Reads any key, reserved ones included. Host-side only; see [get].
  ///
  /// **A platform that cannot answer reads as null.** A unit test with no plugin, a background isolate
  /// that skipped `DartPluginRegistrant.ensureInitialized()`, or a Keystore the OS has invalidated would
  /// otherwise throw out of the middle of a sync and fail the whole run — including the public buckets
  /// that were never authenticated in the first place.
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (e) {
      _log('secure: could not read "$key" ($e); treating it as absent');
      return null;
    }
  }

  /// Writes or deletes any key, reserved ones included. Host-side only; see [set] and [delete].
  ///
  /// A write that cannot reach the platform throws `E_INTERNAL`: unlike a read, silence here would tell
  /// the page its token is stored when nothing is.
  Future<void> write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } on Object catch (e) {
      _log('secure: could not write "$key": $e');
      throw BridgeError(BridgeErrorCode.internal, 'secure storage is not available on this device');
    }
  }

  static void _refuseReserved(String key) {
    if (key == 'valence' || key.startsWith('valence.')) {
      throw BridgeError(BridgeErrorCode.denied, 'the "valence." secure-storage prefix is reserved for the host');
    }
  }
}
