/// The surface `valence codegen` emits calls to. **Not for app code.**
///
/// Everything here is the marshalling half of the bridge: strict decoders, reply and event script
/// builders, and the message cap. It lives in the package so a fix ships once; the generated
/// `bridge.g.dart` is the only thing that should import it.
///
/// App code wants `package:valence/valence.dart` instead, which is also where `BridgeError` lives: a
/// generated file imports both, and the two surfaces deliberately do not overlap.
library;

export 'src/wire.dart'
    show
        bridgeReplyScript,
        decodeBool,
        decodeInt,
        decodeKeys,
        decodeListOf,
        decodeNum,
        decodeObject,
        decodeString,
        eventScript,
        replyError,
        replyOk;
