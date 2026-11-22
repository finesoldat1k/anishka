import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds a WebView-based embed frame for native platforms (Android, iOS, Linux, macOS, Windows).
Widget buildEmbedFrame(String url, {String title = ''}) {
  if (url.trim().isEmpty) return const SizedBox.shrink();

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
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            // Ignore errors, let the WebView handle them
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