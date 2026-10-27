#!/usr/bin/env bash
# Menyesuaikan proyek Android hasil `flutter create` untuk aplikasi ini.
set -euo pipefail

M=android/app/src/main/AndroidManifest.xml

# 1. Izin internet (Firebase, AI, peta) — template rilis tidak menyertakannya.
if ! grep -q 'android.permission.INTERNET' "$M"; then
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$M"
fi

# 2. Nama aplikasi di HP.
perl -pi -e 's#android:label="[^"]*"#android:label="AI Driver Companion"#' "$M"

# 3. Firebase Auth butuh minimal Android 6.0 (API 23).
for G in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$G" ] || continue
  if [[ "$G" == *.kts ]]; then
    perl -pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/' "$G"
  else
    perl -pi -e 's/minSdk(Version)?\s*=?\s*flutter\.minSdkVersion/minSdk = Math.max(flutter.minSdkVersion, 23)/' "$G"
  fi
  grep -n "minSdk" "$G" || true
done

grep -q 'android.permission.INTERNET' "$M" || { echo "Gagal menambah izin INTERNET"; exit 1; }
echo "Patch Android selesai."
