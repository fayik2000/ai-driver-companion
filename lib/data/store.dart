import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Rec = Map<String, dynamic>;

/// Koleksi data yang disimpan aplikasi.
class Cols {
  static const incomes = 'incomes';
  static const expenses = 'expenses';
  static const fuels = 'fuels';
  static const sessions = 'sessions';
  static const maintenance = 'maintenance';
  static const coach = 'coach_results';
  static const insights = 'insights';
  static const all = [incomes, expenses, fuels, sessions, maintenance, coach, insights];
}

/// Dokumen tunggal (profil, pengaturan).
class Docs {
  static const profile = 'profile';
  static const settings = 'settings';
  static const all = [profile, settings];
}

String newId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${r.nextInt(1 << 30).toRadixString(36)}';
}

/// Antarmuka penyimpanan. Dua implementasi: lokal (Mode Demo) dan Firestore.
abstract class DataStore {
  String get label;
  Future<Map<String, List<Rec>>> loadCollections();
  Future<Map<String, Rec?>> loadDocs();
  Future<void> put(String col, Rec rec); // rec wajib punya 'id'
  Future<void> remove(String col, String id);
  Future<void> setDoc(String name, Rec data);
}

/// Penyimpanan di HP (shared_preferences). Data tetap ada setelah aplikasi ditutup.
class LocalStore implements DataStore {
  late SharedPreferences _p;
  final Map<String, List<Rec>> _cache = {};

  @override
  String get label => 'Tersimpan di HP ini (Mode Demo)';

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  List<Rec> _read(String col) {
    final raw = _p.getString('col_$col');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _write(String col) =>
      _p.setString('col_$col', jsonEncode(_cache[col] ?? []));

  @override
  Future<Map<String, List<Rec>>> loadCollections() async {
    for (final c in Cols.all) {
      _cache[c] = _read(c);
    }
    return {for (final c in Cols.all) c: List<Rec>.from(_cache[c]!)};
  }

  @override
  Future<Map<String, Rec?>> loadDocs() async {
    final out = <String, Rec?>{};
    for (final d in Docs.all) {
      final raw = _p.getString('doc_$d');
      out[d] = raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    return out;
  }

  @override
  Future<void> put(String col, Rec rec) async {
    final list = _cache.putIfAbsent(col, () => []);
    final i = list.indexWhere((e) => e['id'] == rec['id']);
    if (i >= 0) {
      list[i] = rec;
    } else {
      list.add(rec);
    }
    await _write(col);
  }

  @override
  Future<void> remove(String col, String id) async {
    _cache[col]?.removeWhere((e) => e['id'] == id);
    await _write(col);
  }

  @override
  Future<void> setDoc(String name, Rec data) =>
      _p.setString('doc_$name', jsonEncode(data));
}

/// Penyimpanan Cloud Firestore: users/{uid}/{koleksi}/{id}.
/// Firestore menyimpan cache offline, jadi aplikasi tetap bisa dipakai tanpa sinyal.
class FirestoreStore implements DataStore {
  FirestoreStore(this.uid);
  final String uid;

  @override
  String get label => 'Tersinkron ke Firebase';

  DocumentReference<Map<String, dynamic>> get _user =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  @override
  Future<Map<String, List<Rec>>> loadCollections() async {
    final out = <String, List<Rec>>{};
    for (final c in Cols.all) {
      final snap = await _user.collection(c).get();
      out[c] = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    }
    return out;
  }

  @override
  Future<Map<String, Rec?>> loadDocs() async {
    final out = <String, Rec?>{};
    for (final d in Docs.all) {
      final ref = _user.collection('meta').doc(d);
      try {
        out[d] = (await ref.get()).data();
      } catch (_) {
        // Offline: coba dari cache, jika belum ada anggap kosong.
        try {
          out[d] = (await ref.get(const GetOptions(source: Source.cache))).data();
        } catch (_) {
          out[d] = null;
        }
      }
    }
    return out;
  }

  @override
  Future<void> put(String col, Rec rec) {
    final data = Map<String, dynamic>.from(rec)..remove('id');
    return _user.collection(col).doc(rec['id'] as String).set(data);
  }

  @override
  Future<void> remove(String col, String id) => _user.collection(col).doc(id).delete();

  @override
  Future<void> setDoc(String name, Rec data) =>
      _user.collection('meta').doc(name).set(data);
}
