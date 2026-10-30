import 'package:flutter/services.dart';
import 'package:valence/valence.dart';

/// A minimal native plugin; no permissions or persistent resources to manage.
final class HapticsPlugin implements ValencePlugin {
  /// Create the handler registered by the example app.
  const HapticsPlugin();

  @override
  String get namespace => 'haptics';
  @override
  Set<String> get methods => const {'haptics.tap'};

  @override
  Future<Object?> invoke(
      Valence valence, String method, Map<String, Object?> params) async {
    if (method != 'haptics.tap') {
      throw const BridgeError(
          BridgeErrorCode.unsupported, 'unknown haptics method');
    }
    if (params.isNotEmpty) {
      throw const BridgeError(
          BridgeErrorCode.params, 'haptics.tap takes no parameters');
    }
    await HapticFeedback.lightImpact();
    return null;
  }
}
