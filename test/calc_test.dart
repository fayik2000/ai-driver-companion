import 'package:ai_driver_companion/logic/calc.dart';
import 'package:ai_driver_companion/logic/demand.dart';
import 'package:ai_driver_companion/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format', () {
    test('Rupiah', () {
      expect(rupiah(0), 'Rp0');
      expect(rupiah(10000), 'Rp10.000');
      expect(rupiah(1250000), 'Rp1.250.000');
      expect(rupiah(-5500), '−Rp5.500');
    });
    test('parseNum', () {
      expect(parseNum('10.000'), 10000);
      expect(parseNum('Rp 12.500'), 12500);
      expect(parseNum('2,5'), 2.5);
      expect(parseNum('10000'), 10000);
      expect(parseNum(''), null);
    });
    test('Hari WIB', () {
      // 2026-10-27 17:30 UTC = 2026-10-28 00:30 WIB
      final ms = DateTime.utc(2026, 10, 27, 17, 30).millisecondsSinceEpoch;
      expect(dayKey(ms), '2026-10-28');
      expect(wibToMs(2026, 10, 28, 0, 30), ms);
    });
  });

  group('Keuangan', () {
    test('Penghasilan bersih = kotor − pengeluaran', () {
      final ms = wibToMs(2026, 10, 27, 9);
      final s = summarize(
        dayKeys: {'2026-10-27'},
        incomes: [
          {'ts': ms, 'amount': 50000},
          {'ts': ms, 'amount': 30000},
          {'ts': wibToMs(2026, 10, 26, 9), 'amount': 99999},
        ],
        expenses: [
          {'ts': ms, 'amount': 20000},
        ],
        sessions: [
          {'start': ms, 'end': ms + 2 * 3600000, 'odoStart': 1000, 'odoEnd': 1040},
        ],
        nowMs: ms + 3 * 3600000,
      );
      expect(s.gross, 80000);
      expect(s.expense, 20000);
      expect(s.net, 60000);
      expect(s.netPerHour, 30000);
      expect(s.km, 40);
      expect(s.costPerKm, 500);
    });
  });

  group('Bahan bakar', () {
    test('Rp10.000 ÷ Rp10.000/L = 1 liter', () {
      expect(litersOf({'paid': 10000, 'pricePerL': 10000}), 1);
      expect(litersOf({'paid': 10000, 'pricePerL': 10000, 'liters': 1.2}), 1.2);
    });
    test('Satu transaksi tidak cukup untuk km/liter', () {
      final s = fuelStats([
        {'ts': 1, 'paid': 20000, 'pricePerL': 10000, 'full': true, 'odometer': 1000},
      ]);
      expect(s.kmPerL, null);
      expect(s.validIntervals, 0);
    });
    test('Tangki penuh → tangki penuh', () {
      final s = fuelStats([
        {'ts': 1, 'paid': 40000, 'pricePerL': 10000, 'full': true, 'odometer': 1000},
        {'ts': 2, 'paid': 10000, 'pricePerL': 10000, 'full': false},
        {'ts': 3, 'paid': 20000, 'pricePerL': 10000, 'full': true, 'odometer': 1150},
      ]);
      // 150 km / (1 + 2) liter = 50 km/L
      expect(s.kmPerL, 50);
      expect(s.costPerKm, 200);
      expect(s.totalSpent, 70000);
    });
    test('Jarak tersisa', () {
      final fuels = [
        {'ts': 1, 'paid': 40000, 'pricePerL': 10000, 'full': true, 'odometer': 1000},
      ];
      final r = remainingRangeKm(fuels: fuels, kmPerL: 50, tankCapacityL: 4, currentOdo: 1100);
      expect(r, 100); // 4 − 2 = 2 liter × 50
      expect(remainingRangeKm(fuels: fuels, kmPerL: null, tankCapacityL: 4, currentOdo: 1100), null);
    });
  });

  group('Keselamatan', () {
    test('Mengantuk selalu menyarankan berhenti', () {
      final a = restAdvice(
          working: true, minutesSinceRest: 5, totalMinutesToday: 5, intervalMin: 120, condition: 'mengantuk');
      expect(a?.level, DueLevel.due);
    });
    test('Pengingat istirahat sesuai interval', () {
      expect(
          restAdvice(working: true, minutesSinceRest: 60, totalMinutesToday: 60, intervalMin: 120, condition: null),
          null);
      expect(
          restAdvice(working: true, minutesSinceRest: 125, totalMinutesToday: 125, intervalMin: 120, condition: null)
              ?.level,
          DueLevel.due);
    });
  });

  group('Peta simulasi', () {
    test('Zona diberi label Data Simulasi', () {
      final z = simulateZones(city: cities.first, service: 'Makanan', hourWib: 12);
      expect(z.length, 8);
      expect(z.every((e) => e.source == DataSource.simulasi), true);
      expect(sourceLabel(z.first.source), 'Data Simulasi');
    });
  });
}
