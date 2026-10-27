import 'package:flutter/material.dart';

import '../config.dart';
import '../logic/calc.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.valueColor, this.sub});
  final String label;
  final String value;
  final Color? valueColor;
  final String? sub;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.ink)),
          ),
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.primary, this.bg = AppColors.goodBg, this.icon});
  final String text;
  final Color color;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

(Color, Color, IconData) levelStyle(DueLevel l) => switch (l) {
      DueLevel.due => (AppColors.danger, AppColors.dangerBg, Icons.error_outline),
      DueLevel.soon => (AppColors.warn, AppColors.warnBg, Icons.info_outline),
      DueLevel.ok => (AppColors.primary, AppColors.goodBg, Icons.check_circle_outline),
    };

class InsightTile extends StatelessWidget {
  const InsightTile(this.insight, {super.key});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final (c, bg, icon) = levelStyle(insight.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(insight.title, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
            const SizedBox(height: 4),
            Text(insight.body, style: const TextStyle(color: AppColors.ink, height: 1.35)),
            const SizedBox(height: 6),
            Text('Alasan: ${insight.reason}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: AppColors.muted, size: 32),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}

/// Penanda jelas bahwa Firebase/AI belum terhubung.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!RuntimeStatus.demoMode) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.warnBg, borderRadius: BorderRadius.circular(12)),
      child: const Text(
        'Mode Demo: Firebase belum terhubung. Data hanya tersimpan di HP ini dan AI Coach memakai analisis aturan sederhana (bukan AI).',
        style: TextStyle(fontSize: 12.5, color: AppColors.warn, height: 1.35),
      ),
    );
  }
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'Hapus'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}
