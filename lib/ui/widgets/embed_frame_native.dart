import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app WebView support. `webview_flutter` ships implementations for
/// Android, iOS and macOS only; Linux and Windows fall back to direct
/// stream resolution.
bool get isEmbedSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Builds a WebView-based embed frame for supported native platforms.
Widget buildEmbedFrame(String url, {String title = ''}) {
  if (url.trim().isEmpty) return const SizedBox.shrink();
  if (!isEmbedSupported) {
    return const ColoredBox(
      color: Color(0xFF000000),
      child: Center(
        child: Text(
          'встроенный плеер недоступен на этой платформе',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  return _EmbedFrameWebView(url: url, title: title);
}

class _EmbedFrameWebView extends StatefulWidget {
  const _EmbedFrameWebView({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_EmbedFrameWebView> createState() => _EmbedFrameWebViewState();
}

class _EmbedFrameWebViewState extends State<_EmbedFrameWebView> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Ignore errors, let the WebView handle them.
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFA855F7)),
          ),
      ],
    );
  }
}
