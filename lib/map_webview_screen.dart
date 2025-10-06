import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapWebViewScreen extends StatefulWidget {
  final Uri url;
  final String? title;
  const MapWebViewScreen({super.key, required this.url, this.title});

  @override
  State<MapWebViewScreen> createState() => _MapWebViewScreenState();
}

class _MapWebViewScreenState extends State<MapWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100.0),
        ),
      )
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Map'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(value: _progress, minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
