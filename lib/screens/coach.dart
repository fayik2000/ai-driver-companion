import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai/coach.dart';
import '../config.dart';
import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

const _emotionLabel = {
  'puas': ('Puas', Icons.sentiment_very_satisfied, AppColors.primary),
  'netral': ('Netral', Icons.sentiment_neutral, AppColors.muted),
  'bingung': ('Bingung', Icons.help_outline, AppColors.warn),
  'khawatir': ('Khawatir', Icons.sentiment_dissatisfied, AppColors.warn),
  'kecewa': ('Kecewa', Icons.sentiment_dissatisfied, AppColors.danger),
  'marah': ('Marah', Icons.sentiment_very_dissatisfied, AppColors.danger),
};

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final input = TextEditingController();
  final reply = TextEditingController();
  CoachResult? result;
  bool busy = false;
  bool editing = false;
  String? notice;

  Future<void> _analyze() async {
    final text = input.text.trim();
    if (text.isEmpty) return snack(context, 'Tempel teks percakapan atau pilih contoh dulu.');
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      notice = null;
    });
    CoachResult r;
    if (RuntimeStatus.firebaseReady) {
      try {
        r = await CoachService.analyzeWithAI(text);
      } catch (e) {
        r = CoachService.analyzeDemo(text);
        notice = 'AI tidak dapat dihubungi ($e). Ditampilkan analisis aturan sederhana (bukan AI).';
      }
    } else {
      r = CoachService.analyzeDemo(text);
    }
    if (!mounted) return;
    setState(() {
      result = r;
      reply.text = r.reply;
      editing = false;
      busy = false;
    });
    AppState.I.save(Cols.coach, {'ts': nowMs(), 'input': text, 'result': r.toMap()});
  }

  void _load(Rec rec) {
    final m = rec['result'];
    if (m is! Map) return;
    final r = CoachResult.fromMap(Map<String, dynamic>.from(m));
    setState(() {
      input.text = (rec['input'] as String?) ?? '';
      result = r;
      reply.text = r.reply;
      editing = false;
      notice = null;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final history = AppState.I.sortedDesc(Cols.coach).take(10).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('AI Coach')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  RuntimeStatus.firebaseReady
                      ? 'Tempel percakapan pelanggan, lalu AI (Gemini via Firebase) membantu memahami dan menyusun balasan.'
                      : 'Mode Demo: analisis memakai aturan kata kunci sederhana, bukan AI. Hubungkan Firebase untuk AI.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: input,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Tempel teks percakapan di sini…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Atau pilih contoh:', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final e in sampleChats.entries)
                    ActionChip(label: Text(e.key), onPressed: () => setState(() => input.text = e.value)),
                ]),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : _analyze,
                  icon: busy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.psychology_alt_outlined),
                  label: const Text('Analisis Percakapan'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aplikasi tidak membaca WhatsApp atau chat Anda secara otomatis dan tidak mengirim pesan. '
                  'Anda yang memutuskan balasan yang dikirim.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                if (notice != null) ...[
                  const SizedBox(height: 12),
                  Text(notice!, style: const TextStyle(color: AppColors.warn, fontSize: 12.5)),
                ],
                if (result != null) ...[
                  const SizedBox(height: 16),
                  _ResultView(
                    r: result!,
                    reply: reply,
                    editing: editing,
                    onEdit: () => setState(() => editing = !editing),
                    onRetry: busy ? null : _analyze,
                  ),
                ],
                if (history.isNotEmpty) ...[
                  const SectionTitle('Riwayat analisis'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final h in history)
                        ListTile(
                          dense: true,
                          onTap: () => _load(h),
                          title: Text(
                            ((h['result'] as Map?)?['summary'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(fmtDateTime(numOf(h['ts']).toInt())),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => AppState.I.delete(Cols.coach, h['id'] as String),
                          ),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.r, required this.reply, required this.editing, required this.onEdit, required this.onRetry});
  final CoachResult r;
  final TextEditingController reply;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback? onRetry;

  Widget _block(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 4),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _emotionLabel[r.emotion] ?? ('Netral', Icons.sentiment_neutral, AppColors.muted);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(r.engine == 'gemini' ? 'Analisis AI' : 'Analisis aturan (demo)',
              icon: r.engine == 'gemini' ? Icons.auto_awesome : Icons.rule,
              color: r.engine == 'gemini' ? AppColors.primary : AppColors.warn,
              bg: r.engine == 'gemini' ? AppColors.goodBg : AppColors.warnBg),
        ]),
        const SizedBox(height: 12),
        _block('Ringkasan masalah', Text(r.summary)),
        _block('Kemungkinan maksud pelanggan', Text(r.intent)),
        _block(
          'Perkiraan perasaan pelanggan',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ]),
            const SizedBox(height: 2),
            const Text('Ini perkiraan dari teks, bukan kepastian.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        ),
        if (r.evidence.isNotEmpty)
          _block(
            'Bagian percakapan yang mendukung',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final q in r.evidence)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.only(left: 10),
                  decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.accent, width: 3))),
                  child: Text('“$q”', style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
            ]),
          ),
        _block(
          'Saran tindakan',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final a in r.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(a)),
                ]),
              ),
          ]),
        ),
        _block(
          'Contoh balasan',
          editing
              ? TextField(controller: reply, minLines: 3, maxLines: 8)
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.goodBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(reply.text, style: const TextStyle(height: 1.4)),
                ),
        ),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reply.text));
                if (context.mounted) snack(context, 'Balasan disalin. Tempel di aplikasi chat saat sudah berhenti.');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Salin'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: Icon(editing ? Icons.check : Icons.edit, size: 18),
              label: Text(editing ? 'Selesai' : 'Edit'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Ulang'),
            ),
          ),
        ]),
      ]),
    );
  }
}
