import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/link_launcher.dart';

/// Kullanım koşulları / gizlilik politikası metnini **uygulama içinde**
/// açar.
///
/// App Store incelemesi, hesap açılan ekranlardan bu metinlere
/// ulaşılabilmesini istiyor. Kullanıcıyı tarayıcıya atmak yerine sayfayı
/// yarım ekran bir sayfada gösteriyoruz; böylece giriş akışı bozulmuyor.
///
/// Web sürümünde gömülü tarayıcı yok; orada bağlantı yeni sekmede açılır.
Future<void> showLegalSheet(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  if (kIsWeb) {
    await openExternalLink(context, url);
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => _LegalSheet(title: title, url: url),
  );
}

class _LegalSheet extends StatefulWidget {
  const _LegalSheet({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_LegalSheet> createState() => _LegalSheetState();
}

class _LegalSheetState extends State<_LegalSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Yalnızca ana sayfanın hatası önemli; alt kaynak hataları değil.
            if (!mounted || !(error.isForMainFrame ?? true)) return;
            setState(() {
              _isLoading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _failed
                  ? _LoadError(
                      url: widget.url,
                      onOpenExternal: () => openExternalLink(context, widget.url),
                    )
                  : Stack(
                      children: <Widget>[
                        WebViewWidget(controller: _controller),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.url, required this.onOpenExternal});

  final String url;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Sayfa açılamadı',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'İnternet bağlantını kontrol edip tekrar dene.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Tarayıcıda aç'),
            ),
          ],
        ),
      ),
    );
  }
}
