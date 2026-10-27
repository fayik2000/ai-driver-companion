import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/demand.dart';
import '../state/app_state.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../util/format.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              const Icon(Icons.two_wheeler, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              const Text('Selamat datang di\nAI Driver Companion',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 8),
              const Text(
                'Pendamping untuk mencatat penghasilan bersih, bahan bakar, dan menjaga keselamatan kerja. '
                'Aplikasi ini bukan bagian dari Gojek, Grab, atau platform lain.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              const DemoBanner(),
              ProfileForm(
                initial: null,
                saveLabel: 'Mulai',
                onSaved: (p) => AppState.I.saveProfile(p),
              ),
            ],
          ),
        ),
      );
}

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ubah profil')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileForm(
              initial: AppState.I.profile,
              saveLabel: 'Simpan perubahan',
              onSaved: (p) {
                AppState.I.saveProfile(p);
                snack(context, 'Profil disimpan.');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.initial, required this.onSaved, required this.saveLabel});
  final Rec? initial;
  final ValueChanged<Rec> onSaved;
  final String saveLabel;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final Rec p = {...?widget.initial};
  late final nick = TextEditingController(text: (p['nickname'] as String?) ?? '');
  late final brand = TextEditingController(text: (p['motorBrand'] as String?) ?? '');
  late final model = TextEditingController(text: (p['motorModel'] as String?) ?? '');
  late final cc = TextEditingController(text: _t(p['engineCc']));
  late final kmpl = TextEditingController(text: _t(p['fuelKmPerL']));
  late final tank = TextEditingController(text: _t(p['tankCapacityL']));
  late final target = TextEditingController(text: _t(p['dailyTarget']));
  late final otherCity = TextEditingController(text: (p['cityOther'] as String?) ?? '');
  late Set<String> services = {...((p['services'] as List?) ?? const ['Makanan']).map((e) => e.toString())};
  late String city = (p['city'] as String?) ?? cities.first.name;
  late String fuel = (p['fuelType'] as String?) ?? 'Pertalite';
  late String start = (p['workStart'] as String?) ?? '08:00';
  late String end = (p['workEnd'] as String?) ?? '17:00';

  static String _t(dynamic v) => v is num ? (v == v.roundToDouble() ? '${v.round()}' : '$v'.replaceAll('.', ',')) : '';

  Future<void> _pickTime(bool isStart) async {
    final parts = (isStart ? start : end).split(':');
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (r == null) return;
    final v = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        start = v;
      } else {
        end = v;
      }
    });
  }

  void _save() {
    if (nick.text.trim().isEmpty) return snack(context, 'Isi nama panggilan dulu.');
    if (services.isEmpty) return snack(context, 'Pilih minimal satu jenis layanan.');
    widget.onSaved({
      ...p,
      'nickname': nick.text.trim(),
      'services': services.toList(),
      'city': city,
      'cityOther': city == 'Lainnya' ? otherCity.text.trim() : null,
      'motorBrand': brand.text.trim(),
      'motorModel': model.text.trim(),
      'engineCc': parseNum(cc.text),
      'fuelType': fuel,
      // Boleh kosong: aplikasi tidak menebak konsumsi BBM Anda.
      'fuelKmPerL': parseNum(kmpl.text),
      'tankCapacityL': parseNum(tank.text),
      'dailyTarget': parseNum(target.text),
      'workStart': start,
      'workEnd': end,
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget gap() => const SizedBox(height: 12);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: nick, decoration: const InputDecoration(labelText: 'Nama panggilan')),
      gap(),
      const Text('Jenis layanan yang dijalankan', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (final sv in serviceTypes)
          FilterChip(
            label: Text(sv),
            selected: services.contains(sv),
            onSelected: (v) => setState(() => v ? services.add(sv) : services.remove(sv)),
          ),
      ]),
      gap(),
      dropdown('Kota / wilayah operasional', city, [...cities.map((c) => c.name), 'Lainnya'],
          (v) => setState(() => city = v)),
      if (city == 'Lainnya') ...[
        gap(),
        TextField(
          controller: otherCity,
          decoration: const InputDecoration(
              labelText: 'Nama kota/wilayah', helperText: 'Peta akan memakai Lamongan sebagai titik awal.'),
        ),
      ],
      gap(),
      Row(children: [
        Expanded(child: TextField(controller: brand, decoration: const InputDecoration(labelText: 'Merek motor'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Model'))),
      ]),
      gap(),
      Row(children: [
        Expanded(child: numField(cc, 'Kapasitas mesin', suffix: 'cc')),
        const SizedBox(width: 12),
        Expanded(child: dropdown('Bahan bakar', fuel, fuelTypes, (v) => setState(() => fuel = v))),
      ]),
      gap(),
      numField(kmpl, 'Konsumsi BBM (jika tahu, opsional)', suffix: 'km/L'),
      gap(),
      numField(tank, 'Kapasitas tangki (opsional)', suffix: 'L'),
      gap(),
      numField(target, 'Target penghasilan bersih harian', suffix: 'Rp'),
      gap(),
      const Text('Jam kerja yang direncanakan', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _pickTime(true), icon: const Icon(Icons.schedule), label: Text('Mulai $start')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _pickTime(false), icon: const Icon(Icons.schedule), label: Text('Selesai $end')),
        ),
      ]),
      const SizedBox(height: 20),
      FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
    ]);
  }
}
