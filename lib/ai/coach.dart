import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../config.dart';

class CoachResult {
  CoachResult({
    required this.summary,
    required this.intent,
    required this.emotion,
    required this.evidence,
    required this.actions,
    required this.reply,
    required this.engine,
  });

  final String summary;
  final String intent;
  final String emotion; // puas | bingung | kecewa | marah | netral | khawatir
  final List<String> evidence;
  final List<String> actions;
  final String reply;

  /// 'gemini' bila dari model AI, 'demo' bila dari aturan sederhana.
  final String engine;

  Map<String, dynamic> toMap() => {
        'summary': summary,
        'intent': intent,
        'emotion': emotion,
        'evidence': evidence,
        'actions': actions,
        'reply': reply,
        'engine': engine,
      };

  static List<String> _list(dynamic v) =>
      v is List ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : <String>[];

  factory CoachResult.fromMap(Map<String, dynamic> m) => CoachResult(
        summary: (m['summary'] ?? '').toString(),
        intent: (m['intent'] ?? '').toString(),
        emotion: (m['emotion'] ?? 'netral').toString().toLowerCase(),
        evidence: _list(m['evidence']),
        actions: _list(m['actions']),
        reply: (m['reply'] ?? '').toString(),
        engine: (m['engine'] ?? 'gemini').toString(),
      );
}

const sampleChats = <String, String>{
  'Pesanan belum sampai': 'Pelanggan: Mas, posisinya di mana ya?\n'
      'Pelanggan: Sudah 30 menit lho, katanya 15 menit.\n'
      'Pelanggan: Halo? Kok nggak dibalas?\n'
      'Pelanggan: Makanannya keburu dingin nanti.',
  'Alamat membingungkan': 'Pelanggan: Pak, rumah saya masuk gang sebelah masjid ya\n'
      'Pelanggan: Eh bukan, gang yang ada warung kopinya\n'
      'Pelanggan: Pagar hijau, tapi bukan yang pertama',
  'Pelanggan puas': 'Pelanggan: Makasih banyak Mas, cepet banget sampainya\n'
      'Pelanggan: Masih anget juga makanannya. Sukses ya!',
  'Pesanan tidak sesuai': 'Pelanggan: Mas ini pesanan saya kok kurang satu?\n'
      'Pelanggan: Saya pesan 3 ayam geprek, yang datang cuma 2\n'
      'Pelanggan: Gimana ini, saya sudah bayar penuh!!',
};

const _prompt = '''
Anda adalah asisten untuk pengemudi ojek online / kurir di Indonesia.
Analisis percakapan pelanggan berikut dan balas HANYA dengan JSON valid berstruktur:
{
  "summary": "ringkasan masalah, 1-2 kalimat",
  "intent": "kemungkinan maksud atau kebutuhan pelanggan",
  "emotion": "salah satu: puas | bingung | khawatir | kecewa | marah | netral",
  "evidence": ["kutipan pendek persis dari percakapan yang mendukung analisis", "..."],
  "actions": ["saran tindakan konkret untuk pengemudi", "..."],
  "reply": "contoh balasan sopan, jelas, profesional, singkat, sapaan 'Kak'"
}
Aturan:
- Bahasa Indonesia yang natural dan sederhana.
- Emosi adalah perkiraan; pilih "netral" bila tidak jelas.
- Jangan mengarang fakta (misalnya posisi atau estimasi waktu pasti). Gunakan placeholder seperti [estimasi menit] bila perlu.
- Jangan menyarankan pengemudi mengetik atau membalas sambil berkendara.

Percakapan:
''';

class CoachService {
  /// Analisis dengan Gemini lewat Firebase AI Logic (kunci API dikelola Firebase,
  /// tidak tersimpan di aplikasi). Melempar error jika layanan gagal.
  static Future<CoachResult> analyzeWithAI(String chat) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: AppConfig.geminiModel,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.4,
      ),
    );
    final res = await model.generateContent([Content.text('$_prompt$chat')]);
    final text = res.text ?? '';
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Jawaban AI tidak berbentuk JSON.');
    }
    final map = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    return CoachResult.fromMap({...map, 'engine': 'gemini'});
  }

  /// Menyusun ringkasan harian dari fakta yang SUDAH dihitung aplikasi.
  /// AI hanya merangkai kalimat, tidak menambah angka baru.
  static Future<String> narrateInsights(String facts) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: AppConfig.geminiModel,
      generationConfig: GenerationConfig(temperature: 0.3),
    );
    final res = await model.generateContent([
      Content.text('Susun ringkasan harian singkat (maks 4 kalimat) untuk pengemudi ojek online '
          'dalam bahasa Indonesia sederhana, HANYA dari fakta berikut. Jangan menambah angka atau '
          'fakta baru. Utamakan keselamatan dan jangan mendorong bekerja berlebihan demi target.\n\n$facts'),
    ]);
    final t = (res.text ?? '').trim();
    if (t.isEmpty) throw const FormatException('Jawaban AI kosong.');
    return t;
  }

  /// Mode Demo: analisis berbasis kata kunci sederhana — BUKAN AI.
  static CoachResult analyzeDemo(String chat) {
    final lower = chat.toLowerCase();
    final lines = chat.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    List<String> find(List<String> keys) =>
        lines.where((l) => keys.any((k) => l.toLowerCase().contains(k))).take(3).toList();

    const kLate = ['di mana', 'dimana', 'posisi', 'lama', 'menit', 'belum sampai', 'kapan', 'halo?'];
    const kAngry = ['!!', 'gimana ini', 'kecewa', 'parah', 'lapor', 'komplain', 'kurang', 'salah'];
    const kConfused = ['gang', 'alamat', 'bukan', 'sebelah', 'patokan', 'pagar'];
    const kHappy = ['makasih', 'terima kasih', 'mantap', 'cepet', 'cepat', 'sukses'];

    final eLate = find(kLate), eAngry = find(kAngry), eConf = find(kConfused), eHappy = find(kHappy);
    final questions = '?'.allMatches(lower).length;

    if (eAngry.isNotEmpty && (lower.contains('!!') || lower.contains('kurang') || lower.contains('salah'))) {
      return CoachResult(
        summary: 'Pelanggan menyampaikan keluhan tentang pesanan.',
        intent: 'Ingin masalah pesanan segera diselesaikan atau mendapat kejelasan.',
        emotion: 'kecewa',
        evidence: eAngry,
        actions: [
          'Minta maaf tanpa menyalahkan siapa pun.',
          'Cek ulang pesanan / struk dari merchant.',
          'Arahkan ke fitur bantuan atau komplain di aplikasi platform bila perlu.',
        ],
        reply: 'Mohon maaf atas ketidaknyamanannya, Kak. Saya cek dulu struk dari merchant-nya ya. '
            'Kalau memang ada yang kurang, Kakak bisa ajukan lewat menu bantuan di aplikasi, nanti saya bantu jelaskan.',
        engine: 'demo',
      );
    }
    if (eLate.isNotEmpty || questions >= 2) {
      return CoachResult(
        summary: 'Pelanggan menanyakan posisi atau waktu tiba pesanan.',
        intent: 'Ingin kepastian kapan pesanan sampai.',
        emotion: 'khawatir',
        evidence: eLate.isNotEmpty ? eLate : lines.take(2).toList(),
        actions: [
          'Berikan estimasi waktu yang realistis (setelah berhenti di tempat aman).',
          'Jelaskan kendala singkat bila ada (macet, antre di merchant).',
        ],
        reply: 'Mohon maaf atas keterlambatannya, Kak. Saat ini saya sedang menuju lokasi. '
            'Perkiraan tiba sekitar [estimasi menit] menit lagi.',
        engine: 'demo',
      );
    }
    if (eConf.isNotEmpty) {
      return CoachResult(
        summary: 'Petunjuk alamat dari pelanggan berubah-ubah atau kurang jelas.',
        intent: 'Ingin pengemudi menemukan rumahnya dengan tepat.',
        emotion: 'bingung',
        evidence: eConf,
        actions: [
          'Minta satu patokan yang pasti atau titik lokasi (share location).',
          'Ulangi kembali alamat yang Anda pahami untuk konfirmasi.',
        ],
        reply: 'Baik, Kak. Supaya tidak salah, boleh kirim titik lokasinya atau satu patokan yang paling jelas? Terima kasih.',
        engine: 'demo',
      );
    }
    if (eHappy.isNotEmpty) {
      return CoachResult(
        summary: 'Pelanggan menyampaikan terima kasih dan puas dengan layanan.',
        intent: 'Mengapresiasi layanan.',
        emotion: 'puas',
        evidence: eHappy,
        actions: ['Balas dengan ramah dan singkat.'],
        reply: 'Sama-sama, Kak. Terima kasih sudah memesan, semoga harinya menyenangkan!',
        engine: 'demo',
      );
    }
    return CoachResult(
      summary: 'Belum terlihat masalah yang jelas dari percakapan.',
      intent: 'Belum dapat disimpulkan.',
      emotion: 'netral',
      evidence: lines.take(2).toList(),
      actions: ['Tanyakan dengan sopan apa yang bisa dibantu.'],
      reply: 'Baik, Kak. Ada yang bisa saya bantu terkait pesanannya?',
      engine: 'demo',
    );
  }
}
