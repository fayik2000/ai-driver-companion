/// Semua perhitungan angka memakai rumus yang dapat diuji — tidak ada tebakan AI.
library;

import '../util/format.dart';

typedef M = Map<String, dynamic>;

num numOf(dynamic v) => v is num ? v : 0;
int? intOrNull(dynamic v) => v is num ? v.toInt() : null;
double? dblOrNull(dynamic v) => v is num ? v.toDouble() : null;

// ───────────────────────── KEUANGAN ─────────────────────────

class PeriodSummary {
  PeriodSummary({
    required this.gross,
    required this.expense,
    required this.workMinutes,
    required this.km,
    required this.incomeCount,
    required this.expenseCount,
  });
  final num gross;
  final num expense;
  final int workMinutes;
  final num km;
  final int incomeCount;
  final int expenseCount;

  /// Penghasilan bersih = penghasilan kotor − total pengeluaran.
  num get net => gross - expense;
  bool get hasData => incomeCount > 0 || expenseCount > 0;

  /// Hanya dihitung bila waktu kerja tercatat minimal 30 menit.
  double? get netPerHour => workMinutes >= 30 ? net / (workMinutes / 60) : null;

  /// Hanya dihitung bila ada data jarak (odometer sesi kerja).
  double? get costPerKm => km > 0 ? expense / km : null;
}

/// Durasi sesi (menit). Sesi aktif dihitung sampai [nowMs].
int sessionMinutes(M s, int nowMs) {
  final start = intOrNull(s['start']);
  if (start == null) return 0;
  final end = intOrNull(s['end']) ?? nowMs;
  return ((end - start) / 60000).floor().clamp(0, 24 * 60);
}

num sessionKm(M s) {
  final a = numOf(s['odoStart']);
  final b = numOf(s['odoEnd']);
  if (s['odoStart'] == null || s['odoEnd'] == null || b <= a) return 0;
  return b - a;
}

PeriodSummary summarize({
  required Set<String> dayKeys,
  required List<M> incomes,
  required List<M> expenses,
  required List<M> sessions,
  required int nowMs,
}) {
  num gross = 0, exp = 0, km = 0;
  var ic = 0, ec = 0, minutes = 0;
  for (final i in incomes) {
    if (dayKeys.contains(dayKey(numOf(i['ts']).toInt()))) {
      gross += numOf(i['amount']);
      ic++;
    }
  }
  for (final e in expenses) {
    if (dayKeys.contains(dayKey(numOf(e['ts']).toInt()))) {
      exp += numOf(e['amount']);
      ec++;
    }
  }
  for (final s in sessions) {
    if (dayKeys.contains(dayKey(numOf(s['start']).toInt()))) {
      minutes += sessionMinutes(s, nowMs);
      km += sessionKm(s);
    }
  }
  return PeriodSummary(
    gross: gross,
    expense: exp,
    workMinutes: minutes,
    km: km,
    incomeCount: ic,
    expenseCount: ec,
  );
}

/// Kunci hari untuk N hari terakhir (termasuk hari ini), urut lama → baru.
List<String> lastNDays(int n) => [for (var i = n - 1; i >= 0; i--) dayKeyOffset(i)];

/// Kunci hari untuk bulan berjalan (WIB) sampai hari ini.
List<String> thisMonthDays() {
  final t = nowWib();
  return [for (var d = 1; d <= t.day; d++) dayKeyOffset(t.day - d)];
}

double? targetProgress(num net, num? target) {
  if (target == null || target <= 0) return null;
  return (net / target).toDouble();
}

Map<String, num> expenseByCategory(List<M> expenses, Set<String> dayKeys) {
  final out = <String, num>{};
  for (final e in expenses) {
    if (!dayKeys.contains(dayKey(numOf(e['ts']).toInt()))) continue;
    final c = (e['category'] as String?) ?? 'Lainnya';
    out[c] = (out[c] ?? 0) + numOf(e['amount']);
  }
  return out;
}

// ───────────────────────── BAHAN BAKAR ─────────────────────────

/// Liter pengisian: pakai liter yang dimasukkan, jika tidak ada → bayar ÷ harga per liter.
double litersOf(M f) {
  final l = dblOrNull(f['liters']);
  if (l != null && l > 0) return l;
  final paid = numOf(f['paid']);
  final price = numOf(f['pricePerL']);
  if (price <= 0) return 0;
  return paid / price;
}

class FuelStats {
  FuelStats({
    required this.totalSpent,
    required this.totalLiters,
    required this.fillCount,
    required this.validIntervals,
    required this.distanceKm,
    required this.intervalLiters,
    required this.intervalCost,
  });
  final num totalSpent;
  final double totalLiters;
  final int fillCount;

  /// Jumlah interval "tangki penuh → tangki penuh" yang punya odometer valid.
  final int validIntervals;
  final num distanceKm;
  final double intervalLiters;
  final num intervalCost;

  double? get kmPerL =>
      validIntervals > 0 && intervalLiters > 0 ? distanceKm / intervalLiters : null;
  double? get costPerKm => validIntervals > 0 && distanceKm > 0 ? intervalCost / distanceKm : null;

  String get explanation {
    if (fillCount == 0) return 'Belum ada catatan pengisian bahan bakar.';
    if (validIntervals == 0) {
      return 'Data belum cukup untuk menghitung konsumsi km/liter. '
          'Isi hingga tangki penuh dan catat angka odometer, minimal dua kali berturut-turut.';
    }
    return 'Dihitung dari $validIntervals interval tangki penuh → tangki penuh '
        '(${fmtNum(distanceKm, 0)} km, ${fmtNum(intervalLiters, 2)} liter).';
  }
}

/// Metode "tangki penuh ke tangki penuh": jarak antara dua pengisian penuh
/// dibagi total liter yang diisi setelah pengisian penuh pertama.
FuelStats fuelStats(List<M> fuels) {
  final list = [...fuels]..sort((a, b) => numOf(a['ts']).compareTo(numOf(b['ts'])));
  num spent = 0, dist = 0, cost = 0;
  double liters = 0, intLiters = 0, accL = 0;
  num accPaid = 0;
  num? lastOdo;
  var valid = 0;
  for (final f in list) {
    final l = litersOf(f);
    spent += numOf(f['paid']);
    liters += l;
    final full = f['full'] == true;
    final odo = dblOrNull(f['odometer']);
    if (full && odo != null) {
      accL += l;
      accPaid += numOf(f['paid']);
      if (lastOdo != null && odo > lastOdo && accL > 0) {
        dist += odo - lastOdo;
        intLiters += accL;
        cost += accPaid;
        valid++;
      }
      lastOdo = odo;
      accL = 0;
      accPaid = 0;
    } else if (full && odo == null) {
      // Rantai terputus: tanpa odometer jarak tidak bisa diketahui.
      lastOdo = null;
      accL = 0;
      accPaid = 0;
    } else {
      accL += l;
      accPaid += numOf(f['paid']);
    }
  }
  return FuelStats(
    totalSpent: spent,
    totalLiters: liters,
    fillCount: list.length,
    validIntervals: valid,
    distanceKm: dist,
    intervalLiters: intLiters,
    intervalCost: cost,
  );
}

/// Perkiraan jarak tersisa. Butuh: km/liter terukur, kapasitas tangki,
/// pengisian penuh terakhir dengan odometer, dan odometer saat ini.
double? remainingRangeKm({
  required List<M> fuels,
  required double? kmPerL,
  required double? tankCapacityL,
  required double? currentOdo,
}) {
  if (kmPerL == null || tankCapacityL == null || tankCapacityL <= 0 || currentOdo == null) {
    return null;
  }
  final list = [...fuels]..sort((a, b) => numOf(a['ts']).compareTo(numOf(b['ts'])));
  var idx = -1;
  for (var i = list.length - 1; i >= 0; i--) {
    if (list[i]['full'] == true && list[i]['odometer'] != null) {
      idx = i;
      break;
    }
  }
  if (idx < 0) return null;
  final fullOdo = numOf(list[idx]['odometer']).toDouble();
  if (currentOdo < fullOdo) return null;
  var litersLeft = tankCapacityL - (currentOdo - fullOdo) / kmPerL;
  for (var i = idx + 1; i < list.length; i++) {
    litersLeft += litersOf(list[i]);
  }
  litersLeft = litersLeft.clamp(0, tankCapacityL).toDouble();
  return litersLeft * kmPerL;
}

// ───────────────────────── PERAWATAN ─────────────────────────

class MaintType {
  const MaintType(this.name, this.days, this.km);
  final String name;
  final int days;
  final int km;
}

/// Interval bawaan sebagai titik awal saja. Pengguna wajib menyesuaikan
/// dengan buku servis / rekomendasi produsen motornya.
const maintTypes = [
  MaintType('Ganti oli', 60, 2000),
  MaintType('Pemeriksaan rem', 90, 4000),
  MaintType('Pemeriksaan ban', 30, 1500),
  MaintType('Servis berkala', 120, 4000),
  MaintType('Komponen lain', 180, 6000),
];

enum DueLevel { ok, soon, due }

class MaintDue {
  MaintDue(this.category, this.level, this.text, this.last);
  final String category;
  final DueLevel level;
  final String text;
  final M last;
}

/// Odometer tertinggi yang pernah dicatat (bensin, sesi, perawatan).
double? latestOdometer(List<M> fuels, List<M> sessions, List<M> maint) {
  double? best;
  void take(dynamic v) {
    final d = dblOrNull(v);
    if (d != null && (best == null || d > best!)) best = d;
  }

  for (final f in fuels) {
    take(f['odometer']);
  }
  for (final s in sessions) {
    take(s['odoStart']);
    take(s['odoEnd']);
  }
  for (final m in maint) {
    take(m['odometer']);
  }
  return best;
}

List<MaintDue> maintenanceStatus(List<M> maint, double? currentOdo, int nowMs) {
  final latest = <String, M>{};
  for (final m in maint) {
    final c = m['category'] as String? ?? 'Komponen lain';
    if (latest[c] == null || numOf(m['ts']) > numOf(latest[c]!['ts'])) latest[c] = m;
  }
  final out = <MaintDue>[];
  latest.forEach((cat, m) {
    final intDays = intOrNull(m['intervalDays']);
    final intKm = intOrNull(m['intervalKm']);
    var level = DueLevel.ok;
    final parts = <String>[];
    if (intDays != null && intDays > 0) {
      final passed = ((nowMs - numOf(m['ts'])) / 86400000).floor();
      final left = intDays - passed;
      if (left <= 0) {
        level = DueLevel.due;
        parts.add('sudah ${-left} hari lewat jadwal');
      } else {
        if (left <= 7 && level != DueLevel.due) level = DueLevel.soon;
        parts.add('$left hari lagi');
      }
    }
    final odo = dblOrNull(m['odometer']);
    if (intKm != null && intKm > 0 && odo != null && currentOdo != null) {
      final left = intKm - (currentOdo - odo);
      if (left <= 0) {
        level = DueLevel.due;
        parts.add('lewat ${fmtNum(-left, 0)} km');
      } else {
        if (left <= intKm * 0.1 && level == DueLevel.ok) level = DueLevel.soon;
        parts.add('${fmtNum(left, 0)} km lagi');
      }
    }
    if (parts.isEmpty) parts.add('belum ada interval pengingat');
    out.add(MaintDue(cat, level, parts.join(' · '), m));
  });
  out.sort((a, b) => b.level.index.compareTo(a.level.index));
  return out;
}

// ───────────────────────── KESELAMATAN ─────────────────────────

class SafetyAdvice {
  SafetyAdvice(this.level, this.title, this.body);
  final DueLevel level;
  final String title;
  final String body;
}

/// Saran istirahat dari durasi kerja dan kondisi yang DILAPORKAN pengemudi.
/// Aplikasi tidak mendeteksi kantuk secara otomatis.
SafetyAdvice? restAdvice({
  required bool working,
  required int minutesSinceRest,
  required int totalMinutesToday,
  required int intervalMin,
  required String? condition,
}) {
  if (condition == 'mengantuk') {
    return SafetyAdvice(
      DueLevel.due,
      'Anda melaporkan mengantuk',
      'Berhentilah di tempat yang aman dan istirahat dulu sebelum melanjutkan perjalanan. '
          'Target penghasilan bisa menunggu — keselamatan Anda lebih penting.',
    );
  }
  if (!working) return null;
  if (minutesSinceRest >= intervalMin) {
    return SafetyAdvice(
      DueLevel.due,
      'Waktunya istirahat',
      'Sudah ${fmtDuration(Duration(minutes: minutesSinceRest))} bekerja sejak istirahat terakhir '
          '(pengingat setiap ${fmtDuration(Duration(minutes: intervalMin))}). '
          'Menepi di tempat aman, minum, dan regangkan badan.',
    );
  }
  if (condition == 'lelah') {
    return SafetyAdvice(
      DueLevel.soon,
      'Anda melaporkan lelah',
      'Pertimbangkan istirahat lebih awal. Kurangi kecepatan dan hindari perjalanan jauh.',
    );
  }
  if (totalMinutesToday >= 10 * 60) {
    return SafetyAdvice(
      DueLevel.soon,
      'Jam kerja hari ini sudah panjang',
      'Lebih dari 10 jam bekerja hari ini. Pertimbangkan untuk menyudahi sesi lebih awal.',
    );
  }
  return null;
}

// ───────────────────────── INSIGHT HARIAN ─────────────────────────

class Insight {
  Insight(this.level, this.title, this.body, this.reason);
  final DueLevel level; // ok = positif/info, soon = perhatian, due = penting
  final String title;
  final String body;
  final String reason;
}

/// Rekomendasi berbasis aturan yang jelas dan data yang tercatat.
List<Insight> dailyInsights({
  required PeriodSummary today,
  required List<PeriodSummary> previousDays, // hari-hari sebelumnya (tanpa hari ini)
  required num? dailyTarget,
  required num fuelToday,
  required List<num> fuelPrevDays,
  required SafetyAdvice? safety,
  required List<MaintDue> maint,
}) {
  final out = <Insight>[];
  if (safety != null) {
    out.add(Insight(safety.level, safety.title, safety.body, 'Dari durasi kerja dan kondisi yang Anda laporkan.'));
  }
  if (!today.hasData) {
    out.add(Insight(
      DueLevel.ok,
      'Belum ada catatan hari ini',
      'Catat penghasilan dan pengeluaran agar ringkasan dan rekomendasi bisa dihitung.',
      'Rekomendasi hanya dibuat dari data yang Anda catat.',
    ));
  } else {
    final withData = previousDays.where((d) => d.hasData).toList();
    if (withData.length >= 2) {
      final avg = withData.map((d) => d.net).reduce((a, b) => a + b) / withData.length;
      final diff = today.net - avg;
      final up = diff >= 0;
      var body = 'Penghasilan bersih hari ini ${rupiah(today.net)}, '
          '${up ? 'lebih tinggi' : 'lebih rendah'} ${rupiah(diff.abs())} dari rata-rata '
          '${withData.length} hari terakhir yang tercatat (${rupiah(avg)}).';
      final prevFuel = fuelPrevDays.where((f) => f > 0).toList();
      if (prevFuel.length >= 2) {
        final avgFuel = prevFuel.reduce((a, b) => a + b) / prevFuel.length;
        if (fuelToday > avgFuel * 1.2) {
          body += ' Biaya bahan bakar juga lebih tinggi dari biasanya — '
              'periksa catatan jarak tempuh untuk mengetahui apakah perjalanan hari ini lebih jauh.';
        }
      }
      out.add(Insight(up ? DueLevel.ok : DueLevel.soon, 'Dibanding hari-hari sebelumnya', body,
          'Perbandingan dengan ${withData.length} hari terakhir yang punya catatan.'));
    } else {
      out.add(Insight(
        DueLevel.ok,
        'Perbandingan belum tersedia',
        'Butuh catatan minimal 2 hari sebelumnya untuk membandingkan penghasilan.',
        'Data historis belum cukup.',
      ));
    }
    if (today.gross > 0 && today.expense / today.gross > 0.5) {
      out.add(Insight(
        DueLevel.soon,
        'Pengeluaran lebih dari separuh penghasilan',
        'Pengeluaran hari ini ${rupiah(today.expense)} dari penghasilan kotor ${rupiah(today.gross)}. '
            'Cek kategori pengeluaran terbesar di menu Keuangan.',
        'Rasio pengeluaran ÷ penghasilan kotor hari ini.',
      ));
    }
    final p = targetProgress(today.net, dailyTarget);
    if (p != null && p >= 1) {
      out.add(Insight(
        DueLevel.ok,
        'Target harian tercapai',
        'Penghasilan bersih sudah ${(p * 100).round()}% dari target. '
            'Jika sudah lelah, ini saat yang baik untuk menyudahi hari.',
        'Penghasilan bersih dibanding target di profil.',
      ));
    }
  }
  for (final m in maint.where((m) => m.level != DueLevel.ok)) {
    out.add(Insight(
      m.level,
      m.level == DueLevel.due ? '${m.category}: sudah waktunya' : '${m.category}: segera',
      'Status: ${m.text}.',
      'Dari riwayat perawatan dan interval yang Anda atur.',
    ));
  }
  return out;
}
