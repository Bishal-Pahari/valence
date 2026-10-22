import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'manifest.dart';
import 'wire.dart';

/// Maximum decoded inline image size; base64 plus the envelope fits the bridge cap.
const maxInlineShareBytes = 128 * 1024;

/// Maximum size of an image read from the active signed bundle.
const maxBundleShareBytes = 5 * 1024 * 1024;

/// The package-owned policy for `share.image` (contracts §4.7).
///
/// Paths are manifest keys, never filesystem paths. Only the hash in the host's
/// verified active manifest selects a CAS file. The native plugin receives a copy
/// of validated bytes, never the CAS path or a page-supplied file path.
final class ValenceImageShare {
  /// Creates a sharing service. [present] replaces only native UI in tests.
  ValenceImageShare({
    required this.manifest,
    required this.casDir,
    Future<ShareResult> Function(ShareParams)? present,
    Future<Directory> Function()? temporaryDirectory,
  })  : _present = present ?? SharePlus.instance.share,
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  /// The manifest currently served by the host, after signature verification.
  final ValenceManifest? Function() manifest;

  /// The host's private content-addressed store.
  final Directory casDir;
  final Future<ShareResult> Function(ShareParams) _present;
  final Future<Directory> Function() _temporaryDirectory;
  bool _busy = false;

  /// Opens native sharing. `selected` means a target was chosen, not delivery.
  Future<String> share(
      {String? bytes, String? path, String? fileName, String? caption}) async {
    if (_busy) {
      throw const BridgeError(
          BridgeErrorCode.denied, 'a share sheet is already open');
    }
    if ((bytes == null) == (path == null)) {
      throw const BridgeError(
          BridgeErrorCode.params, 'provide exactly one of bytes or path');
    }
    if (caption != null &&
        (caption.length > 4096 || utf8.encode(caption).length > 4096)) {
      throw const BridgeError(
          BridgeErrorCode.tooLarge, 'caption exceeds 4096 UTF-8 bytes');
    }
    // Validate before any file I/O, including when the detected extension is unknown.
    if (fileName != null &&
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.(png|jpg|jpeg)$')
            .hasMatch(fileName)) {
      throw const BridgeError(BridgeErrorCode.params,
          'fileName must be a plain PNG or JPEG leaf name');
    }
    _busy = true;
    try {
      final Uint8List data;
      if (bytes != null) {
        if (bytes.length > ((maxInlineShareBytes + 2) ~/ 3) * 4) {
          throw const BridgeError(
              BridgeErrorCode.tooLarge, 'inline image exceeds 128 KiB');
        }
        // Dart's decoder normalizes URL-safe, percent-escaped and unpadded input.
        // The wire contract accepts canonical standard base64 only.
        if (!RegExp(
                r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$')
            .hasMatch(bytes)) {
          throw const BridgeError(
              BridgeErrorCode.params, 'bytes must be standard padded base64');
        }
        try {
          data = base64Decode(bytes);
        } on FormatException {
          throw const BridgeError(
              BridgeErrorCode.params, 'bytes must be canonical base64');
        }
        if (base64Encode(data) != bytes) {
          throw const BridgeError(
              BridgeErrorCode.params, 'bytes must be canonical base64');
        }
        if (data.length > maxInlineShareBytes) {
          throw const BridgeError(
              BridgeErrorCode.tooLarge, 'inline image exceeds 128 KiB');
        }
      } else {
        if (!isSafeBundlePath(path!) || isReservedBundlePath(path)) {
          throw const BridgeError(
              BridgeErrorCode.denied, 'path must name an active bundle image');
        }
        final entry = manifest()?.files[path];
        if (entry == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.hash)) {
          throw const BridgeError(
              BridgeErrorCode.denied, 'path is absent from the active bundle');
        }
        if (entry.size > maxBundleShareBytes) {
          throw const BridgeError(
              BridgeErrorCode.tooLarge, 'bundle image exceeds 5 MiB');
        }
        // Bound the actual read too: CAS may have changed or rotted since download.
        final file =
            File('${casDir.path}${Platform.pathSeparator}${entry.hash}');
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(0, maxBundleShareBytes + 1)) {
          builder.add(chunk);
        }
        data = builder.takeBytes();
        if (data.length > maxBundleShareBytes) {
          throw const BridgeError(
              BridgeErrorCode.tooLarge, 'bundle image exceeds 5 MiB');
        }
        if (data.length != entry.size ||
            sha256.convert(data).toString() != entry.hash) {
          throw const BridgeError(BridgeErrorCode.internal,
              'bundle image failed integrity verification');
        }
      }
      final png = data.length >= 8 &&
          List.generate(8, (i) => data[i]).join(',') ==
              '137,80,78,71,13,10,26,10';
      final jpeg = data.length >= 3 &&
          data[0] == 255 &&
          data[1] == 216 &&
          data[2] == 255;
      if (!png && !jpeg) {
        throw const BridgeError(
            BridgeErrorCode.params, 'only PNG and JPEG images are supported');
      }
      final name = fileName ?? (png ? 'image.png' : 'image.jpg');
      if (png != name.endsWith('.png')) {
        throw const BridgeError(BridgeErrorCode.params,
            'fileName extension does not match image bytes');
      }
      final root = await _temporaryDirectory();
      // Only this fixed host-owned child is cleared, never the app cache root.
      // Wipe links as links rather than following them into another directory.
      final scratch =
          Directory('${root.path}${Platform.pathSeparator}valence-share');
      if (await FileSystemEntity.type(scratch.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const BridgeError(
            BridgeErrorCode.internal, 'invalid image sharing cache');
      }
      await scratch.create(recursive: true);
      await for (final child in scratch.list(followLinks: false)) {
        await child.delete(recursive: true);
      }
      final copy = File('${scratch.path}${Platform.pathSeparator}$name');
      await copy.writeAsBytes(data, flush: true);
      final result = await _present(ShareParams(
        files: [XFile(copy.path, mimeType: png ? 'image/png' : 'image/jpeg')],
        text: caption == null || caption.isEmpty ? null : caption,
        // Native-owned anchor for the iPad popover; no web coordinates or paths.
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      ));
      return switch (result.status) {
        ShareResultStatus.success => 'selected',
        ShareResultStatus.dismissed => 'dismissed',
        ShareResultStatus.unavailable => 'unavailable',
      };
    } on BridgeError {
      rethrow;
    } on Object {
      // No platform messages, private paths or user payloads cross the bridge.
      throw const BridgeError(
          BridgeErrorCode.internal, 'native image sharing failed');
    } finally {
      _busy = false;
    }
  }
}
