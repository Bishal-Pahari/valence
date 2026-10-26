// Native WebView replacement for app_widget_test.dart. Unimplemented operations fail loudly.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class StubWebViewPlatform extends WebViewPlatform {
  final controllers = <StubWebViewController>[];
  Completer<void>? configureGate;

  StubWebViewController get controller => controllers.single;

  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller = StubWebViewController(params, configureGate);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      StubNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      StubWebViewWidget(params);
}

class StubWebViewController extends PlatformWebViewController {
  StubWebViewController(super.params, this.configureGate)
      : super.implementation();

  final Completer<void>? configureGate;
  final loads = <Uri>[];
  final scripts = <String>[];
  late StubNavigationDelegate navigation;
  late JavaScriptChannelParams channel;
  JavaScriptMode? javaScriptMode;
  bool hasHistory = false;
  int backCount = 0;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    javaScriptMode = mode;
    await configureGate?.future;
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async =>
      channel = params;

  @override
  Future<void> setOnConsoleMessage(
      void Function(JavaScriptConsoleMessage) onConsoleMessage) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
          PlatformNavigationDelegate handler) async =>
      navigation = handler as StubNavigationDelegate;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loads.add(params.uri);

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);

  @override
  Future<bool> canGoBack() async => hasHistory;

  @override
  Future<void> goBack() async => backCount++;
}

class StubNavigationDelegate extends PlatformNavigationDelegate {
  StubNavigationDelegate(super.params) : super.implementation();

  late NavigationRequestCallback request;
  late PageEventCallback started;
  late PageEventCallback finished;

  @override
  Future<void> setOnNavigationRequest(
          NavigationRequestCallback callback) async =>
      request = callback;

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async =>
      started = callback;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      finished = callback;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class StubWebViewWidget extends PlatformWebViewWidget {
  StubWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey('stub-webview'));
}
