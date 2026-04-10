import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../services/translation_service.dart';
import '../constants/app_colors.dart';

/// A widget that displays user-generated text with auto-translation.
/// Shows a "🌐 Translated" badge and "Show original" toggle when the
/// content has been translated to the user's preferred language.
class TranslatedText extends ConsumerStatefulWidget {
  final String text;
  final String? sourceLang;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText({
    super.key,
    required this.text,
    this.sourceLang,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  ConsumerState<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends ConsumerState<TranslatedText> {
  String? _translatedText;
  bool _isLoading = false;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translate();
    }
  }

  Future<void> _translate() async {
    final locale = ref.read(localeProvider);
    final targetLang = locale.languageCode;

    // Don't translate if already in target language
    if (widget.sourceLang == targetLang || targetLang == 'en') {
      setState(() => _translatedText = null);
      return;
    }

    setState(() => _isLoading = true);

    final result = await TranslationService.instance.translate(
      widget.text,
      targetLang,
      sourceLang: widget.sourceLang,
    );

    if (mounted) {
      setState(() {
        _translatedText = result != widget.text ? result : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to locale changes and re-translate
    ref.listen(localeProvider, (_, __) => _translate());

    final displayText =
        (_showOriginal || _translatedText == null)
            ? widget.text
            : _translatedText!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayText,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textLight,
              ),
            ),
          ),
        if (_translatedText != null && !_isLoading)
          GestureDetector(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌐 ', style: GoogleFonts.inter(fontSize: 10)),
                  Text(
                    _showOriginal ? 'Show translation' : 'Show original',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.reportedBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
