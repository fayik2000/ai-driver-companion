import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  int period = 0; // 0 hari ini, 1 7 hari, 2 bulan ini

  List<String> get _days => switch (period) {
        0 => [todayKey()],
        1 => lastNDays(7),
        _ => thisMonthDays(),
      };

  void _addMenu() => showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.add_card, color: AppColors.primary),
              title: const Text('Catat penghasilan'),
              onTap: () {
                Navigator.pop(c);
                showIncomeForm(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: AppColors.primary),
              title: const Text('Catat pengeluaran'),
              onTap: () {
                Navigator.pop(c);
                showExpenseForm(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_gas_station, color: AppColors.primary),
              title: const Text('Catat isi bahan bakar'),
              onTap: () {
                Navigator.pop(c);
                showFuelForm(context);
              },
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final days = _days;
          final sum = s.summaryFor(days);
          final daySet = days.toSet();
          final tx = <(bool, Rec)>[
            for (final i in s.incomes)
              if (daySet.contains(dayKey(numOf(i['ts']).toInt()))) (true, i),
            for (final e in s.expenses)
              if (daySet.contains(dayKey(numOf(e['ts']).toInt()))) (false, e),
          ]..sort((a, b) => numOf(b.$2['ts']).compareTo(numOf(a.$2['ts'])));
          final cats = expenseByCategory(s.expenses, daySet).entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final workedDays = days.where((d) => s.summaryFor([d]).hasData).length;

          return Scaffold(
            appBar: AppBar(title: const Text('Keuangan')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _addMenu,
              icon: const Icon(Icons.add),
              label: const Text('Catat'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Hari ini')),
                    ButtonSegment(value: 1, label: Text('7 hari')),
                    ButtonSegment(value: 2, label: Text('Bulan ini')),
                  ],
                  selected: {period},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => period = v.first),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    StatBox(
                      label: 'Penghasilan bersih',
                      value: rupiah(sum.net),
                      valueColor: sum.net < 0 ? AppColors.danger : AppColors.primary,
                    ),
                    const Divider(height: 24),
                    Row(children: [
                      Expanded(child: StatBox(label: 'Kotor', value: rupiah(sum.gross))),
                      Expanded(child: StatBox(label: 'Pengeluaran', value: rupiah(sum.expense))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: StatBox(
                          label: 'Bersih per jam',
                          value: sum.netPerHour == null ? '—' : rupiah(sum.netPerHour!),
                          sub: sum.netPerHour == null ? 'Butuh catatan sesi kerja' : fmtDuration(Duration(minutes: sum.workMinutes)),
                        ),
                      ),
                      Expanded(
                        child: StatBox(
                          label: 'Biaya operasional/km',
                          value: sum.costPerKm == null ? '—' : rupiah(sum.costPerKm!),
                          sub: sum.costPerKm == null ? 'Butuh odometer sesi kerja' : '${fmtNum(sum.km, 0)} km tercatat',
                        ),
                      ),
                    ]),
                    if (s.dailyTarget != null && s.dailyTarget! > 0) ...[
                      const Divider(height: 24),
                      _TargetRow(sum: sum, target: s.dailyTarget!, period: period, workedDays: workedDays),
                    ],
                  ]),
                ),
                const SectionTitle('Penghasilan bersih 7 hari terakhir'),
                AppCard(child: _NetBars(days: lastNDays(7))),
                if (cats.isNotEmpty) ...[
                  const SectionTitle('Pengeluaran per kategori'),
                  AppCard(
                    child: Column(children: [
                      for (final c in cats)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(c.key)),
                              Text(rupiah(c.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: sum.expense > 0 ? (c.value / sum.expense).toDouble() : 0,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: AppColors.line,
                              color: AppColors.accent,
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ],
                SectionTitle('Catatan (${tx.length})'),
                if (tx.isEmpty)
                  const AppCard(child: EmptyNote('Belum ada catatan pada periode ini. Ketuk "Catat" untuk menambah.'))
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (isIncome, r) in tx)
                        ListTile(
                          onTap: () => isIncome ? showIncomeForm(context, r) : showExpenseForm(context, r),
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? AppColors.goodBg : AppColors.dangerBg,
                            child: Icon(isIncome ? Icons.south_west : Icons.north_east,
                                color: isIncome ? AppColors.primary : AppColors.danger, size: 18),
                          ),
                          title: Text(isIncome ? 'Penghasilan · ${r['service'] ?? ''}' : '${r['category'] ?? 'Pengeluaran'}'),
                          subtitle: Text([
                            fmtDateTime(numOf(r['ts']).toInt()),
                            if ((r['note'] as String?)?.isNotEmpty ?? false) r['note'],
                          ].join(' · ')),
                          trailing: Text(
                            '${isIncome ? '+' : '−'}${rupiah(numOf(r['amount']))}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: isIncome ? AppColors.primary : AppColors.danger),
                          ),
                        ),
                    ]),
                  ),
              ],
            ),
          );
        },
      );
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.sum, required this.target, required this.period, required this.workedDays});
  final PeriodSummary sum;
  final num target;
  final int period;
  final int workedDays;

  @override
  Widget build(BuildContext context) {
    final String label;
    final double? p;
    if (period == 0) {
      p = targetProgress(sum.net, target);
      label = 'Progres target harian (${rupiah(target)})';
    } else if (workedDays > 0) {
      p = targetProgress(sum.net / workedDays, target);
      label = 'Rata-rata bersih ${rupiah(sum.net / workedDays)}/hari dari $workedDays hari tercatat vs target';
    } else {
      p = null;
      label = 'Belum ada hari dengan catatan.';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      if (p != null) ...[
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: p.clamp(0, 1).toDouble(),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: AppColors.line,
          color: AppColors.primary,
        ),
        const SizedBox(height: 4),
        Text('${(p * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

/// Grafik batang sederhana penghasilan bersih per hari.
class _NetBars extends StatelessWidget {
  const _NetBars({required this.days});
  final List<String> days;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final values = [for (final d in days) s.summaryFor([d])];
    final maxAbs = values.map((v) => v.net.abs()).fold<num>(0, (a, b) => b > a ? b : a);
    if (values.every((v) => !v.hasData)) {
      return const EmptyNote('Belum ada data 7 hari terakhir.', icon: Icons.bar_chart);
    }
    return SizedBox(
      height: 170,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    values[i].hasData ? '${(values[i].net / 1000).round()}rb' : '–',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: maxAbs == 0 ? 2 : (110 * values[i].net.abs() / maxAbs).toDouble().clamp(2.0, 110.0),
                  decoration: BoxDecoration(
                    color: values[i].net < 0
                        ? AppColors.danger
                        : (i == days.length - 1 ? AppColors.primary : AppColors.accent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(fmtDayKey(days[i]), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}
