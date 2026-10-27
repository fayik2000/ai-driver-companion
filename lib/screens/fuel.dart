import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

class FuelScreen extends StatelessWidget {
  const FuelScreen({super.key});

  Future<void> _setOdo(BuildContext context) async {
    final r = await askOdometer(context, 'Odometer saat ini');
    if (r?.odo != null) AppState.I.updateSettings({'currentOdo': r!.odo});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final st = s.fuel;
          final range = remainingRangeKm(
            fuels: s.fuels,
            kmPerL: st.kmPerL,
            tankCapacityL: s.tankCapacity,
            currentOdo: s.currentOdo,
          );
          final monthDays = thisMonthDays().toSet();
          final monthFuel = expenseByCategory(s.expenses, monthDays)['Bahan bakar'] ?? 0;
          final history = s.sortedDesc(Cols.fuels);

          String rangeNote() {
            if (st.kmPerL == null) return 'Butuh konsumsi km/liter terukur.';
            if (s.tankCapacity == null) return 'Isi kapasitas tangki di Profil.';
            if (s.currentOdo == null) return 'Isi odometer saat ini.';
            return 'Data belum cukup (butuh isi penuh terakhir dengan odometer).';
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Smart Fuel')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => showFuelForm(context),
              icon: const Icon(Icons.local_gas_station),
              label: const Text('Isi BBM'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: StatBox(
                          label: 'Konsumsi terukur',
                          value: st.kmPerL == null ? '—' : '${fmtNum(st.kmPerL!)} km/L',
                          valueColor: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        child: StatBox(
                          label: 'Biaya BBM per km',
                          value: st.costPerKm == null ? '—' : rupiah(st.costPerKm!),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(st.explanation, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
                    const Divider(height: 24),
                    Row(children: [
                      Expanded(child: StatBox(label: 'BBM bulan ini', value: rupiah(monthFuel))),
                      Expanded(
                        child: StatBox(
                          label: 'Total semua catatan',
                          value: rupiah(st.totalSpent),
                          sub: '${st.fillCount} pengisian · ${fmtNum(st.totalLiters, 1)} L',
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  onTap: () => _setOdo(context),
                  child: Row(children: [
                    const Icon(Icons.route, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatBox(
                        label: 'Perkiraan jarak tersisa',
                        value: range == null ? '—' : '± ${fmtNum(range, 0)} km',
                        sub: range == null
                            ? rangeNote()
                            : 'Odometer ${fmtNum(s.currentOdo!, 0)} km · ketuk untuk ubah. Hanya perkiraan.',
                      ),
                    ),
                    const Icon(Icons.edit, size: 18, color: AppColors.muted),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.goodBg, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'Cara mendapat angka km/liter yang akurat: isi sampai tangki penuh dan catat odometer. '
                    'Lakukan lagi saat pengisian penuh berikutnya. Pengisian di antaranya (tidak penuh) tetap dihitung.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.primary, height: 1.35),
                  ),
                ),
                SectionTitle('Riwayat pengisian (${history.length})'),
                if (history.isEmpty)
                  const AppCard(child: EmptyNote('Belum ada catatan. Contoh: beli Pertalite Rp10.000 → ketuk "Isi BBM".'))
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final f in history)
                        ListTile(
                          onTap: () => showFuelForm(context, f),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.goodBg,
                            child: Icon(f['full'] == true ? Icons.battery_full : Icons.battery_5_bar,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Text('${f['fuelType']} · ${fmtNum(litersOf(f), 2)} L'),
                          subtitle: Text([
                            fmtDateTime(numOf(f['ts']).toInt()),
                            if (f['odometer'] != null) 'odo ${fmtNum(numOf(f['odometer']), 0)}',
                            if (f['full'] == true) 'penuh',
                          ].join(' · ')),
                          trailing: Text(rupiah(numOf(f['paid'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ),
              ],
            ),
          );
        },
      );
}
