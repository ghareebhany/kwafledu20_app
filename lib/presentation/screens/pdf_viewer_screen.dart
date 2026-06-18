import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/network/dio_client.dart';

/// Native PDF viewer: page-by-page full screen.
class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  const PdfViewerScreen({
    super.key,
    required this.url,
    this.title = 'PDF',
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfController? _controller;
  int? _pagesCount;
  int _current = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Download bytes using the app's Dio (keeps base settings and avoids
      // depending on WebView/cookies). If the URL is public, this works directly.
      final res = await DioClient.instance.dio.get<List<int>>(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final raw = res.data;
      if (raw == null || raw.isEmpty) {
        throw Exception('Empty PDF response');
      }

      final bytes = Uint8List.fromList(raw);
      final doc = await PdfDocument.openData(bytes);
      final c = PdfController(document: Future.value(doc));
      setState(() {
        _controller = c;
        _pagesCount = doc.pagesCount;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_pagesCount != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  '$_current / $_pagesCount',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 10),
                        const Text('تعذر فتح ملف PDF',
                            style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(
                          _error!.replaceAll('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _init,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        )
                      ],
                    ),
                  ),
                )
              : PdfView(
                  controller: _controller!,
                  pageSnapping: true,
                  onPageChanged: (page) {
                    setState(() => _current = page);
                  },
                ),
    );
  }
}
