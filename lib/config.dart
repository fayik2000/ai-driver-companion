import 'package:firebase_core/firebase_core.dart';

/// Konfigurasi Firebase dibaca dari --dart-define saat build.
/// Jika FIREBASE_API_KEY kosong, aplikasi berjalan dalam Mode Demo
/// (data disimpan di HP, AI Coach memakai analisis aturan sederhana).
class AppConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// Model Gemini lewat Firebase AI Logic. Bisa diganti tanpa ubah kode.
  static const geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.8-flash');

  static bool get firebaseConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      );
}

/// Status integrasi yang benar-benar aktif saat aplikasi berjalan.
class RuntimeStatus {
  static bool firebaseReady = false;
  static String? firebaseError;

  static bool get demoMode => !firebaseReady;
}
