import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'data/store.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DriverApp());
}

/// Menyiapkan penyimpanan: Firebase bila dikonfigurasi, jika tidak Mode Demo (lokal).
Future<void> bootstrap() async {
  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(options: AppConfig.options);
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      RuntimeStatus.firebaseReady = true;
      await AppState.I.init(FirestoreStore(auth.currentUser!.uid));
      return;
    } catch (e) {
      RuntimeStatus.firebaseReady = false;
      RuntimeStatus.firebaseError = e.toString();
    }
  }
  final local = LocalStore();
  await local.init();
  await AppState.I.init(local);
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AI Driver Companion',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      );
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late Future<void> _boot = bootstrap();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _boot,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.two_wheeler, size: 56, color: AppColors.primary),
                  SizedBox(height: 16),
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Menyiapkan data…'),
                ]),
              ),
            );
          }
          if (snap.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Gagal memuat data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _boot = bootstrap()),
                      child: const Text('Coba lagi'),
                    ),
                  ]),
                ),
              ),
            );
          }
          return ListenableBuilder(
            listenable: AppState.I,
            builder: (context, _) =>
                AppState.I.profile == null ? const OnboardingScreen() : const Shell(),
          );
        },
      );
}
