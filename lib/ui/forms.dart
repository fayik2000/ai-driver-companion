import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/calc.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import 'theme.dart';
import 'widgets.dart';

const serviceTypes = ['Penumpang', 'Makanan', 'Barang', 'Lainnya'];
const expenseCategories = [
  'Bahan bakar',
  'Makan dan minum',
  'Parkir',
  'Internet atau paket data',
  'Perawatan kendaraan',
  'Biaya operasional lainnya',
];
const fuelTypes = ['Pertalite', 'Pertamax', 'Pertamax Turbo', 'Solar', 'Listrik/lainnya'];

final _numFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

String _numText(dynamic v) {
  if (v is! num) return '';
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toString().replaceAll('.', ',');
}

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: child,
      ),
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children, required this.onSave, this.onDelete});
  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
          Row(children: [
            if (onDelete != null) ...[
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: FilledButton(onPressed: onSave, child: const Text('Simpan'))),
          ]),
        ]),
      );
}

TextField numField(TextEditingController c, String label, {String? hint, String? suffix, ValueChanged<String>? onChanged}) =>
    TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_numFormatter],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: hint, suffixText: suffix),
    );

/// Pemilih tanggal & jam (dianggap WIB).
class DateTimeField extends StatelessWidget {
  const DateTimeField({super.key, required this.ms, required this.onChanged});
  final int ms;
  final ValueChanged<int> onChanged;

  Future<void> _pick(BuildContext context) async {
    final t = wib(ms);
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(t.year, t.month, t.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !context.mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
    onChanged(wibToMs(d.year, d.month, d.day, tm?.hour ?? t.hour, tm?.minute ?? t.minute));
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Tanggal & waktu (WIB)', suffixIcon: Icon(Icons.event)),
          child: Text(fmtDateTime(ms)),
        ),
      );
}

Widget dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) =>
    DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );

// ───────────────────────── PENGHASILAN ─────────────────────────

Future<void> showIncomeForm(BuildContext context, [Rec? rec]) => _sheet(context, _IncomeForm(rec));

class _IncomeForm extends StatefulWidget {
  const _IncomeForm(this.rec);
  final Rec? rec;
  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  late int ts = numOf(widget.rec?['ts'] ?? nowMs()).toInt();
  late String service = (widget.rec?['service'] as String?) ?? _defaultService();
  late final amount = TextEditingController(text: _numText(widget.rec?['amount']));
  late final note = TextEditingController(text: (widget.rec?['note'] as String?) ?? '');

  String _defaultService() {
    final s = AppState.I.profile?['services'];
    if (s is List && s.isNotEmpty) return s.first.toString();
    return serviceTypes.first;
  }

  void _save() {
    final a = parseNum(amount.text);
    if (a == null || a <= 0) return snack(context, 'Masukkan jumlah penghasilan.');
    AppState.I.save(Cols.incomes, {
      ...?widget.rec,
      'ts': ts,
      'service': service,
      'amount': a,
      'note': note.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: widget.rec == null ? 'Catat penghasilan' : 'Ubah penghasilan',
        onSave: _save,
        onDelete: widget.rec == null
            ? null
            : () async {
                if (await confirm(context, 'Hapus catatan?', 'Catatan penghasilan ini akan dihapus.')) {
                  AppState.I.delete(Cols.incomes, widget.rec!['id'] as String);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        children: [
          numField(amount, 'Jumlah penghasilan', hint: 'contoh 25.000', suffix: 'Rp'),
          dropdown('Jenis layanan', service, serviceTypes, (v) => setState(() => service = v)),
          DateTimeField(ms: ts, onChanged: (v) => setState(() => ts = v)),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
        ],
      );
}

// ───────────────────────── PENGELUARAN ─────────────────────────

Future<void> showExpenseForm(BuildContext context, [Rec? rec]) {
  if (rec != null && (AppState.I.isFuelLinked(rec) || AppState.I.isMaintLinked(rec))) {
    final src = AppState.I.isFuelLinked(rec) ? 'Smart Fuel' : 'Perawatan Kendaraan';
    snack(context, 'Pengeluaran ini dibuat dari $src. Ubah atau hapus lewat menu $src.');
    return Future.value();
  }
  return _sheet(context, _ExpenseForm(rec));
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm(this.rec);
  final Rec? rec;
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late int ts = numOf(widget.rec?['ts'] ?? nowMs()).toInt();
  late String category = (widget.rec?['category'] as String?) ?? expenseCategories[1];
  late final amount = TextEditingController(text: _numText(widget.rec?['amount']));
  late final note = TextEditingController(text: (widget.rec?['note'] as String?) ?? '');

  void _save() {
    final a = parseNum(amount.text);
    if (a == null || a <= 0) return snack(context, 'Masukkan jumlah pengeluaran.');
    AppState.I.save(Cols.expenses, {
      ...?widget.rec,
      'ts': ts,
      'category': category,
      'amount': a,
      'note': note.text.trim(),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: widget.rec == null ? 'Catat pengeluaran' : 'Ubah pengeluaran',
        onSave: _save,
        onDelete: widget.rec == null
            ? null
            : () async {
                if (await confirm(context, 'Hapus catatan?', 'Catatan pengeluaran ini akan dihapus.')) {
                  AppState.I.delete(Cols.expenses, widget.rec!['id'] as String);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        children: [
          numField(amount, 'Jumlah pengeluaran', hint: 'contoh 15.000', suffix: 'Rp'),
          dropdown('Kategori', category, expenseCategories, (v) => setState(() => category = v)),
          if (category == 'Bahan bakar')
            const Text(
              'Tips: catat bensin lewat Smart Fuel agar konsumsi km/liter bisa dihitung.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          DateTimeField(ms: ts, onChanged: (v) => setState(() => ts = v)),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
        ],
      );
}

// ───────────────────────── BAHAN BAKAR ─────────────────────────

Future<void> showFuelForm(BuildContext context, [Rec? rec]) => _sheet(context, _FuelForm(rec));

class _FuelForm extends StatefulWidget {
  const _FuelForm(this.rec);
  final Rec? rec;
  @override
  State<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends State<_FuelForm> {
  final s = AppState.I;
  late int ts = numOf(widget.rec?['ts'] ?? nowMs()).toInt();
  late String fuel = (widget.rec?['fuelType'] as String?) ?? s.fuelType;
  late final price = TextEditingController(text: _numText(widget.rec?['pricePerL'] ?? s.priceFor(fuel)));
  late final paid = TextEditingController(text: _numText(widget.rec?['paid']));
  late final liters = TextEditingController(text: _numText(widget.rec?['liters']));
  late final odo = TextEditingController(text: _numText(widget.rec?['odometer']));
  late bool full = widget.rec?['full'] == true;
  bool savePrice = true;

  String get _preview {
    final l = parseNum(liters.text);
    if (l != null && l > 0) return 'Liter dimasukkan manual: ${fmtNum(l, 2)} L';
    final p = parseNum(price.text), b = parseNum(paid.text);
    if (p == null || p <= 0 || b == null || b <= 0) return 'Isi harga per liter dan jumlah bayar untuk menghitung liter.';
    return 'Perkiraan: ${fmtNum(b / p, 2)} liter (${rupiah(b)} ÷ ${rupiah(p)}/L)';
  }

  void _save() {
    final p = parseNum(price.text), b = parseNum(paid.text);
    if (b == null || b <= 0) return snack(context, 'Masukkan jumlah uang yang dibayarkan.');
    final l = parseNum(liters.text);
    if ((p == null || p <= 0) && (l == null || l <= 0)) {
      return snack(context, 'Isi harga per liter atau jumlah liter.');
    }
    final o = parseNum(odo.text);
    s.saveFuel({
      ...?widget.rec,
      'ts': ts,
      'fuelType': fuel,
      'pricePerL': p,
      'paid': b,
      'liters': (l != null && l > 0) ? l : null,
      'odometer': o,
      'full': full,
    });
    if (savePrice && p != null && p > 0) {
      final prices = Map<String, dynamic>.from((s.settings['fuelPrices'] as Map?) ?? {});
      prices[fuel] = p;
      s.updateSettings({'fuelPrices': prices});
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: widget.rec == null ? 'Catat isi bahan bakar' : 'Ubah catatan bahan bakar',
        onSave: _save,
        onDelete: widget.rec == null
            ? null
            : () async {
                if (await confirm(context, 'Hapus catatan?', 'Catatan BBM dan pengeluarannya akan dihapus.')) {
                  s.deleteFuel(widget.rec!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        children: [
          dropdown('Jenis bahan bakar', fuel, fuelTypes, (v) {
            setState(() {
              fuel = v;
              final pr = s.priceFor(v);
              if (pr != null) price.text = _numText(pr);
            });
          }),
          numField(price, 'Harga per liter', suffix: 'Rp/L', onChanged: (_) => setState(() {})),
          CheckboxListTile(
            value: savePrice,
            onChanged: (v) => setState(() => savePrice = v ?? true),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Simpan sebagai harga di lokasi saya'),
          ),
          numField(paid, 'Jumlah dibayar', hint: 'contoh 10.000', suffix: 'Rp', onChanged: (_) => setState(() {})),
          numField(liters, 'Jumlah liter (jika tahu, opsional)', suffix: 'L', onChanged: (_) => setState(() {})),
          Text(_preview, style: const TextStyle(fontSize: 13, color: AppColors.primary)),
          numField(odo, 'Angka odometer (opsional, disarankan)', suffix: 'km'),
          SwitchListTile(
            value: full,
            onChanged: (v) => setState(() => full = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Isi sampai tangki penuh'),
            subtitle: const Text('Isi penuh + odometer diperlukan untuk menghitung km/liter.'),
          ),
          DateTimeField(ms: ts, onChanged: (v) => setState(() => ts = v)),
        ],
      );
}

// ───────────────────────── PERAWATAN ─────────────────────────

Future<void> showMaintForm(BuildContext context, [Rec? rec]) => _sheet(context, _MaintForm(rec));

class _MaintForm extends StatefulWidget {
  const _MaintForm(this.rec);
  final Rec? rec;
  @override
  State<_MaintForm> createState() => _MaintFormState();
}

class _MaintFormState extends State<_MaintForm> {
  final s = AppState.I;
  late int ts = numOf(widget.rec?['ts'] ?? nowMs()).toInt();
  late String category = (widget.rec?['category'] as String?) ?? maintTypes.first.name;
  late final odo = TextEditingController(text: _numText(widget.rec?['odometer'] ?? s.currentOdo));
  late final cost = TextEditingController(text: _numText(widget.rec?['cost']));
  late final note = TextEditingController(text: (widget.rec?['note'] as String?) ?? '');
  late final days = TextEditingController(text: _numText(widget.rec?['intervalDays'] ?? maintTypes.first.days));
  late final km = TextEditingController(text: _numText(widget.rec?['intervalKm'] ?? maintTypes.first.km));
  late bool asExpense = widget.rec == null || widget.rec?['expenseId'] != null;

  void _save() {
    s.saveMaintenance({
      ...?widget.rec,
      'ts': ts,
      'category': category,
      'odometer': parseNum(odo.text),
      'cost': parseNum(cost.text) ?? 0,
      'note': note.text.trim(),
      'intervalDays': parseNum(days.text)?.round(),
      'intervalKm': parseNum(km.text)?.round(),
    }, asExpense: asExpense);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
        title: widget.rec == null ? 'Catat perawatan' : 'Ubah perawatan',
        onSave: _save,
        onDelete: widget.rec == null
            ? null
            : () async {
                if (await confirm(context, 'Hapus catatan?', 'Catatan perawatan ini akan dihapus.')) {
                  s.deleteMaintenance(widget.rec!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
        children: [
          dropdown('Jenis perawatan', category, [for (final t in maintTypes) t.name], (v) {
            setState(() {
              category = v;
              if (widget.rec == null) {
                final t = maintTypes.firstWhere((e) => e.name == v);
                days.text = '${t.days}';
                km.text = '${t.km}';
              }
            });
          }),
          DateTimeField(ms: ts, onChanged: (v) => setState(() => ts = v)),
          numField(odo, 'Odometer saat perawatan', suffix: 'km'),
          numField(cost, 'Biaya', suffix: 'Rp'),
          SwitchListTile(
            value: asExpense,
            onChanged: (v) => setState(() => asExpense = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Catat biaya sebagai pengeluaran'),
          ),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Keterangan (opsional)')),
          const Text('Pengingat berikutnya',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          Row(children: [
            Expanded(child: numField(days, 'Setiap', suffix: 'hari')),
            const SizedBox(width: 12),
            Expanded(child: numField(km, 'atau setiap', suffix: 'km')),
          ]),
          const Text(
            'Angka bawaan hanya titik awal. Sesuaikan dengan buku servis atau rekomendasi produsen motor Anda.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      );
}

// ───────────────────────── ODOMETER (sesi kerja) ─────────────────────────

/// Mengembalikan null bila dibatalkan; (odo) bisa null bila dilewati.
Future<({double? odo})?> askOdometer(BuildContext context, String title) {
  final c = TextEditingController(text: _numText(AppState.I.currentOdo));
  return showDialog<({double? odo})>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        numField(c, 'Odometer (opsional)', suffix: 'km'),
        const SizedBox(height: 8),
        const Text('Mengisi odometer di awal & akhir sesi memungkinkan hitung biaya per km.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(d, (odo: parseNum(c.text)?.toDouble())),
          child: const Text('Lanjut'),
        ),
      ],
    ),
  );
}
