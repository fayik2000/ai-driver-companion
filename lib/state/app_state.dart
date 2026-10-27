import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/store.dart';
import '../logic/calc.dart';
import '../util/format.dart';

/// Status aplikasi: memuat data dari penyimpanan, menyimpan perubahan,
/// dan menyediakan ringkasan siap pakai untuk layar.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  DataStore? store;
  bool loaded = false;
  String? lastError;
  Timer? _ticker;

  final Map<String, List<Rec>> _cols = {for (final c in Cols.all) c: <Rec>[]};
  Rec? profile;
  Rec settings = defaultSettings();

  static Rec defaultSettings() => {
        'restIntervalMin': 120,
        // Harga awal hanya titik mulai — ubah sesuai harga di SPBU Anda.
        'fuelPrices': {'Pertalite': 10000, 'Pertamax': 12500, 'Pertamax Turbo': 13500, 'Solar': 6800},
        'condition': null,
        'conditionAt': null,
        'currentOdo': null,
      };

  Future<void> init(DataStore s) async {
    store = s;
    loaded = false;
    notifyListeners();
    final cols = await s.loadCollections();
    final docs = await s.loadDocs();
    for (final c in Cols.all) {
      _cols[c] = cols[c] ?? <Rec>[];
    }
    profile = docs[Docs.profile];
    settings = {...defaultSettings(), ...?docs[Docs.settings]};
    loaded = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (activeSession != null) notifyListeners();
    });
    notifyListeners();
  }

  // ───── akses data ─────
  List<Rec> col(String c) => _cols[c]!;
  List<Rec> get incomes => col(Cols.incomes);
  List<Rec> get expenses => col(Cols.expenses);
  List<Rec> get fuels => col(Cols.fuels);
  List<Rec> get sessions => col(Cols.sessions);
  List<Rec> get maintenance => col(Cols.maintenance);
  List<Rec> get coachResults => col(Cols.coach);
  List<Rec> get insightsSaved => col(Cols.insights);

  List<Rec> sortedDesc(String c, [String field = 'ts']) =>
      [...col(c)]..sort((a, b) => numOf(b[field]).compareTo(numOf(a[field])));

  void _persist(Future<void> f) {
    // Firestore menyelesaikan Future saat server menerima data; saat offline
    // data tetap tersimpan di cache dan akan dikirim otomatis.
    f.catchError((Object e) {
      lastError = 'Gagal menyimpan: $e';
      notifyListeners();
    });
  }

  void save(String c, Rec rec) {
    rec['id'] ??= newId();
    final list = col(c);
    final i = list.indexWhere((e) => e['id'] == rec['id']);
    if (i >= 0) {
      list[i] = rec;
    } else {
      list.add(rec);
    }
    notifyListeners();
    _persist(store!.put(c, rec));
  }

  void delete(String c, String id) {
    col(c).removeWhere((e) => e['id'] == id);
    notifyListeners();
    _persist(store!.remove(c, id));
  }

  void saveProfile(Rec p) {
    profile = p;
    notifyListeners();
    _persist(store!.setDoc(Docs.profile, p));
  }

  void saveSettings(Rec s) {
    settings = s;
    notifyListeners();
    _persist(store!.setDoc(Docs.settings, s));
  }

  void updateSettings(Map<String, dynamic> patch) => saveSettings({...settings, ...patch});

  // ───── profil ─────
  num? get dailyTarget => profile?['dailyTarget'] as num?;
  String get nickname => (profile?['nickname'] as String?) ?? 'Pengemudi';
  String get fuelType => (profile?['fuelType'] as String?) ?? 'Pertalite';
  double? get tankCapacity => dblOrNull(profile?['tankCapacityL']);
  int get restIntervalMin => (numOf(settings['restIntervalMin']).toInt()).clamp(15, 600);

  double? priceFor(String fuel) {
    final m = settings['fuelPrices'];
    if (m is Map && m[fuel] is num) return (m[fuel] as num).toDouble();
    return null;
  }

  // ───── bahan bakar (tersambung otomatis ke pengeluaran) ─────
  void saveFuel(Rec f) {
    f['id'] ??= newId();
    final expId = (f['expenseId'] as String?) ?? newId();
    f['expenseId'] = expId;
    save(Cols.fuels, f);
    save(Cols.expenses, {
      'id': expId,
      'ts': f['ts'],
      'category': 'Bahan bakar',
      'amount': f['paid'],
      'note': '${f['fuelType']} · ${fmtNum(litersOf(f), 2)} L',
      'fuelId': f['id'],
    });
    final odo = dblOrNull(f['odometer']);
    if (odo != null) _bumpOdo(odo);
  }

  void deleteFuel(Rec f) {
    delete(Cols.fuels, f['id'] as String);
    final e = f['expenseId'] as String?;
    if (e != null) delete(Cols.expenses, e);
  }

  /// Pengeluaran BBM yang dibuat dari Smart Fuel dikelola dari sana.
  bool isFuelLinked(Rec expense) => expense['fuelId'] != null;
  bool isMaintLinked(Rec expense) => expense['maintId'] != null;

  // ───── perawatan ─────
  void saveMaintenance(Rec m, {required bool asExpense}) {
    m['id'] ??= newId();
    final cost = numOf(m['cost']);
    if (asExpense && cost > 0) {
      final expId = (m['expenseId'] as String?) ?? newId();
      m['expenseId'] = expId;
      save(Cols.expenses, {
        'id': expId,
        'ts': m['ts'],
        'category': 'Perawatan kendaraan',
        'amount': cost,
        'note': m['category'],
        'maintId': m['id'],
      });
    } else if (m['expenseId'] != null) {
      delete(Cols.expenses, m['expenseId'] as String);
      m.remove('expenseId');
    }
    save(Cols.maintenance, m);
    final odo = dblOrNull(m['odometer']);
    if (odo != null) _bumpOdo(odo);
  }

  void deleteMaintenance(Rec m) {
    delete(Cols.maintenance, m['id'] as String);
    final e = m['expenseId'] as String?;
    if (e != null) delete(Cols.expenses, e);
  }

  void _bumpOdo(double odo) {
    final cur = dblOrNull(settings['currentOdo']);
    if (cur == null || odo > cur) updateSettings({'currentOdo': odo});
  }

  double? get currentOdo =>
      dblOrNull(settings['currentOdo']) ?? latestOdometer(fuels, sessions, maintenance);

  // ───── sesi kerja & keselamatan ─────
  Rec? get activeSession {
    for (final s in sessions) {
      if (s['end'] == null) return s;
    }
    return null;
  }

  String get workStatus {
    if (activeSession != null) return 'Sedang bekerja';
    final today = todayKey();
    final any = sessions.any((s) => dayKey(numOf(s['start']).toInt()) == today);
    return any ? 'Sudah selesai' : 'Belum mulai';
  }

  void startSession({double? odo}) {
    if (activeSession != null) return;
    final now = nowMs();
    save(Cols.sessions, {'start': now, 'end': null, 'odoStart': odo, 'odoEnd': null, 'lastRestAt': now, 'rests': 0});
    if (odo != null) _bumpOdo(odo);
    updateSettings({'condition': null, 'conditionAt': null});
  }

  void endSession({double? odo}) {
    final s = activeSession;
    if (s == null) return;
    save(Cols.sessions, {...s, 'end': nowMs(), 'odoEnd': odo});
    if (odo != null) _bumpOdo(odo);
  }

  void markRest() {
    final s = activeSession;
    if (s == null) return;
    save(Cols.sessions, {...s, 'lastRestAt': nowMs(), 'rests': numOf(s['rests']) + 1});
    updateSettings({'condition': 'segar', 'conditionAt': nowMs()});
  }

  void reportCondition(String c) => updateSettings({'condition': c, 'conditionAt': nowMs()});

  /// Kondisi yang dilaporkan dalam 3 jam terakhir.
  String? get recentCondition {
    final at = intOrNull(settings['conditionAt']);
    if (at == null || nowMs() - at > 3 * 3600000) return null;
    return settings['condition'] as String?;
  }

  int get minutesSinceRest {
    final s = activeSession;
    if (s == null) return 0;
    final from = intOrNull(s['lastRestAt']) ?? intOrNull(s['start']) ?? nowMs();
    return ((nowMs() - from) / 60000).floor();
  }

  // ───── ringkasan ─────
  PeriodSummary summaryFor(Iterable<String> days) => summarize(
        dayKeys: days.toSet(),
        incomes: incomes,
        expenses: expenses,
        sessions: sessions,
        nowMs: nowMs(),
      );

  PeriodSummary get today => summaryFor([todayKey()]);

  SafetyAdvice? get safety => restAdvice(
        working: activeSession != null,
        minutesSinceRest: minutesSinceRest,
        totalMinutesToday: today.workMinutes,
        intervalMin: restIntervalMin,
        condition: recentCondition,
      );

  FuelStats get fuel => fuelStats(fuels);

  List<MaintDue> get maintStatus => maintenanceStatus(maintenance, currentOdo, nowMs());

  num fuelOn(String day) => expenseByCategory(expenses, {day})['Bahan bakar'] ?? 0;

  List<Insight> get insights {
    final prevDays = [for (var i = 1; i <= 3; i++) dayKeyOffset(i)];
    return dailyInsights(
      today: today,
      previousDays: [for (final d in prevDays) summaryFor([d])],
      dailyTarget: dailyTarget,
      fuelToday: fuelOn(todayKey()),
      fuelPrevDays: [for (final d in prevDays) fuelOn(d)],
      safety: safety,
      maint: maintStatus,
    );
  }
}
