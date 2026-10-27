import 'runtime.dart';

/// A store-compiled native extension. Only generated schema cases reach [invoke].
///
/// Return JSON values, not generated Dart model instances. The generated adapter
/// decodes results and parameters against the IDL. Plugins are trusted native
/// code; they own initialization, permissions, subscriptions and cleanup.
abstract interface class ValencePlugin {
  /// One lower-camel namespace, matching the package's schema fragment.
  String get namespace;

  /// Exact wire names, all beginning with `namespace.`.
  Set<String> get methods;

  /// Called after nonce and strict parameter validation by generated dispatch.
  Future<Object?> invoke(
      Valence valence, String method, Map<String, Object?> params);
}

/// Routes generated delegations to a fixed snapshot of installed native plugins.
final class ValencePluginRegistry {
  /// Installs the built-in open group and refuses replacement or duplicate owners.
  ValencePluginRegistry([List<ValencePlugin> plugins = const []]) {
    _handlers['open.external'] = const ValenceOpenPlugin();
    for (final plugin in plugins) {
      final namespace = plugin.namespace;
      if (!_namespace.hasMatch(namespace) ||
          reservedNamespaces.contains(namespace)) {
        throw ArgumentError.value(
            namespace, 'namespace', 'invalid or reserved plugin namespace');
      }
      if (!_namespaces.add(namespace)) {
        throw ArgumentError('duplicate plugin namespace $namespace');
      }
      for (final method in plugin.methods) {
        if (!method.startsWith('$namespace.') || !_method.hasMatch(method)) {
          throw ArgumentError.value(
              method, 'method', 'must be scoped to $namespace');
        }
        if (_handlers.containsKey(method)) {
          throw ArgumentError('duplicate plugin method $method');
        }
        _handlers[method] = plugin;
      }
    }
  }

  /// Checks generated schema requirements in every build mode before dispatch.
  /// Extra native methods remain unreachable unless present in the schema.
  factory ValencePluginRegistry.checked(
    List<ValencePlugin> plugins, {
    Set<String> requiredNamespaces = const {},
    Set<String> requiredMethods = const {},
  }) {
    final registry = ValencePluginRegistry(plugins);
    final missingNamespaces =
        requiredNamespaces.difference(registry._namespaces);
    final missingMethods =
        requiredMethods.difference(registry._handlers.keys.toSet());
    if (missingNamespaces.isNotEmpty || missingMethods.isNotEmpty) {
      throw StateError(
          'Native plugin registration does not match the generated schema: '
          'missing namespaces [${missingNamespaces.join(', ')}], '
          'missing methods [${missingMethods.join(', ')}]. '
          'Register matching plugins in ValenceBuiltins(plugins: [...]) and rebuild the host.');
    }
    return registry;
  }

  /// Namespaces owned by the host, including planned native capabilities.
  static const reservedNamespaces = {
    'app',
    'data',
    'prefs',
    'sync',
    'open',
    'bundle',
    'secure',
    'auth',
    'permissions',
    'notify',
    'badge',
    'push',
    'link',
    'state',
    'http',
    'share',
  };
  static final _namespace = RegExp(r'^[a-z][a-zA-Z0-9]*$');
  static final _method = RegExp(r'^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)+$');
  final _handlers = <String, ValencePlugin>{};
  final _namespaces = <String>{};

  /// Not a raw bridge dispatcher: never expose this directly to a WebView channel.
  Future<Object?> invoke(
      Valence valence, String method, Map<String, Object?> params) {
    final plugin = _handlers[method];
    if (plugin == null) {
      throw BridgeError(BridgeErrorCode.unsupported,
          'native plugin not installed for $method');
    }
    return plugin.invoke(valence, method, Map.unmodifiable(params));
  }
}

/// The existing built-in `open.*` group, using the public plugin contract.
final class ValenceOpenPlugin implements ValencePlugin {
  /// Built-in; applications cannot replace its reserved namespace.
  const ValenceOpenPlugin();

  @override
  String get namespace => 'open';
  @override
  Set<String> get methods => const {'open.external'};

  @override
  Future<Object?> invoke(
      Valence valence, String method, Map<String, Object?> params) async {
    if (method != 'open.external') {
      throw const BridgeError(
          BridgeErrorCode.unsupported, 'unknown open method');
    }
    if (params.length != 1 || params['url'] is! String) {
      throw const BridgeError(
          BridgeErrorCode.params, 'open.external requires a string url');
    }
    await valence.openExternal(params['url']! as String);
    return null;
  }
}
