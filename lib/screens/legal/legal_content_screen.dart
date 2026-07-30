import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

/// Renders Privacy Policy / Terms & Conditions natively in-app (same
/// Setting-backed content as the public web page), with a plain back arrow
/// that returns to whatever screen pushed this one — unlike the web page,
/// there's no "Back to site" link to a marketing site that doesn't make sense
/// once the content is already embedded in the app.
class LegalContentScreen extends StatefulWidget {
  final String type; // 'privacy' | 'terms'
  const LegalContentScreen({super.key, required this.type});

  @override
  State<LegalContentScreen> createState() => _LegalContentScreenState();
}

class _LegalContentScreenState extends State<LegalContentScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String _title = '';
  String _content = '';
  String _updated = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getLegalContent(widget.type);
      if (!mounted) return;
      setState(() {
        _title   = (data['title'] as String?) ?? (widget.type == 'terms' ? 'Terms & Conditions' : 'Privacy Policy');
        _content = (data['content'] as String?) ?? '';
        _updated = (data['updated'] as String?) ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        leading: IconButton(
          icon: const Icon(UniconsLine.arrow_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.type == 'terms' ? 'Terms & Conditions' : 'Privacy Policy',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(UniconsLine.exclamation_triangle, size: 40, color: c.textHint),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ]),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_title, style: GoogleFonts.sora(
                          fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      if (_updated.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Last updated: $_updated',
                            style: TextStyle(color: c.textHint, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      if (_content.isNotEmpty)
                        _MarkdownBody(source: _content, c: c)
                      else
                        Text('This page has not been published yet. Please check back later.',
                            style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.6)),
                      const SizedBox(height: 32),
                    ]),
                  ),
      ),
    );
  }
}

/// Minimal line-based Markdown renderer covering exactly what admin-authored
/// legal content uses: #/##/### headings, "- " bullet lists, and **bold**
/// inline spans. Deliberately not a full CommonMark implementation — avoids
/// pulling in a Markdown package for a handful of simple, well-known patterns.
class _MarkdownBody extends StatelessWidget {
  final String source;
  final AppColorScheme c;
  const _MarkdownBody({required this.source, required this.c});

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');

  List<InlineSpan> _inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _boldPattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(1), style: base.copyWith(fontWeight: FontWeight.w800)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = TextStyle(color: c.textPrimary, fontSize: 14, height: 1.6);
    final widgets = <Widget>[];

    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(line.substring(4),
              style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(line.substring(3),
              style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(line.substring(2),
              style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: bodyStyle),
            Expanded(child: Text.rich(TextSpan(style: bodyStyle, children: _inlineSpans(line.substring(2), bodyStyle)))),
          ]),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(style: bodyStyle, children: _inlineSpans(line, bodyStyle))),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
