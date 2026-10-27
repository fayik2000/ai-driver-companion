/// Peta Peluang — DATA SIMULASI untuk demonstrasi prototipe.
/// Tidak terhubung ke pesanan Gojek, Grab, atau platform lain.
library;

import 'dart:math';

enum DataSource { simulasi, historis, nyata }

String sourceLabel(DataSource s) => switch (s) {
      DataSource.simulasi => 'Data Simulasi',
      DataSource.historis => 'Berdasarkan Pola Historis',
      DataSource.nyata => 'Data Nyata',
    };

class City {
  const City(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

/// Titik tengah peta per kota. "Lainnya" memakai Lamongan sebagai titik awal.
const cities = [
  City('Lamongan', -7.1167, 112.4167),
  City('Gresik', -7.1564, 112.6550),
  City('Surabaya', -7.2575, 112.7521),
  City('Malang', -7.9666, 112.6326),
  City('Jakarta', -6.2000, 106.8167),
  City('Bandung', -6.9175, 107.6191),
  City('Semarang', -6.9667, 110.4167),
  City('Yogyakarta', -7.7956, 110.3695),
  City('Medan', 3.5952, 98.6722),
  City('Makassar', -5.1477, 119.4327),
  City('Denpasar', -8.6500, 115.2167),
];

City cityByName(String? name) =>
    cities.firstWhere((c) => c.name == name, orElse: () => cities.first);

class Zone {
  Zone({
    required this.name,
    required this.lat,
    required this.lng,
    required this.score,
    required this.source,
  });
  final String name;
  final double lat;
  final double lng;

  /// 0–100, potensi peluang relatif antarzona (bukan jumlah pesanan).
  final int score;
  final DataSource source;

  String get levelLabel => score >= 70 ? 'Tinggi' : (score >= 45 ? 'Sedang' : 'Rendah');
}

const services = ['Penumpang', 'Makanan', 'Barang'];
const horizons = ['Saat ini', '30 menit', '60 menit', 'Pola historis'];

// Pola simulasi kasar per layanan menurut jam (0–23). Hanya ilustrasi.
double _hourWeight(String service, double hour) {
  double bump(double center, double width) => exp(-pow(hour - center, 2) / (2 * width * width));
  switch (service) {
    case 'Makanan':
      return 0.25 + 0.75 * max(bump(12, 1.5), bump(19, 1.8));
    case 'Barang':
      return 0.3 + 0.7 * bump(14, 3.5);
    default:
      return 0.25 + 0.75 * max(bump(7, 1.3), bump(17, 1.6));
  }
}

/// Membuat zona simulasi deterministik di sekitar titik tengah kota.
List<Zone> simulateZones({
  required City city,
  required String service,
  required double hourWib, // jam WIB + offset horizon
}) {
  const offsets = [
    [0.0, 0.0], [0.018, 0.012], [-0.016, 0.02], [0.02, -0.018],
    [-0.022, -0.014], [0.004, 0.03], [-0.006, -0.03], [0.03, 0.004],
  ];
  final w = _hourWeight(service, hourWib % 24);
  final zones = <Zone>[];
  for (var i = 0; i < offsets.length; i++) {
    final seed = city.name.hashCode ^ service.hashCode ^ (i * 7919);
    final rnd = Random(seed);
    final base = 0.35 + rnd.nextDouble() * 0.65; // karakter zona
    final phase = rnd.nextDouble() * 2 * pi;
    final wiggle = 0.12 * sin(hourWib / 24 * 2 * pi + phase);
    final s = ((base * w + wiggle) * 100).clamp(5, 98).round();
    zones.add(Zone(
      name: 'Zona ${String.fromCharCode(65 + i)}',
      lat: city.lat + offsets[i][0],
      lng: city.lng + offsets[i][1],
      score: s,
      source: DataSource.simulasi,
    ));
  }
  return zones;
}

/// Jarak garis lurus (km) — perkiraan kasar, jarak jalan sebenarnya lebih jauh.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(a));
}

class ZoneEval {
  ZoneEval(this.zone, this.km, this.minutes, this.fuelCost, this.netScore);
  final Zone zone;
  final double km; // perkiraan jarak jalan (garis lurus × 1,3)
  final int minutes; // asumsi 25 km/jam di kota
  final double? fuelCost; // null bila km/liter belum diketahui
  final double netScore;
}

/// Menilai zona dengan mempertimbangkan potensi, jarak, waktu, dan biaya BBM.
List<ZoneEval> evaluateZones({
  required List<Zone> zones,
  required double? fromLat,
  required double? fromLng,
  required double? kmPerL,
  required double? pricePerL,
}) {
  final out = <ZoneEval>[];
  for (final z in zones) {
    double km = 0;
    if (fromLat != null && fromLng != null) {
      km = haversineKm(fromLat, fromLng, z.lat, z.lng) * 1.3;
    }
    final minutes = (km / 25 * 60).round();
    final cost = (kmPerL != null && kmPerL > 0 && pricePerL != null) ? km / kmPerL * pricePerL : null;
    final net = z.score - minutes * 1.5;
    out.add(ZoneEval(z, km, minutes, cost, net));
  }
  out.sort((a, b) => b.netScore.compareTo(a.netScore));
  return out;
}
