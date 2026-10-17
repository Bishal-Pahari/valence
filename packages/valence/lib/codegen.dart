/// The surface `valence codegen` emits calls to. **Not for app code.**
///
/// Everything here is the marshalling half of the bridge: strict decoders, reply and event script
/// builders, and the message cap. It lives in the package so a fix ships once; the generated
/// `bridge.g.dart` is the only thing that should import it.
///
/// App code wants `package:valence/valence.dart` instead.
library;

export 'src/wire.dart'
    show
        BridgeError,
        BridgeErrorCode,
        bridgeReplyScript,
        decodeBool,
        decodeInt,
        decodeKeys,
        decodeListOf,
        decodeNum,
        decodeObject,
        decodeString,
        eventScript,
        maxMessageBytes,
        replyError,
        replyOk;
