import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'wire.dart';

/// The bounded local notification service. The native adapter never receives page file paths or URLs.
final class ValenceNotifications {
  /// Creates an enabled service. [directory] is private host storage, never a page-supplied path.
  ValenceNotifications({
    required this.directory,
    required this.emit,
    this.icon = 'ic_stat_valence',
    ValenceNotificationPlatform? platform,
    DateTime Function()? now,
  })  : _platform = platform ?? ValenceNotificationPlatform(),
        _now = now ?? DateTime.now;

  /// Private attachment directory.
  final Directory directory;

  /// Emits a warm response after escaping through the wire event builder.
  final void Function(String) emit;

  /// A compiled Android drawable resource name.
  final String icon;
  final ValenceNotificationPlatform _platform;
  final DateTime Function() _now;
  Future<void>? _initialized;
  Future<void> _tail = Future.value();
  Map<String, Object?>? _initial;

  /// Registers callbacks and captures a cold-start tap without prompting.
  Future<void> initialize() => _initialized ??= _initialize();

  Future<void> _initialize() async {
    _identifier(icon, 'icon');
    final response = await _platform.initialize(icon, _respond);
    _initial = _response(response);
  }

  void _respond(NotificationResponse response) {
    final value = _response(response);
    if (value != null) {
      emit(eventScript(
          value['action'] == null ? 'notify.tapped' : 'notify.action', value));
    }
  }

  Map<String, Object?>? _response(NotificationResponse? response) {
    if (response == null ||
        response.id == null ||
        response.id! < 0 ||
        response.id! > 0x7fffffff) {
      return null;
    }
    final raw = response.payload;
    if (raw == null || utf8.encode(raw).length > 26000) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['valence'] != 'local-v1' ||
          data['payload'] is! String) {
        return null;
      }
      final payload = data['payload'] as String;
      if (utf8.encode(payload).length > 4096) return null;
      final action = response.actionId;
      if (action != null && action.isNotEmpty && !actions.containsKey(action)) {
        return null;
      }
      return {
        'id': response.id,
        'payload': payload,
        'action': action == null || action.isEmpty ? null : action
      };
    } on FormatException {
      return null;
    }
  }

  /// The response that launched the process, consumed once. Does not also emit a warm event.
  Future<Object?> initial() async {
    await initialize();
    final value = _initial;
    _initial = null;
    return value;
  }

  /// Passive by default; requesting notification authorization is always explicit.
  Future<bool> permission({bool request = false}) async {
    await initialize();
    return _platform.permission(request: request);
  }

  // Serializes scheduler mutations so concurrent bridge calls cannot overrun the native pending cap.
  Future<T> _serial<T>(Future<T> Function() run) {
    final task = _tail.then((_) => run());
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  /// Schedules one absolute instant. Returning a timing mode does not promise delivery.
  Future<Map<String, Object?>> schedule({
    required int id,
    required String title,
    required int at,
    String? body,
    String? channel,
    bool exact = false,
    String? payload,
    String? image,
    List<String> actionIds = const [],
    String? group,
  }) =>
      _serial(() async {
        _id(id);
        _text(title, 'title', 256);
        _text(body ?? '', 'body', 4096);
        _text(payload ?? '', 'payload', 4096);
        final delta = at - _now().millisecondsSinceEpoch;
        if (delta <= 0 || delta > const Duration(days: 366).inMilliseconds) {
          _bad('at must be within the next 366 days');
        }
        final channelId = channel ?? 'valence_reminders';
        _identifier(channelId, 'channel');
        if (group != null) _identifier(group, 'group');
        if (actionIds.length > 3 ||
            actionIds.toSet().length != actionIds.length ||
            actionIds.any((a) => !actions.containsKey(a))) {
          _bad('unknown or duplicate action');
        }
        final bytes = image == null ? null : _image(image);
        if (bytes != null) await _validateImage(bytes);
        await initialize();
        if (!await permission()) return {'id': id, 'timing': 'blocked'};
        final pending = await _platform.pending();
        if (pending.length >= 64 && !pending.any((r) => r.id == id)) {
          throw const BridgeError(
              BridgeErrorCode.tooLarge, 'at most 64 pending notifications');
        }
        // An auto-created channel has a stable policy. Explicit channels.set should run before scheduling.
        await _platform.channel(
            id: channelId,
            ifAbsent: true,
            name: channelId == 'valence_reminders' ? 'Reminders' : channelId);
        var mode = exact && await _platform.canExact()
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
        final details = await _platform.details(
          directory: directory,
          id: id,
          channel: channelId,
          image: bytes,
          actionIds: actionIds,
          group: group,
        );
        Future<void> send() => _platform.schedule(
              id: id,
              title: title,
              body: body,
              at: at,
              details: details,
              mode: mode,
              payload:
                  jsonEncode({'valence': 'local-v1', 'payload': payload ?? ''}),
            );
        try {
          await send();
        } on PlatformException catch (e) {
          // Android may revoke access between canScheduleExactNotifications and the actual call.
          if (mode != AndroidScheduleMode.exactAllowWhileIdle ||
              e.code != 'exact_alarms_not_permitted') {
            rethrow;
          }
          mode = AndroidScheduleMode.inexactAllowWhileIdle;
          await send();
        }
        return {
          'id': id,
          'timing': _platform.isIOS
              ? 'system'
              : mode == AndroidScheduleMode.exactAllowWhileIdle
                  ? 'exact'
                  : 'inexact'
        };
      });

  /// Returns native pending requests; no cached shadow queue.
  Future<List<Map<String, Object?>>> pending() async {
    await initialize();
    return [
      for (final r in await _platform.pending())
        {
          'id': r.id,
          'title': r.title,
          'body': r.body,
          'payload': _response(NotificationResponse(
              id: r.id,
              payload: r.payload,
              notificationResponseType:
                  NotificationResponseType.selectedNotification))?['payload'],
        }
    ];
  }

  /// Cancels only this ID. Never cancel-all during a rolling-window refill.
  Future<void> cancel(int id) => _serial(() async {
        _id(id);
        await initialize();
        await _platform.cancel(id);
        for (final ext in ['png', 'jpg']) {
          final file = File('${directory.path}/$id.$ext');
          if (await file.exists()) await file.delete();
        }
      });

  /// Creates Android channels and optional channel groups. Existing policies remain OS-controlled.
  Future<void> channel(
          {required String id,
          required String name,
          String importance = 'default',
          String? sound,
          String? group,
          String? groupName}) =>
      _serial(() async {
        _identifier(id, 'id');
        _text(name, 'name', 128);
        if (name.isEmpty) _bad('channel name must not be empty');
        if (!const {'min', 'low', 'default', 'high', 'max'}
            .contains(importance)) {
          _bad('unknown importance');
        }
        if (sound != null && sound.isNotEmpty) _identifier(sound, 'sound');
        if (group != null) _identifier(group, 'group');
        _text(groupName ?? '', 'groupName', 128);
        await initialize();
        await _platform.channel(
            id: id,
            name: name,
            importance: importance,
            sound: sound,
            group: group,
            groupName: groupName);
      });

  /// Best-effort badge update; true means the supported platform accepted the request.
  Future<bool> badge(int n) async {
    if (n < 0 || n > 9999) _bad('badge must be 0..9999');
    await initialize();
    if (!await permission()) return false;
    return _platform.badge(n);
  }

  static void _id(int id) {
    if (id < 0 || id > 0x7fffffff) _bad('id must be 0..2147483647');
  }

  static void _identifier(String value, String field) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
      _bad('$field must be a lowercase resource identifier');
    }
  }

  static void _text(String value, String field, int max) {
    if (utf8.encode(value).length > max) {
      throw BridgeError(
          BridgeErrorCode.tooLarge, '$field exceeds $max UTF-8 bytes');
    }
  }

  static Never _bad(String message) =>
      throw BridgeError(BridgeErrorCode.params, message);

  static Uint8List _image(String raw) {
    if (raw.length > 131072) {
      throw const BridgeError(BridgeErrorCode.tooLarge, 'image exceeds 96 KiB');
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(raw);
    } on FormatException {
      _bad('image must be base64 PNG or JPEG');
    }
    if (bytes.length > 98304) {
      throw const BridgeError(BridgeErrorCode.tooLarge, 'image exceeds 96 KiB');
    }
    int width = 0, height = 0;
    if (bytes.length >= 24 &&
        base64Encode(bytes.sublist(0, 8)) == 'iVBORw0KGgo=' &&
        ascii.decode(bytes.sublist(12, 16), allowInvalid: true) == 'IHDR') {
      final header = ByteData.sublistView(bytes);
      width = header.getUint32(16);
      height = header.getUint32(20);
    } else if (bytes.length > 4 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      var pos = 2;
      while (pos + 4 < bytes.length) {
        if (bytes[pos] != 0xff) break;
        final marker = bytes[pos + 1];
        if (marker == 0xda || marker == 0xd9) break;
        final length = bytes[pos + 2] * 256 + bytes[pos + 3];
        if (length < 2 || pos + 2 + length > bytes.length) break;
        if (const {0xc0, 0xc1, 0xc2}.contains(marker) && length >= 7) {
          height = bytes[pos + 5] * 256 + bytes[pos + 6];
          width = bytes[pos + 7] * 256 + bytes[pos + 8];
          break;
        }
        pos += length + 2;
      }
    }
    if (width < 1 || height < 1 || width > 1024 || height > 1024) {
      _bad('PNG/JPEG image must be at most 1024 pixels per side');
    }
    return bytes;
  }

  static Future<void> _validateImage(Uint8List bytes) async {
    // Header bounds are checked first. A bounded decode then catches corrupt pixels/CRC rather than
    // returning "scheduled" while the native notification silently drops its picture.
    try {
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 1024, targetHeight: 1024, allowUpscaling: false);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } on Object {
      _bad('image pixels could not be decoded as PNG or JPEG');
    }
  }

  /// Store-compiled action IDs. Every action opens the UI; no background UI activation occurs.
  static const actions = {'open': 'Open', 'done': 'Done', 'snooze': 'Snooze'};
}

/// The native adapter; replace in tests to exercise policy separately from OS method channels.
class ValenceNotificationPlatform {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Whether native delivery timing is controlled by iOS.
  bool get isIOS => Platform.isIOS;
  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Registers compiled categories and the foreground callback; does not prompt.
  Future<NotificationResponse?> initialize(
      String icon, void Function(NotificationResponse) respond) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const BridgeError(
          BridgeErrorCode.unsupported, 'notifications need Android or iOS');
    }
    await _plugin.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings(icon),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
              notificationCategories: [
                for (var mask = 1; mask < 8; mask++)
                  DarwinNotificationCategory('valence_$mask', actions: [
                    for (var i = 0; i < 3; i++)
                      if ((mask & (1 << i)) != 0)
                        DarwinNotificationAction.plain(
                            ValenceNotifications.actions.keys.elementAt(i),
                            ValenceNotifications.actions.values.elementAt(i),
                            options: {
                              DarwinNotificationActionOption.foreground
                            }),
                  ]),
              ]),
        ),
        onDidReceiveNotificationResponse: respond);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse
        : null;
  }

  /// Passive authorization check or explicit prompt.
  Future<bool> permission({required bool request}) async {
    if (_android case final android?) {
      return (request
              ? await android.requestNotificationsPermission()
              : await android.areNotificationsEnabled()) ??
          false;
    }
    if (_ios case final ios?) {
      if (request) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    return false;
  }

  /// Android's exact access is independent of notification permission.
  Future<bool> canExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  /// Native pending snapshot.
  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  /// Cancels one pending or displayed request.
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// Creates channel and group before use. Android ignores attempts to alter immutable policies.
  Future<void> channel(
      {required String id,
      required String name,
      String importance = 'default',
      String? sound,
      String? group,
      String? groupName,
      bool ifAbsent = false}) async {
    final android = _android;
    if (android == null) return;
    // Scheduling must not rename a configured channel or remove its group.
    if (ifAbsent) {
      if ((await android.getNotificationChannels())?.any((c) => c.id == id) ==
          true) {
        return;
      }
    }
    if (group != null) {
      await android.createNotificationChannelGroup(
          AndroidNotificationChannelGroup(group, groupName ?? group));
    }
    await android.createNotificationChannel(AndroidNotificationChannel(id, name,
        importance: {
          'min': Importance.min,
          'low': Importance.low,
          'default': Importance.defaultImportance,
          'high': Importance.high,
          'max': Importance.max
        }[importance]!,
        playSound: sound != '',
        sound: sound == null || sound.isEmpty
            ? null
            : RawResourceAndroidNotificationSound(sound),
        groupId: group));
  }

  /// Converts already-validated bytes into platform details. No page file paths reach this method.
  Future<NotificationDetails> details(
      {required Directory directory,
      required int id,
      required String channel,
      Uint8List? image,
      required List<String> actionIds,
      String? group}) async {
    String? attachment;
    if (isIOS && image != null) {
      await directory.create(recursive: true);
      final keep = {for (final r in await pending()) r.id};
      // UNUserNotificationCenter owns a copy after accepting the request. Keep source files only
      // for pending IDs; old delivered/cancelled IDs and alternate extensions cannot accumulate.
      await for (final entry in directory.list()) {
        final leaf = entry.uri.pathSegments.last;
        final match = RegExp(r'^(\d+)\.(png|jpg)$').firstMatch(leaf);
        if (entry is File &&
            match != null &&
            (!keep.contains(int.parse(match[1]!)) ||
                int.parse(match[1]!) == id)) {
          await entry.delete();
        }
      }
      final file =
          File('${directory.path}/$id.${image[0] == 0x89 ? 'png' : 'jpg'}');
      await file.writeAsBytes(image, flush: true);
      attachment = file.path;
    }
    var mask = 0;
    for (final id in actionIds) {
      mask |= 1 << ValenceNotifications.actions.keys.toList().indexOf(id);
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(channel, channel,
          groupKey: group,
          styleInformation: image == null
              ? null
              : BigPictureStyleInformation(ByteArrayAndroidBitmap(image)),
          actions: [
            for (final id in actionIds)
              AndroidNotificationAction(id, ValenceNotifications.actions[id]!,
                  showsUserInterface: true)
          ]),
      iOS: DarwinNotificationDetails(
          categoryIdentifier: mask == 0 ? null : 'valence_$mask',
          threadIdentifier: group,
          attachments: attachment == null
              ? null
              : [DarwinNotificationAttachment(attachment)]),
    );
  }

  /// Schedules an absolute UTC instant: no tz.local default or trimmed timezone database involved.
  Future<void> schedule(
          {required int id,
          required String title,
          String? body,
          required int at,
          required NotificationDetails details,
          required AndroidScheduleMode mode,
          required String payload}) =>
      _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, at),
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: payload);

  /// Returns acceptance, not proof of a visible launcher change.
  Future<bool> badge(int n) async {
    try {
      if (_ios case final ios?) {
        if ((await ios.checkPermissions())?.isBadgeEnabled != true) {
          return false;
        }
      }
      if (!await AppBadgePlus.isSupported()) return false;
      await AppBadgePlus.updateBadge(n);
      return true;
    } on PlatformException {
      return false;
    }
  }
}
