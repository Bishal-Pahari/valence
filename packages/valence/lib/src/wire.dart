import 'dart:convert';

/// The per-message cap on the bridge, in UTF-8 bytes (contracts §4.2).
///
/// On Android a message travels through Binder, whose transaction buffer is around 1 MB and is shared
/// across the process. Overrunning it kills the WebView, with no reply and no error either side can catch.
const maxMessageBytes = 262144;

/// The closed set of bridge error codes (contracts §4.2). Add to the spec rather than inventing one per app.
abstract final class BridgeErrorCode {
  /// The method is not in the generated table.
  static const unknown = 'E_UNKNOWN';

  /// The params failed strict decoding.
  static const params = 'E_PARAMS';

  /// The host bridge is older than the method's `since`.
  static const unsupported = 'E_UNSUPPORTED';

  /// A bad nonce, a write to a non-writable bucket, or a disallowed URL scheme.
  static const denied = 'E_DENIED';

  /// The user backed out of native UI. Not an error, not a denial and not a fault.
  static const cancelled = 'E_CANCELLED';

  /// The message is over [maxMessageBytes].
  static const tooLarge = 'E_TOO_LARGE';

  /// Anything else.
  static const internal = 'E_INTERNAL';
}

/// An error carried back to the page as `{"ok": false, "e": {"code", "message"}}`.
///
/// Throw this from a bridge handler to choose the code the page sees. Anything else becomes `E_INTERNAL`.
final class BridgeError implements Exception {
  /// Creates an error with one of the [BridgeErrorCode] values.
  const BridgeError(this.code, this.message);

  /// One of the [BridgeErrorCode] constants.
  final String code;

  /// A message for the page's console and logs. It is not localised and not for end users.
  final String message;

  @override
  String toString() => '$code: $message';
}

// ---------------------------------------------------------------------------
// Strict decoders. `valence codegen` emits calls to these from every fromJson factory, so unknown
// fields, wrong types and non-JSON input are all rejected before a handler runs (contracts §4.2).
// ---------------------------------------------------------------------------

/// Decodes a JSON object, or throws `E_PARAMS`. Used by generated code.
Map<String, Object?> decodeObject(Object? v, String f) =>
    v is Map<String, Object?> ? v : throw BridgeError(BridgeErrorCode.params, '$f: expected an object');

/// Rejects any field the schema does not declare. Used by generated code.
void decodeKeys(Map<String, Object?> m, Set<String> allowed, String f) {
  for (final k in m.keys) {
    if (!allowed.contains(k)) throw BridgeError(BridgeErrorCode.params, '$f.$k: unknown field');
  }
}

/// Decodes a JSON string, or throws `E_PARAMS`. Used by generated code.
String decodeString(Object? v, String f) =>
    v is String ? v : throw BridgeError(BridgeErrorCode.params, '$f: expected a string');

/// Decodes a JSON integer, or throws `E_PARAMS`. Used by generated code.
int decodeInt(Object? v, String f) =>
    v is int ? v : throw BridgeError(BridgeErrorCode.params, '$f: expected an int');

/// Decodes a JSON number, or throws `E_PARAMS`. Used by generated code.
num decodeNum(Object? v, String f) =>
    v is num ? v : throw BridgeError(BridgeErrorCode.params, '$f: expected a number');

/// Decodes a JSON boolean, or throws `E_PARAMS`. Used by generated code.
bool decodeBool(Object? v, String f) =>
    v is bool ? v : throw BridgeError(BridgeErrorCode.params, '$f: expected a bool');

/// Decodes a JSON list, naming the failing index. Used by generated code.
List<T> decodeListOf<T>(Object? v, String f, T Function(Object? e, String p) each) {
  if (v is! List) throw BridgeError(BridgeErrorCode.params, '$f: expected a list');
  return [for (var i = 0; i < v.length; i++) each(v[i], '$f[$i]')];
}

// ---------------------------------------------------------------------------
// Replies and event scripts. Every script is built through jsonEncode; raw strings are never
// concatenated into JavaScript (contracts §4.2).
// ---------------------------------------------------------------------------

/// Encodes a successful reply, replacing an over-cap one with `E_TOO_LARGE`. Used by generated code.
///
/// An over-cap reply would overrun Binder and kill the WebView, with no reply and nothing either side can
/// catch — and a WebView death while a trial is on screen spends a strike, so a healthy bundle can be
/// marked bad. The id is still in hand here, so it becomes an error the page can actually see (§4.2).
String replyOk(Object? id, Object? v) {
  final s = jsonEncode({'id': id, 'ok': true, 'v': v});
  if (utf8.encode(s).length > maxMessageBytes) {
    return replyError(
      id,
      BridgeErrorCode.tooLarge,
      'reply is over the $maxMessageBytes byte bridge cap; page the request',
    );
  }
  return s;
}

/// Encodes a failed reply. Used by generated code.
String replyError(Object? id, String code, String message) =>
    jsonEncode({'id': id, 'ok': false, 'e': {'code': code, 'message': message}});

/// Builds the script that delivers one event to the page. Used by generated code.
String eventScript(String name, Object? payload) =>
    _escapeScriptSeparators('window.__valence&&window.__valence.e(${jsonEncode(name)},${jsonEncode(payload)})');

/// Wraps a reply from the generated `bridgeDispatch` in the script the host passes to `runJavaScript`.
String bridgeReplyScript(String reply) => _escapeScriptSeparators('window.__valence&&window.__valence.r($reply)');

String _escapeScriptSeparators(String script) => script.replaceAll('\u2028', r'\u2028').replaceAll('\u2029', r'\u2029');
