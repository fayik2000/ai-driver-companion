# AI Driver Companion

Aplikasi Android (Flutter + Firebase) pendamping pengemudi ojek online, kurir, dan layanan antar: pencatatan penghasilan bersih, Smart Fuel, AI Coach percakapan pelanggan, Peta Peluang (data simulasi), pengingat istirahat, dan perawatan kendaraan.

Aplikasi ini **bukan** bagian dari Gojek, Grab, atau platform lain dan tidak membaca data pesanan mereka.

---

## 1. Cara mendapatkan APK (tanpa install apa pun di komputer)

APK di-build otomatis di server GitHub (gratis) setiap kali kode di-upload.

1. Buat akun di github.com, lalu buat repository baru (boleh *Private*), misalnya `ai-driver-companion`.
2. Upload seluruh isi folder proyek ini ke repository tersebut (termasuk folder tersembunyi `.github`).
3. Buka tab **Actions** di repository → workflow **Build APK** akan berjalan (±8–12 menit).
4. Setelah selesai (centang hijau), buka bagian **Releases** di halaman repository → unduh `AI-Driver-Companion.apk`.
5. Di HP Android: buka file APK → izinkan "Instal dari sumber tidak dikenal" → Instal.

Tanpa pengaturan Firebase, aplikasi berjalan dalam **Mode Demo**: semua fitur bisa dipakai, data tersimpan di HP, dan AI Coach memakai analisis aturan sederhana (diberi label jelas, bukan AI).

## 2. Menghubungkan Firebase (agar data di cloud & AI Coach aktif)

1. Buka https://console.firebase.google.com → **Add project**.
2. **Add app → Android**. Package name: `id.aidriver.ai_driver_companion`. File `google-services.json` tidak wajib diunduh.
3. **Authentication → Sign-in method**: aktifkan **Anonymous** dan **Email/Password**.
4. **Firestore Database → Create database**. Di tab **Rules**, tempel isi file `firestore.rules`, lalu **Publish**.
5. **AI Logic → Get started** → pilih **Gemini Developer API**. Kunci API Gemini dikelola Firebase di server, tidak tersimpan di aplikasi.
6. Buka **Project settings → General**, catat:
   - Web API Key → `FIREBASE_API_KEY`
   - Project ID → `FIREBASE_PROJECT_ID`
   - Project number → `FIREBASE_SENDER_ID`
   - App ID aplikasi Android (`1:...:android:...`) → `FIREBASE_APP_ID`
   - Storage bucket (opsional) → `FIREBASE_STORAGE_BUCKET`
7. Di GitHub: **Settings → Secrets and variables → Actions → New repository secret**, isi kelima nilai di atas dengan nama persis seperti itu.
8. Tab **Actions → Build APK → Run workflow**. Pasang APK baru dari **Releases**.

Opsional: model Gemini bisa diganti tanpa ubah kode lewat **Variables** bernama `GEMINI_MODEL`. Disarankan juga mengaktifkan **App Check** di Firebase sebelum aplikasi dipakai banyak orang, agar kuota AI tidak disalahgunakan.

## 3. Isi aplikasi

| Menu | Fungsi |
|---|---|
| Beranda | Penghasilan bersih hari ini (kotor − pengeluaran), progres target, sesi kerja, kondisi diri, aksi cepat, rekomendasi harian |
| Peta Peluang | Peta OpenStreetMap dengan zona **Data Simulasi** berlabel jelas; jarak, waktu, dan biaya BBM menuju zona |
| Keuangan | Catat/ubah/hapus penghasilan & pengeluaran, rekap harian/7 hari/bulanan, bersih per jam, biaya per km, grafik |
| AI Coach | Tempel chat pelanggan → ringkasan, maksud, perkiraan emosi, kutipan pendukung, saran, balasan (salin/edit/ulang) |
| Profil | Data pengemudi & motor, harga BBM lokal, akun, status integrasi |
| Smart Fuel | Hitung liter dari Rupiah, km/liter metode tangki penuh → tangki penuh, biaya per km, jarak tersisa |
| Perawatan | Riwayat servis, pengingat berdasarkan hari/km yang bisa diatur |
| Keselamatan | Interval pengingat istirahat, laporan kondisi (segar/lelah/mengantuk), riwayat sesi |

Semua angka (keuangan, BBM) dihitung dengan rumus yang diuji di `test/calc_test.dart`, bukan ditebak AI.

## 4. Keterbatasan versi ini (disengaja & dinyatakan di aplikasi)

- Peta Peluang memakai **data simulasi**; pola historis belum tersedia karena belum ada data permintaan nyata.
- Pengingat istirahat muncul di dalam aplikasi saat terbuka; notifikasi saat aplikasi tertutup belum ada.
- Tidak ada deteksi kantuk otomatis dan tidak ada deteksi kerusakan motor otomatis.
- Aplikasi tidak membaca WhatsApp/chat dan tidak mengirim pesan otomatis.
- APK ditandatangani dengan kunci debug (cukup untuk dipasang langsung). Untuk Play Store perlu kunci rilis sendiri.

## 5. Untuk developer

```bash
flutter create --platforms=android --org id.aidriver --project-name ai_driver_companion .
bash tool/patch_android.sh
flutter pub get
flutter test
flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

Struktur: `lib/logic` (perhitungan murni), `lib/data` (penyimpanan lokal/Firestore), `lib/state` (status aplikasi), `lib/ai` (AI Coach), `lib/screens` & `lib/ui` (tampilan).
