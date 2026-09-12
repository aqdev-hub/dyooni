import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/report_options.dart';
import 'report_share_format_sheet.dart';
import 'report_sort_sheet.dart';

/// Generic over the report-type enum ([SummaryReportType] or [AccountReportType]) so one widget
/// serves both entry points. The three callbacks receive whatever was configured in the sheet at
/// the moment an action icon was tapped; the caller decides what "generate" actually means for
/// its own report type.
class ReportOptionsSheet<T> extends StatefulWidget {
  const ReportOptionsSheet({
    required this.options,
    required this.initialType,
    required this.onGeneratePdf,
    required this.onGenerateExcel,
    required this.onShareViaWhatsapp,
    super.key,
  });

  final List<(T value, String label)> options;
  final T initialType;
  final void Function(T type, ReportSortOption? sort, DateTimeRange? range) onGeneratePdf;
  final void Function(T type, ReportSortOption? sort, DateTimeRange? range) onGenerateExcel;
  final void Function(T type, ReportSortOption? sort, DateTimeRange? range, ReportShareFormat format) onShareViaWhatsapp;

  @override
  State<ReportOptionsSheet<T>> createState() => _ReportOptionsSheetState<T>();
}

class _ReportOptionsSheetState<T> extends State<ReportOptionsSheet<T>> {
  late T _selectedType = widget.initialType;
  bool _showSortOptions = false;
  ReportSortOption? _selectedSort;
  bool _showDateRange = false;
  DateTimeRange? _selectedRange;

  Future<void> _toggleSortOptions(bool value) async {
    if (!value) {
      setState(() {
        _showSortOptions = false;
        _selectedSort = null;
      });
      return;
    }
    final chosen = await showModalBottomSheet<ReportSortOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReportSortSheet(),
    );
    if (chosen == null || !mounted) return; // dismissed without choosing — leave unchecked
    setState(() {
      _showSortOptions = true;
      _selectedSort = chosen;
    });
  }

  Future<void> _toggleDateRange(bool value) async {
    if (!value) {
      setState(() {
        _showDateRange = false;
        _selectedRange = null;
      });
      return;
    }
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (range == null || !mounted) return; // dismissed without choosing — leave unchecked
    setState(() {
      _showDateRange = true;
      _selectedRange = range;
    });
  }

  Future<void> _openShareFormatSheet() async {
    final format = await showModalBottomSheet<ReportShareFormat>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReportShareFormatSheet(),
    );
    if (format == null || !mounted) return;
    Navigator.of(context).pop(); // close the options sheet itself before handing off
    widget.onShareViaWhatsapp(_selectedType, _selectedSort, _selectedRange, format);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: shell.surface, borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: shell.accent, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.reportsSheetTitle,
                        style: AppTextStyles.button(context).copyWith(color: shell.headerBottom, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.reply_rounded, color: shell.accent),
                    onPressed: _openShareFormatSheet,
                    tooltip: l10n.reportShareFormatTitle,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // `RadioListTile.groupValue`/`.onChanged` are deprecated on newer Flutter — the
              // group's shared state now comes from this ancestor `RadioGroup<T>` instead, with
              // each tile below only specifying its own `value`.
              RadioGroup<T>(
                groupValue: _selectedType,
                onChanged: (v) {
                  if (v != null) setState(() => _selectedType = v);
                },
                child: Column(
                  children: [
                    for (final (value, label) in widget.options)
                      RadioListTile<T>(
                        value: value,
                        title: Text(
                          label,
                          textAlign: TextAlign.end,
                          style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                        ),
                        activeColor: shell.accent,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _showSortOptions,
                onChanged: (v) => _toggleSortOptions(v ?? false),
                title: Text(
                  l10n.reportShowSortOptions,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                ),
                activeColor: shell.accent,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _showDateRange,
                onChanged: (v) => _toggleDateRange(v ?? false),
                title: Text(
                  l10n.reportSetDateRange,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body(context).copyWith(color: shell.textPrimary),
                ),
                activeColor: shell.accent,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _FormatIconButton(
                    assetName: 'assets/icons/report_pdf_icon.png',
                    fallbackIcon: Icons.picture_as_pdf_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onGeneratePdf(_selectedType, _selectedSort, _selectedRange);
                    },
                  ),
                  const SizedBox(width: 16),
                  _FormatIconButton(
                    assetName: 'assets/icons/report_excel_icon.png',
                    fallbackIcon: Icons.table_chart_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onGenerateExcel(_selectedType, _selectedSort, _selectedRange);
                    },
                  ),
                  const Spacer(),
                  _FormatIconButton(
                    assetName: 'assets/icons/report_whatsapp_icon.png',
                    fallbackIcon: Icons.chat_outlined,
                    onTap: _openShareFormatSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatIconButton extends StatelessWidget {
  const _FormatIconButton({required this.assetName, required this.fallbackIcon, required this.onTap});
  final String assetName;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          assetName,
          width: 40,
          height: 40,
          errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: 34, color: shell.accent),
        ),
      ),
    );
  }
}
