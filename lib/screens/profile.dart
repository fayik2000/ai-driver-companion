import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../data/store.dart';
import '../state/app_state.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';
import 'fuel.dart';
import 'onboarding.dart';
import 'safety.dart';
import 'vehicle.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final p = s.profile ?? {};
          final city = p['city'] == 'Lainnya' ? (p['cityOther'] ?? 'Lainnya') : p['city'];
          String v(dynamic x, [String suffix = '']) =>
              (x == null || (x is String && x.isEmpty)) ? '—' : '$x$suffix';
          void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

          return Scaffold(
            appBar: AppBar(title: const Text('Profil')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.goodBg,
                        child: Icon(Icons.person, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.nickname, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('${v(city)} · ${((p['services'] as List?) ?? []).join(', ')}',
                              style: const TextStyle(color: AppColors.muted)),
                        ]),
                      ),
                      IconButton(onPressed: () => go(const ProfileEditScreen()), icon: const Icon(Icons.edit)),
                    ]),
                    const Divider(height: 24),
                    _kv('Motor', '${v(p['motorBrand'])} ${p['motorModel'] ?? ''}'.trim()),
                    _kv('Mesin', v(p['engineCc'], ' cc')),
                    _kv('Bahan bakar', v(p['fuelType'])),
                    _kv('Konsumsi BBM (profil)', p['fuelKmPerL'] == null ? 'Belum diisi' : '${fmtNum(p['fuelKmPerL'] as num)} km/L'),
                    _kv('Kapasitas tangki', p['tankCapacityL'] == null ? 'Belum diisi' : '${fmtNum(p['tankCapacityL'] as num)} L'),
                    _kv('Target harian', s.dailyTarget == null ? 'Belum diisi' : rupiah(s.dailyTarget!)),
                    _kv('Jam kerja', '${v(p['workStart'])} – ${v(p['workEnd'])} WIB'),
                  ]),
                ),
                const SectionTitle('Alat bantu'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _nav(Icons.local_gas_station, 'Smart Fuel', 'Konsumsi BBM & biaya per km', () => go(const FuelScreen())),
                    _nav(Icons.build_outlined, 'Perawatan kendaraan', 'Riwayat & pengingat servis', () => go(const VehicleScreen())),
                    _nav(Icons.health_and_safety_outlined, 'Keselamatan', 'Interval pengingat istirahat', () => go(const SafetyScreen())),
                    _nav(Icons.price_change_outlined, 'Harga BBM di lokasi saya', 'Dipakai untuk menghitung liter',
                        () => _editPrices(context)),
                  ]),
                ),
                const SectionTitle('Akun & data'),
                const _AccountCard(),
                const SectionTitle('Status integrasi'),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _status('Penyimpanan', s.store?.label ?? '—', true),
                    _status('Firebase', RuntimeStatus.firebaseReady ? 'Terhubung' : 'Belum terhubung (Mode Demo)',
                        RuntimeStatus.firebaseReady),
                    _status('AI Coach (Gemini)', RuntimeStatus.firebaseReady ? 'Aktif via Firebase AI Logic' : 'Tidak aktif — memakai aturan sederhana',
                        RuntimeStatus.firebaseReady),
                    _status('Data pesanan platform (Gojek/Grab, dll.)', 'Tidak terhubung — Peta Peluang memakai data simulasi', false),
                    if (RuntimeStatus.firebaseError != null) ...[
                      const SizedBox(height: 8),
                      Text('Kesalahan Firebase: ${RuntimeStatus.firebaseError}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('AI Driver Companion v1.0 · Bukan aplikasi resmi platform mana pun',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ),
              ],
            ),
          );
        },
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );

  Widget _nav(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  Widget _status(String k, String v, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ok ? Icons.check_circle : Icons.remove_circle_outline,
              size: 18, color: ok ? AppColors.primary : AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$k\n', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: v, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ])),
          ),
        ]),
      );

  Future<void> _editPrices(BuildContext context) async {
    final s = AppState.I;
    final ctrls = {for (final f in fuelTypes.take(4)) f: TextEditingController(text: '${s.priceFor(f)?.round() ?? ''}')};
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Harga BBM per liter'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Sesuaikan dengan harga di SPBU tempat Anda biasa mengisi.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 12),
            for (final e in ctrls.entries)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: numField(e.value, e.key, suffix: 'Rp/L')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final prices = Map<String, dynamic>.from((s.settings['fuelPrices'] as Map?) ?? {});
              ctrls.forEach((k, ctl) {
                final n = parseNum(ctl.text);
                if (n != null && n > 0) prices[k] = n;
              });
              s.updateSettings({'fuelPrices': prices});
              Navigator.pop(c);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard();
  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool busy = false;

  Future<({String email, String pass})?> _askCred(String title) {
    final e = TextEditingController(), p = TextEditingController();
    return showDialog<({String email, String pass})>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Kata sandi (min. 6 karakter)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, (email: e.text.trim(), pass: p.text)), child: const Text('Lanjut')),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => busy = true);
    try {
      await f();
      if (mounted) snack(context, ok);
    } on FirebaseAuthException catch (e) {
      if (mounted) snack(context, 'Gagal: ${e.message ?? e.code}');
    } catch (e) {
      if (mounted) snack(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reload() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) await AppState.I.init(FirestoreStore(u.uid));
  }

  @override
  Widget build(BuildContext context) {
    if (!RuntimeStatus.firebaseReady) {
      return const AppCard(
        child: Text(
          'Data tersimpan di HP ini. Hubungkan Firebase (lihat panduan README) agar data aman tersimpan di cloud '
          'dan bisa dipulihkan.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      );
    }
    final u = FirebaseAuth.instance.currentUser;
    final anon = u?.isAnonymous ?? true;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(anon ? 'Akun tamu' : 'Masuk sebagai ${u?.email}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          anon
              ? 'Data Anda tersimpan di Firebase dengan akun tamu. Hubungkan email agar data tidak hilang saat ganti HP.'
              : 'Data tersinkron ke akun ini dan bisa dibuka dari HP lain.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        if (anon) ...[
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final c = await _askCred('Amankan data dengan email');
                    if (c == null) return;
                    await _run(
                      () => u!.linkWithCredential(EmailAuthProvider.credential(email: c.email, password: c.pass)),
                      'Akun berhasil dihubungkan dengan email.',
                    );
                    if (mounted) setState(() {});
                  },
            child: const Text('Hubungkan email'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final ok = await confirm(context, 'Masuk ke akun lain?',
                        'Data akun tamu di HP ini tidak dipindahkan ke akun tersebut.', yes: 'Lanjut');
                    if (!ok) return;
                    final c = await _askCred('Masuk dengan email');
                    if (c == null) return;
                    await _run(() async {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(email: c.email, password: c.pass);
                      await _reload();
                    }, 'Berhasil masuk.');
                  },
            child: const Text('Sudah punya akun? Masuk'),
          ),
        ] else
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final ok = await confirm(context, 'Keluar?', 'Anda bisa masuk lagi dengan email yang sama.', yes: 'Keluar');
                    if (!ok) return;
                    await _run(() async {
                      await FirebaseAuth.instance.signOut();
                      await FirebaseAuth.instance.signInAnonymously();
                      await _reload();
                    }, 'Anda sudah keluar.');
                  },
            child: const Text('Keluar'),
          ),
      ]),
    );
  }
}
