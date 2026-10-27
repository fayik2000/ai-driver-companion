/// Utilitas format Rupiah dan waktu Asia/Jakarta (WIB, UTC+7, tanpa DST).
library;

const _wibOffset = Duration(hours: 7);

/// Waktu "jam dinding" Jakarta untuk sebuah epoch milidetik.
DateTime wib(int epochMs) =>
    DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).add(_wibOffset);

DateTime nowWib() => DateTime.now().toUtc().add(_wibOffset);

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Mengubah tanggal+jam WIB (komponen) menjadi epoch milidetik.
int wibToMs(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(_wibOffset).millisecondsSinceEpoch;

String _two(int n) => n.toString().padLeft(2, '0');

/// Kunci hari "yyyy-MM-dd" menurut WIB.
String dayKey(int epochMs) {
  final t = wib(epochMs);
  return '${t.year}-${_two(t.month)}-${_two(t.day)}';
}

String todayKey() => dayKey(nowMs());

/// Kunci hari untuk N hari sebelum hari ini (WIB).
String dayKeyOffset(int daysAgo) {
  final t = nowWib().subtract(Duration(days: daysAgo));
  return '${t.year}-${_two(t.month)}-${_two(t.day)}';
}

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];
const _hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

String fmtDate(int epochMs) {
  final t = wib(epochMs);
  return '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]} ${t.year}';
}

String fmtTime(int epochMs) {
  final t = wib(epochMs);
  return '${_two(t.hour)}:${_two(t.minute)} WIB';
}

String fmtDateTime(int epochMs) => '${fmtDate(epochMs)} · ${fmtTime(epochMs)}';

String fmtDayKey(String key) {
  final p = key.split('-');
  if (p.length != 3) return key;
  return '${int.parse(p[2])} ${_bulan[int.parse(p[1]) - 1]}';
}

/// Format Rupiah: Rp12.500 (titik pemisah ribuan).
String rupiah(num value) {
  final neg = value < 0;
  final s = value.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '−' : ''}Rp$buf';
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m mnt';
  return '$h j $m mnt';
}

String fmtNum(num v, [int digits = 1]) {
  final s = v.toStringAsFixed(digits);
  return s.replaceAll('.', ',');
}

/// Parsing angka dari input pengguna ("10.000", "10000", "2,5").
num? parseNum(String input) {
  var s = input.trim().replaceAll('Rp', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return num.tryParse(s);
}
