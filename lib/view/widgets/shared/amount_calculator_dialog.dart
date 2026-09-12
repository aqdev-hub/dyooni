import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

Future<double?> showAmountCalculatorDialog(BuildContext context, {String initialValue = ''}) => showDialog<double?>(
      context: context,
      builder: (_) => _AmountCalculatorDialog(initialValue: initialValue),
    );

class _AmountCalculatorDialog extends StatefulWidget {
  const _AmountCalculatorDialog({required this.initialValue});
  final String initialValue;

  @override
  State<_AmountCalculatorDialog> createState() => _AmountCalculatorDialogState();
}

class _AmountCalculatorDialogState extends State<_AmountCalculatorDialog> {
  late String _expression = widget.initialValue;
  String _display = '';

  @override
  void initState() {
    super.initState();
    _display = _expression;
  }

  void _tap(String value) {
    setState(() {
      if (value == 'C') {
        _expression = '';
        _display = '';
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) _expression = _expression.substring(0, _expression.length - 1);
        _display = _expression;
      } else if (value == '=') {
        final result = _evaluate(_expression);
        _display = result == null ? _expression : _format(result);
        if (result != null) _expression = _display;
      } else {
        _expression += value;
        _display = _expression;
      }
    });
  }

  double? _evaluate(String expression) {
    final normalized = expression.replaceAll(' ', '').replaceAll('×', '*').replaceAll('÷', '/');
    final tokens = RegExp(r'(\d+(?:\.\d+)?|[+\-*/])').allMatches(normalized).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty || tokens.join() != normalized) return null;
    final parsedFirst = double.tryParse(tokens.first);
    if (parsedFirst == null) return null;
    double value = parsedFirst;
    for (var i = 1; i + 1 < tokens.length; i += 2) {
      final right = double.tryParse(tokens[i + 1]);
      if (right == null) return null;
      switch (tokens[i]) {
        case '+': value += right;
        case '-': value -= right;
        case '*': case '×': value *= right;
        case '/': case '÷': if (right == 0) return null; value /= right;
        default: return null;
      }
    }
    return value;
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final keys = ['C', '⌫', '÷', '×', '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '=', '0', '00', '000', '.'];
    return AlertDialog(
      backgroundColor: shell.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(l10n.calculatorTitle, textAlign: TextAlign.center, style: AppTextStyles.title(context).copyWith(color: shell.textPrimary)),
      content: SizedBox(
        width: 310,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: shell.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: shell.border),
              ),
              child: Text(
                _display.isEmpty ? '0' : _display,
                textAlign: TextAlign.end,
                style: AppTextStyles.title(context).copyWith(color: shell.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              children: [
                for (final key in keys)
                  OutlinedButton(
                    onPressed: () => _tap(key),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: ['+', '-', '×', '÷', '='].contains(key) ? shell.accent : shell.textPrimary,
                    ),
                    child: Text(key, style: AppTextStyles.body(context).copyWith(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = _evaluate(_expression) ?? double.tryParse(_expression);
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.calculatorApply),
        ),
      ],
    );
  }
}
