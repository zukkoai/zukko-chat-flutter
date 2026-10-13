import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../data/models/chatwoot_user.dart';
import '../../shared/sdk_log.dart';
import '../../shared/url_policy.dart';
import 'bridge.dart';
import 'token_store.dart';

export 'token_store.dart' show ChatwootTokenStore;

/// Chatwoot web widget in a webview.
/// {@category FlutterClientSdk}
class ChatwootWidget extends StatefulWidget {
  /// Website channel token
  final String websiteToken;

  /// Installation url for chatwoot
  final String baseUrl;

  /// Information about the user like email, username and avatar_url
  final ChatwootUser? user;

  /// User locale
  final String locale;

  /// Widget Close event
  final void Function()? closeWidget;

  /// Additional information about the customer (must be JSON-encodable)
  final Object? customAttributes;

  /// Widget Attachment event. Currently supported only on Android devices
  final Future<List<String>> Function()? onAttachFile;

  /// Widget Load started event
  final void Function()? onLoadStarted;

  /// Widget Load progress event
  final void Function(int)? onLoadProgress;

  /// Widget Load completed event
  final void Function()? onLoadCompleted;

  /// The page could not be loaded (e.g. offline); gets a description.
  final void Function(String description)? onError;

  /// Where the conversation token is kept; defaults to secure storage.
  final ChatwootTokenStore tokenStore;

  /// Allow a plain `http://` [baseUrl] that is not loopback. Development only.
  final bool allowInsecure;

  const ChatwootWidget({
    super.key,
    required this.websiteToken,
    required this.baseUrl,
    this.user,
    this.locale = 'en',
    this.customAttributes,
    this.closeWidget,
    this.onAttachFile,
    this.onLoadStarted,
    this.onLoadProgress,
    this.onLoadCompleted,
    this.onError,
    this.tokenStore = const SecureTokenStore(),
    this.allowInsecure = false,
  });

  /// Sign-out: forgets the stored conversation of [user] and wipes the
  /// webview's cookies, local storage and cache, so the next user cannot
  /// land in this user's widget session. Call it on logout.
  static Future<void> clearStoredConversation({
    required String baseUrl,
    required String websiteToken,
    ChatwootUser? user,
    ChatwootTokenStore tokenStore = const SecureTokenStore(),
  }) async {
    await tokenStore.delete(
      conversationTokenScope(
        baseUrl: baseUrl,
        websiteToken: websiteToken,
        userIdentifier: user?.identifier,
      ),
    );
    await _wipeWebData(WebViewController());
  }

  @override
  State<ChatwootWidget> createState() => _ChatwootWidgetState();
}

Future<void> _wipeWebData(WebViewController controller) async {
  await WebViewCookieManager().clearCookies();
  await controller.clearLocalStorage();
  await controller.clearCache();
}

/// One page load: everything the bridge needs is captured here, so a message
/// from a superseded webview can never be attributed to the current target.
class _Load {
  _Load(this.url, this.scope, this.controller);
  final Uri url;
  final String scope;
  final WebViewController controller;
  bool loaded = false; // `loaded` is honoured once per load
}

class _ChatwootWidgetState extends State<ChatwootWidget> {
  _Load? _current;
  int _generation = 0; // discards results of superseded _load() calls

  String get _scope => conversationTokenScope(
    baseUrl: widget.baseUrl,
    websiteToken: widget.websiteToken,
    userIdentifier: widget.user?.identifier,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ChatwootWidget old) {
    super.didUpdateWidget(old);
    final sameTarget =
        old.baseUrl == widget.baseUrl &&
        old.websiteToken == widget.websiteToken &&
        old.user?.identifier == widget.user?.identifier;
    if (!sameTarget) {
      _current = null;
      unawaited(_load(wipe: true));
    } else if (old.locale != widget.locale ||
        old.user != widget.user ||
        old.customAttributes != widget.customAttributes) {
      final load = _current;
      if (load != null) unawaited(_inject(load));
    }
  }

  @override
  void dispose() {
    _generation++;
    _current = null;
    super.dispose();
  }

  Future<bool> _onWidgetPage(_Load load) async {
    try {
      return isWidgetPage(load.url, await load.controller.currentUrl());
    } catch (e) {
      sdkLog('current url failed: $e');
      return false;
    }
  }

  /// Sends user/locale/attributes to the page, only while it is the widget.
  Future<void> _inject(_Load load) async {
    final String script;
    try {
      script = generateScripts(
        user: widget.user,
        locale: widget.locale,
        customAttributes: widget.customAttributes,
      );
    } catch (e) {
      widget.onError?.call('invalid widget parameters: $e');
      return;
    }
    if (script.isEmpty || !await _onWidgetPage(load)) return;
    if (!mounted || !identical(load, _current)) return;
    try {
      await load.controller.runJavaScript(script);
    } catch (e) {
      sdkLog('inject failed: $e');
    }
  }

  Future<void> _load({bool wipe = false}) async {
    final generation = ++_generation;
    final scope = _scope; // fixed for this load, whatever the widget becomes
    String? token;
    try {
      token = await widget.tokenStore.read(scope);
    } catch (e) {
      sdkLog('token read failed: $e');
    }
    if (!mounted || generation != _generation) return;

    final Uri url;
    try {
      validateBaseUrl(widget.baseUrl, allowInsecure: widget.allowInsecure);
      url = widgetUri(
        widget.baseUrl,
        websiteToken: widget.websiteToken,
        locale: widget.locale,
        token: token,
      );
    } on FormatException catch (e) {
      widget.onError?.call(e.message);
      return;
    } on ArgumentError catch (e) {
      widget.onError?.call(e.message.toString());
      return;
    }

    final controller = WebViewController();
    final load = _Load(url, scope, controller);
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => widget.onLoadProgress?.call(p),
          onPageStarted: (_) => widget.onLoadStarted?.call(),
          onPageFinished: (_) => widget.onLoadCompleted?.call(),
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) widget.onError?.call(e.description);
          },
          onNavigationRequest: (request) {
            switch (decideNavigation(
              url,
              request.url,
              isMainFrame: request.isMainFrame,
            )) {
              case NavigationVerdict.allow:
                return NavigationDecision.navigate;
              case NavigationVerdict.launchExternally:
                final uri = Uri.tryParse(request.url);
                if (uri != null) {
                  unawaited(
                    launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ).catchError((Object e) {
                      sdkLog('launch failed: $e');
                      return false;
                    }),
                  );
                }
                return NavigationDecision.prevent;
              case NavigationVerdict.block:
                return NavigationDecision.prevent;
            }
          },
        ),
      );
    // Residual risk: a hostile iframe inside /widget can still post here.
    await controller.addJavaScriptChannel(
      'ReactNativeWebView',
      onMessageReceived: (m) => _onBridgeMessage(load, m.message),
    );

    final platform = controller.platform;
    if (platform is AndroidWebViewController && widget.onAttachFile != null) {
      // Read at call time: the host may have rebuilt with another callback.
      unawaited(
        platform.setOnShowFileSelector(
          (_) => widget.onAttachFile?.call() ?? Future.value(const <String>[]),
        ),
      );
    }

    try {
      if (wipe) await _wipeWebData(controller); // before the new session loads
      if (!mounted || generation != _generation) return;
      _current = load; // from here on the page may talk to us
      await controller.loadRequest(url);
    } catch (e) {
      if (mounted && generation == _generation) {
        widget.onError?.call(e.toString());
      }
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {});
  }

  void _onBridgeMessage(_Load load, String raw) {
    if (!mounted || !identical(load, _current)) return;
    switch (parseBridgeMessage(raw)) {
      case BridgeLoaded(:final authToken):
        unawaited(_onLoaded(load, authToken));
      case BridgeClose():
        unawaited(_onClose(load));
      case BridgeIgnored():
        break;
    }
  }

  Future<void> _onLoaded(_Load load, String authToken) async {
    if (load.loaded || !await _onWidgetPage(load)) return;
    if (!mounted || !identical(load, _current) || load.loaded) return;
    load.loaded = true;
    try {
      await widget.tokenStore.write(load.scope, authToken);
    } catch (e) {
      sdkLog('token write failed: $e');
    }
    await _inject(load);
  }

  Future<void> _onClose(_Load load) async {
    if (!await _onWidgetPage(load)) return;
    if (mounted && identical(load, _current)) widget.closeWidget?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = _current?.controller;
    return c == null ? const SizedBox.shrink() : WebViewWidget(controller: c);
  }
}
