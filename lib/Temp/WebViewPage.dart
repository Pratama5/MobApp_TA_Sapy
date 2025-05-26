// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class WebViewPage extends StatelessWidget {
//   final String url;
//   const WebViewPage({Key? key, required this.url}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..loadRequest(Uri.parse(url));

//     return Scaffold(
//       appBar: AppBar(title: const Text("Download Audio")),
//       body: WebViewWidget(controller: controller),
//     );
//   }
// }
