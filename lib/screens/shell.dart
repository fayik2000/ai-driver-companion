import 'package:flutter/material.dart';

import '../logic/calc.dart';
import '../state/app_state.dart';
import 'coach.dart';
import 'finance.dart';
import 'home.dart';
import 'map.dart';
import 'profile.dart';

/// Tab aktif — dipakai tombol cepat di Beranda untuk berpindah menu.
final tabIndex = ValueNotifier<int>(0);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  String? _alerted;

  @override
  void initState() {
    super.initState();
    AppState.I.addListener(_checkRest);
  }

  @override
  void dispose() {
    AppState.I.removeListener(_checkRest);
    super.dispose();
  }

  /// Pengingat istirahat di dalam aplikasi (saat aplikasi terbuka).
  void _checkRest() {
    final s = AppState.I;
    final a = s.safety;
    final session = s.activeSession;
    if (a == null || a.level != DueLevel.due || session == null) return;
    final key = '${session['id']}-${session['lastRestAt']}-${s.recentCondition}';
    if (_alerted == key || !mounted) return;
    _alerted = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.local_cafe_outlined, size: 36),
          title: Text(a.title),
          content: Text(a.body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Nanti')),
            FilledButton(
              onPressed: () {
                AppState.I.markRest();
                Navigator.pop(c);
              },
              child: const Text('Saya sudah istirahat'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: tabIndex,
        builder: (context, i, _) => Scaffold(
          body: IndexedStack(index: i, children: const [
            HomeScreen(),
            MapScreen(),
            FinanceScreen(),
            CoachScreen(),
            ProfileScreen(),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => tabIndex.value = v,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Peta Peluang'),
              NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Keuangan'),
              NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'AI Coach'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        ),
      );
}
