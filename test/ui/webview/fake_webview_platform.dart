import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A recording WebView platform. [log] is shared by every fake it creates, so
/// tests can assert the order of cookie wipes, loads and injected scripts.
class FakeWebViewPlatform extends WebViewPlatform {
  final log = <String>[];
  final controllers = <FakeWebViewController>[];
  int cookieClears = 0;

  /// Installs this fake as the platform; returns it.
  static FakeWebViewPlatform install() {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    return platform;
  }

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final c = FakeWebViewController(params, this);
    controllers.add(c);
    return c;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeNavigationDelegate(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => FakeCookieManager(params, this);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebViewWidget(params);
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params, this._platform) : super.implementation();

  final FakeWebViewPlatform _platform;
  final channels = <String, void Function(JavaScriptMessage)>{};
  final scripts = <String>[];
  final loads = <Uri>[];
  FakeNavigationDelegate? navigation;
  JavaScriptMode? javaScriptMode;

  /// What `currentUrl()` answers; tests move it to simulate navigation.
  String? url;

  /// Delivers [message] as the page would through the JS channel.
  void post(String message) =>
      channels['ReactNativeWebView']!(JavaScriptMessage(message: message));

  Future<NavigationDecision> request(String url, {bool isMainFrame = true}) =>
      Future.value(
        navigation!.onNavigationRequest!(
          NavigationRequest(url: url, isMainFrame: isMainFrame),
        ),
      );

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async =>
      javaScriptMode = mode;

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => navigation = handler as FakeNavigationDelegate;

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async => channels[javaScriptChannelParams.name] =
      javaScriptChannelParams.onMessageReceived;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loads.add(params.uri);
    url = params.uri.toString();
    _platform.log.add('load ${params.uri}');
  }

  @override
  Future<String?> currentUrl() async => url;

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
    _platform.log.add('js');
  }

  @override
  Future<void> clearLocalStorage() async => _platform.log.add('clearStorage');

  @override
  Future<void> clearCache() async => _platform.log.add('clearCache');
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => this.onNavigationRequest = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(super.params, this._platform) : super.implementation();

  final FakeWebViewPlatform _platform;

  @override
  Future<bool> clearCookies() async {
    _platform.cookieClears++;
    _platform.log.add('clearCookies');
    return true;
  }
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('webview'));
}
