import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/secure_storage.dart';
import '../../core/network/dio_client.dart';
import 'pdf_viewer_screen.dart';

/// عرض الدروس النصية / PDF / واجبات في WebView
/// يستخدم نمط ?app=1&token=JWT حتى يعمل app_mode_init ويُحقن __tvvl_app_token
/// تلقائياً، فيتولى tvvl-frontend.js تسجيل المشاهدة عند الخروج بدون تدخل Dart.
class LessonWebScreen extends StatefulWidget {
  final int lessonId;
  final String title;
  const LessonWebScreen(
      {super.key, required this.lessonId, required this.title});

  @override
  State<LessonWebScreen> createState() => _LessonWebScreenState();
}

class _LessonWebScreenState extends State<LessonWebScreen> {
  WebViewController? _ctrl;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // ✅ الحل النهائي المستقر: صفحة lesson-view النظيفة (بدون الثيم)
    // باستخدام play_token قصير العمر.
    // هذا يعرض:
    // - فيديو إن وجد
    // - أو محتوى المحرر (صورة/PDF داخل المحرر) + attachments
    // بدون مشاكل cookies / سواد / redirect.
    final jwt = await SecureStorageService.instance.getToken() ?? '';

    final res = await DioClient.instance.dio.get(
      '${ApiConstants.baseUrl}/app/v1/video-token/${widget.lessonId}',
      options: Options(
        headers: jwt.isNotEmpty ? {'Authorization': 'Bearer $jwt'} : null,
      ),
    );

    final body = res.data;
    final data = (body is Map && body['data'] is Map) ? body['data'] as Map : null;
    final playToken = (data?['token'] as String?) ?? '';
    final playerUrl = (data?['player_url'] as String?) ?? '';

    if (playToken.isEmpty || playerUrl.isEmpty) {
      throw Exception('تعذّر إنشاء توكن الدرس');
    }

    final url =
        '$playerUrl${playerUrl.contains('?') ? '&' : '?'}play_token=${Uri.encodeComponent(playToken)}';

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('kwafledu-app')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          // اعتراض نقرات واتساب فقط — تسجيل المشاهدة يتولاه tvvl-frontend.js
          _ctrl?.runJavaScript(
            '(function(){'
            '  document.addEventListener("click",function(e){'
            '    var el=e.target.closest?e.target.closest("a[href]"):null;'
            '    if(!el) return;'
            '    var href=el.getAttribute("href")||"";'
            '    var isWa=href.indexOf("whatsapp://")===0||href.indexOf("https://wa.me")===0||href.indexOf("http://wa.me")===0;'
            '    if(isWa){ e.preventDefault(); e.stopPropagation(); if(window.WaChannel) window.WaChannel.postMessage(href); }'
            '  },true);'
            '})();',
          );
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted) {
            setState(() {
              _hasError = true;
              _loading  = false;
            });
          }
        },
        onNavigationRequest: (req) {
          final uri    = Uri.tryParse(req.url);
          final scheme = uri?.scheme ?? '';
          final host   = uri?.host   ?? '';

          // واتساب → افتح في المتصفح الخارجي
          final isWhatsApp = scheme == 'whatsapp' ||
              host == 'wa.me' ||
              host.endsWith('.wa.me');

          if (isWhatsApp && uri != null) {
            Uri launchUri = uri;
            if (scheme == 'whatsapp') {
              final phone   = uri.queryParameters['phone'] ?? '';
              final text    = uri.queryParameters['text']  ?? '';
              if (phone.isNotEmpty) {
                final encoded = Uri.encodeComponent(text);
                launchUri = Uri.parse(
                  text.isNotEmpty
                      ? 'https://wa.me/' + phone + '?text=' + encoded
                      : 'https://wa.me/' + phone,
                );
              }
            }
            launchUrl(launchUri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }

          if ((scheme == 'tel' || scheme == 'mailto') && uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      // AppChannel + VideoEvents: صفحة lesson-view قد ترسل أحداث PDF عبر
      // أي من القناتين حسب نسخة الإضافة، لذلك ندعم القناتين.
      ..addJavaScriptChannel('AppChannel', onMessageReceived: _onBridgeMessage)
      ..addJavaScriptChannel('VideoEvents', onMessageReceived: _onBridgeMessage)
      ..addJavaScriptChannel('WaChannel',
          onMessageReceived: (msg) => _onWaLink(msg.message))
      ..loadRequest(Uri.parse(url));

    setState(() => _ctrl = ctrl);
  }

  void _onBridgeMessage(JavaScriptMessage msg) {
    final data = msg.message;
    String url = '';

    if (data.startsWith('pdf_inline:')) {
      url = data.substring('pdf_inline:'.length);
    } else if (data.startsWith('pdf:')) {
      url = data.substring('pdf:'.length);
    } else if (data.startsWith('open:')) {
      final openUrl = data.substring('open:'.length).trim();
      final uri = Uri.tryParse(openUrl);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    url = url.trim();
    if (url.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(url: url, title: widget.title),
        ),
      );
    }
  }

  void _onWaLink(String href) {
    Uri? uri;
    if (href.startsWith('whatsapp://')) {
      final raw   = Uri.tryParse(href);
      final phone = raw?.queryParameters['phone'] ?? '';
      final text  = raw?.queryParameters['text']  ?? '';
      if (phone.isNotEmpty) {
        final encoded = Uri.encodeComponent(text);
        uri = Uri.parse(
          text.isNotEmpty
              ? 'https://wa.me/' + phone + '?text=' + encoded
              : 'https://wa.me/' + phone,
        );
      }
    } else {
      uri = Uri.tryParse(href);
    }
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: Stack(children: [
        if (_ctrl != null) WebViewWidget(controller: _ctrl!),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_hasError)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل المحتوى'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ]),
          ),
      ]),
    );
  }
}
