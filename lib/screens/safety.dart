import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  static const _intervals = [60, 90, 120, 150, 180, 240];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final advice = s.safety;
          final recent = s.sortedDesc(Cols.sessions, 'start').take(7).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('Keselamatan')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (advice != null)
                  InsightTile(Insight(advice.level, advice.title, advice.body, 'Durasi kerja dan kondisi yang Anda laporkan.')),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Pengingat istirahat setiap', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final m in _intervals)
                        ChoiceChip(
                          label: Text(fmtDuration(Duration(minutes: m))),
                          selected: s.restIntervalMin == m,
                          onSelected: (_) => s.updateSettings({'restIntervalMin': m}),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'Pengingat muncul di dalam aplikasi selama sesi kerja aktif dan aplikasi sedang dibuka. '
                      'Notifikasi saat aplikasi tertutup belum tersedia di versi ini.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Bagaimana kondisi Anda?', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final c in const ['segar', 'lelah', 'mengantuk'])
                        ChoiceChip(
                          label: Text(c[0].toUpperCase() + c.substring(1)),
                          selected: s.recentCondition == c,
                          onSelected: (_) => s.reportCondition(c),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'Aplikasi tidak mendeteksi kantuk secara otomatis. Saran didasarkan pada kondisi yang Anda pilih '
                      'dan lamanya bekerja.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
                    ),
                  ]),
                ),
                const SectionTitle('Kebiasaan aman'),
                const AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _Tip(Icons.phonelink_off, 'Jangan gunakan HP saat berkendara. Menepi dulu untuk membalas pesan atau membuka aplikasi.'),
                    _Tip(Icons.local_cafe_outlined, 'Jika mengantuk, berhenti di tempat aman dan istirahat. Target bisa menunggu.'),
                    _Tip(Icons.water_drop_outlined, 'Minum air secara teratur, terutama saat siang hari.'),
                    _Tip(Icons.sports_motorsports_outlined, 'Pastikan helm terpasang dengan benar dan rem berfungsi baik.'),
                  ]),
                ),
                SectionTitle('Sesi kerja terakhir (${recent.length})'),
                if (recent.isEmpty)
                  const AppCard(child: EmptyNote('Belum ada sesi kerja. Mulai dari Beranda.'))
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final ss in recent)
                        ListTile(
                          dense: true,
                          title: Text(fmtDate(numOf(ss['start']).toInt())),
                          subtitle: Text(
                            '${fmtTime(numOf(ss['start']).toInt())} – '
                            '${ss['end'] == null ? 'berjalan' : fmtTime(numOf(ss['end']).toInt())}'
                            '${sessionKm(ss) > 0 ? ' · ${fmtNum(sessionKm(ss), 0)} km' : ''}'
                            ' · istirahat ${numOf(ss['rests']).toInt()}×',
                          ),
                          trailing: Text(fmtDuration(Duration(minutes: sessionMinutes(ss, nowMs()))),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          onLongPress: ss['end'] == null
                              ? null
                              : () async {
                                  if (await confirm(context, 'Hapus sesi?', 'Sesi kerja ini akan dihapus.')) {
                                    s.delete(Cols.sessions, ss['id'] as String);
                                  }
                                },
                        ),
                    ]),
                  ),
                if (recent.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Tekan lama sesi yang sudah selesai untuk menghapus.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  ),
              ],
            ),
          );
        },
      );
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ]),
      );
}
