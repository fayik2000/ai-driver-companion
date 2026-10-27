import 'package:flutter/material.dart';

import '../ai/coach.dart';
import '../config.dart';
import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';
import 'fuel.dart';
import 'safety.dart';
import 'shell.dart';
import 'vehicle.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 68,
              title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Halo, ${s.nickname}'),
                Text(fmtDate(nowMs()),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w400)),
              ]),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Pill(s.workStatus,
                      icon: s.activeSession != null ? Icons.circle : Icons.circle_outlined,
                      color: s.activeSession != null ? AppColors.primary : AppColors.muted,
                      bg: s.activeSession != null ? AppColors.goodBg : const Color(0xFFEDEFEC)),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (s.lastError != null) _ErrorNote(s.lastError!),
                const DemoBanner(),
                const _TodayCard(),
                const SizedBox(height: 12),
                const _WorkCard(),
                const SectionTitle('Aksi cepat'),
                const _QuickActions(),
                const SectionTitle('Rekomendasi hari ini'),
                for (final i in s.insights) InsightTile(i),
                const _AiSummary(),
              ],
            ),
          );
        },
      );
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
        child: Text(msg, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final t = s.today;
    final p = targetProgress(t.net, s.dailyTarget);
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Penghasilan bersih hari ini', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(rupiah(t.net),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          const Text('= penghasilan kotor − total pengeluaran',
              style: TextStyle(color: Colors.white60, fontSize: 11.5)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _whiteStat('Kotor', rupiah(t.gross))),
            Expanded(child: _whiteStat('Pengeluaran', rupiah(t.expense))),
            Expanded(child: _whiteStat('Waktu kerja', fmtDuration(Duration(minutes: t.workMinutes)))),
          ]),
          const SizedBox(height: 14),
          if (p != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text('${(p * 100).clamp(0, 999).round()}% dari target ${rupiah(s.dailyTarget!)}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ] else
            const Text('Atur target harian di Profil untuk melihat progres.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        ]),
      ),
    );
  }

  Widget _whiteStat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ]);
}

class _WorkCard extends StatelessWidget {
  const _WorkCard();

  Future<void> _toggle(BuildContext context) async {
    final s = AppState.I;
    final active = s.activeSession != null;
    final r = await askOdometer(context, active ? 'Akhiri sesi kerja' : 'Mulai sesi kerja');
    if (r == null) return;
    if (active) {
      s.endSession(odo: r.odo);
      if (context.mounted) snack(context, 'Sesi kerja diakhiri. Hati-hati di jalan pulang.');
    } else {
      s.startSession(odo: r.odo);
      if (context.mounted) snack(context, 'Sesi dimulai. Jangan gunakan HP saat berkendara.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final active = s.activeSession != null;
    final advice = s.safety;
    final cond = s.recentCondition;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(active ? 'Sesi kerja berjalan' : 'Sesi kerja',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          IconButton(
            tooltip: 'Pengaturan keselamatan',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyScreen())),
            icon: const Icon(Icons.tune),
          ),
        ]),
        if (active) ...[
          const SizedBox(height: 4),
          Text(
            'Mulai ${fmtTime(numOf(s.activeSession!['start']).toInt())} · '
            '${fmtDuration(Duration(minutes: s.minutesSinceRest))} sejak istirahat terakhir · '
            'pengingat tiap ${fmtDuration(Duration(minutes: s.restIntervalMin))}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Kondisi Anda sekarang:', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final c in const ['segar', 'lelah', 'mengantuk'])
            ChoiceChip(
              label: Text(c[0].toUpperCase() + c.substring(1)),
              selected: cond == c,
              onSelected: (_) => s.reportCondition(c),
            ),
        ]),
        if (advice != null) ...[
          const SizedBox(height: 12),
          InsightTile(Insight(advice.level, advice.title, advice.body, 'Kondisi yang Anda laporkan dan durasi kerja.')),
        ],
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _toggle(context),
              icon: Icon(active ? Icons.stop_circle_outlined : Icons.play_arrow),
              label: Text(active ? 'Akhiri sesi' : 'Mulai kerja'),
              style: active ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            ),
          ),
          if (active) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  s.markRest();
                  snack(context, 'Istirahat dicatat. Pengingat dihitung ulang dari sekarang.');
                },
                icon: const Icon(Icons.local_cafe_outlined),
                label: const Text('Saya istirahat'),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Icon(Icons.phonelink_off, size: 16, color: AppColors.muted),
          SizedBox(width: 6),
          Expanded(
            child: Text('Jangan gunakan HP saat berkendara. Menepilah dulu sebelum membalas pesan.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ]),
      ]),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.add_card, 'Catat penghasilan', () => showIncomeForm(context)),
      (Icons.receipt_long, 'Catat pengeluaran', () => showExpenseForm(context)),
      (Icons.local_gas_station, 'Isi bahan bakar', () => showFuelForm(context)),
      (Icons.map, 'Peta Peluang', () => tabIndex.value = 1),
      (Icons.chat, 'Analisis chat', () => tabIndex.value = 3),
      (Icons.query_stats, 'Smart Fuel', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FuelScreen()))),
      (Icons.build_outlined, 'Perawatan', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleScreen()))),
      (Icons.health_and_safety_outlined, 'Keselamatan', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyScreen()))),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        for (final (icon, label, onTap) in items)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            onTap: onTap,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppColors.goodBg, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.15)),
            ]),
          ),
      ],
    );
  }
}

/// AI hanya menyusun kalimat dari fakta yang sudah dihitung aplikasi.
class _AiSummary extends StatefulWidget {
  const _AiSummary();
  @override
  State<_AiSummary> createState() => _AiSummaryState();
}

class _AiSummaryState extends State<_AiSummary> {
  bool busy = false;

  Rec? get _todaySaved {
    final list = AppState.I.insightsSaved.where((e) => e['day'] == todayKey()).toList()
      ..sort((a, b) => numOf(b['ts']).compareTo(numOf(a['ts'])));
    return list.isEmpty ? null : list.first;
  }

  Future<void> _run() async {
    final s = AppState.I;
    final facts = s.insights.map((i) => '- ${i.title}: ${i.body}').join('\n');
    setState(() => busy = true);
    try {
      final text = await CoachService.narrateInsights(facts);
      s.save(Cols.insights, {'ts': nowMs(), 'day': todayKey(), 'text': text, 'facts': facts});
    } catch (e) {
      if (mounted) snack(context, 'AI belum bisa dihubungi: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!RuntimeStatus.firebaseReady) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('Ringkasan kalimat oleh AI aktif setelah Firebase terhubung. Rekomendasi di atas dihitung dari aturan dan data Anda.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
      );
    }
    final saved = _todaySaved;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (saved != null)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Pill('Ringkasan AI', icon: Icons.auto_awesome),
            const SizedBox(height: 8),
            Text('${saved['text']}', style: const TextStyle(height: 1.4)),
            const SizedBox(height: 6),
            Text('Disusun ${fmtTime(numOf(saved['ts']).toInt())} dari data tercatat.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: busy ? null : _run,
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome),
        label: Text(saved == null ? 'Susun ringkasan harian dengan AI' : 'Perbarui ringkasan AI'),
      ),
    ]);
  }
}
