import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final status = s.maintStatus;
          final history = s.sortedDesc(Cols.maintenance);
          final p = s.profile ?? {};
          return Scaffold(
            appBar: AppBar(title: const Text('Perawatan Kendaraan')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => showMaintForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Catat perawatan'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                AppCard(
                  child: Row(children: [
                    const Icon(Icons.two_wheeler, color: AppColors.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatBox(
                        label: '${p['motorBrand'] ?? ''} ${p['motorModel'] ?? ''}'.trim().isEmpty
                            ? 'Motor Anda'
                            : '${p['motorBrand'] ?? ''} ${p['motorModel'] ?? ''}'.trim(),
                        value: s.currentOdo == null ? 'Odometer belum dicatat' : '${fmtNum(s.currentOdo!, 0)} km',
                        sub: 'Odometer terakhir yang tercatat',
                      ),
                    ),
                  ]),
                ),
                const SectionTitle('Pengingat'),
                if (status.isEmpty)
                  const AppCard(
                    child: EmptyNote('Catat perawatan terakhir (misalnya ganti oli) agar pengingat bisa dihitung.',
                        icon: Icons.build_outlined),
                  )
                else
                  for (final m in status) _DueTile(m),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Pengingat dihitung dari tanggal/odometer perawatan terakhir dan interval yang Anda atur. '
                    'Aplikasi tidak mendeteksi kerusakan — periksakan ke bengkel bila ada gejala.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                SectionTitle('Riwayat (${history.length})'),
                if (history.isEmpty)
                  const AppCard(child: EmptyNote('Belum ada riwayat perawatan.'))
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final m in history)
                        ListTile(
                          onTap: () => showMaintForm(context, m),
                          title: Text('${m['category']}'),
                          subtitle: Text([
                            fmtDate(numOf(m['ts']).toInt()),
                            if (m['odometer'] != null) 'odo ${fmtNum(numOf(m['odometer']), 0)}',
                            if ((m['note'] as String?)?.isNotEmpty ?? false) m['note'],
                          ].join(' · ')),
                          trailing: Text(rupiah(numOf(m['cost'])), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                    ]),
                  ),
              ],
            ),
          );
        },
      );
}

class _DueTile extends StatelessWidget {
  const _DueTile(this.m);
  final MaintDue m;

  @override
  Widget build(BuildContext context) {
    final (c, bg, icon) = levelStyle(m.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.category, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
            Text(m.text, style: const TextStyle(fontSize: 13)),
            Text('Terakhir: ${fmtDate(numOf(m.last['ts']).toInt())}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        Text(switch (m.level) { DueLevel.due => 'Waktunya', DueLevel.soon => 'Segera', DueLevel.ok => 'Aman' },
            style: TextStyle(fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}
