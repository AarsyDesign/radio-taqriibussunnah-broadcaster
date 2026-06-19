# Command Log Summary

Ringkasan instruksi yang diberikan, pekerjaan yang dilakukan, dan hasil verifikasi project Radio Taqriibussunnah Broadcaster.

## Tahap 1: UI Dummy

Instruksi:

- Buat UI Flutter Android internal bernama Radio Taqriibussunnah Broadcaster.
- Buat 3 halaman: Setup, Live, Log.
- Gunakan tema hijau tua, krem, putih hangat, minimalis.
- Gunakan Provider atau Riverpod.
- Belum perlu backend, streaming asli, atau native Kotlin.

Hasil:

- UI dibuat ulang dengan struktur folder rapi.
- Provider digunakan untuk state dummy.
- SetupPage, LivePage, dan LogPage dibuat.
- Bottom navigation 3 menu dibuat.
- Status dummy dan monitoring dummy dibuat.

Verifikasi:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Tahap 2: Storage, Permission, Network, Log Lokal

Instruksi:

- Tambahkan konfigurasi permanen.
- Simpan password DJ dengan `flutter_secure_storage`.
- Tambahkan `shared_preferences`, `permission_handler`, dan `connectivity_plus`.
- Tambahkan model `BroadcasterConfig` dan `BroadcastLog`.
- Tambahkan service config storage, microphone permission, network info, connection test dummy, dan log storage.
- Log dummy disimpan lokal sebagai JSON list.

Hasil:

- Config operator disimpan ke `SharedPreferences`.
- Password DJ disimpan ke `FlutterSecureStorage`.
- Permission microphone dicek sebelum mulai siaran.
- Jenis jaringan dibaca memakai `connectivity_plus`.
- Log dummy tersimpan lokal dan bisa dihapus dari LogPage.
- Provider diupdate untuk load config/log saat startup.

Verifikasi:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Got dependencies!
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Tahap 3: Native Android Foreground Service Dummy

Instruksi:

- Buat Platform Channel Flutter <-> Kotlin.
- Buat MethodChannel:
  - `startBroadcastService()`
  - `stopBroadcastService()`
  - `getServiceStatus()`
- Buat EventChannel untuk status native:
  - `offline`
  - `connecting`
  - `live`
  - `reconnecting`
  - `connectionDropped`
  - `stopped`
- Buat `BroadcastService` foreground service dummy.
- Tampilkan notifikasi "Kajian live sedang berjalan".
- Flutter memanggil service saat Mulai Siaran dan menghentikan saat Stop Siaran.
- Jangan buat audio capture, encoder, atau koneksi Icecast/AzuraCast.

Hasil:

- `MainActivity.kt` mengatur MethodChannel dan EventChannel.
- `BroadcastService.kt` dibuat sebagai Foreground Service dummy.
- Flutter service wrapper dibuat di `lib/services/native_broadcast_service.dart`.
- `BroadcasterProvider` mencoba native service lebih dulu, lalu fallback ke dummy mode jika native belum tersedia.
- AndroidManifest diupdate dengan permission dan deklarasi service.
- README diupdate agar status Tahap 3 tercatat selesai.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

Catatan:

- Build Android sempat menampilkan warning Kotlin Gradle Plugin dari template project Flutter.
- Warning tersebut tidak menggagalkan build.
- Belum ada audio capture, encoder, atau koneksi server.

## Tahap 4: Audio Capture

Instruksi:

- Lanjutkan ke tahap audio capture.
- Tangkap input microphone menggunakan `AudioRecord`.
- Baca level audio real.
- Kirim audio level dari Kotlin ke Flutter.
- Jangan buat encoder.
- Jangan konek ke Icecast/AzuraCast.
- Belum streaming ke server.

Hasil:

- `BroadcastService.kt` sekarang menjalankan `AudioRecord` saat service dimulai.
- Audio capture berjalan di thread terpisah.
- Level audio dihitung dari RMS PCM 16-bit mono.
- Level audio dikirim ke Flutter sebagai nilai `0.0` sampai `1.0`.
- `MainActivity.kt` menambahkan EventChannel khusus audio level.
- `NativeBroadcastService` di Flutter menambahkan `audioLevelStream`.
- `BroadcasterProvider` memakai audio level native saat service berjalan.
- Fallback dummy audio level tetap tersedia jika native channel belum tersedia.
- Encoder dan koneksi server belum dibuat.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Tahap 5: Encoder

Instruksi:

- Lanjutkan ke tahap encoder.
- Encode audio ke format yang cocok untuk Icecast/AzuraCast.
- Gunakan bitrate 64/96/128 kbps dari konfigurasi Flutter.
- Jaga buffer agar stabil.
- Jangan konek ke Icecast/AzuraCast dulu.
- Jangan streaming ke server dulu.

Hasil:

- `AudioEncoder.kt` ditambahkan.
- Encoder memakai `MediaCodec` AAC-LC.
- PCM 16-bit mono dari `AudioRecord` masuk ke encoder.
- Bitrate dikirim dari Flutter melalui MethodChannel saat `startBroadcastService()`.
- `BroadcastService.kt` menjalankan encoder bersamaan dengan audio capture.
- Output encoded dihitung secara lokal dan belum dikirim ke server.
- UI dan fallback dummy tetap berjalan seperti sebelumnya.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Tahap 6: Icecast/AzuraCast Connection

Instruksi:

- Lanjutkan ke tahap koneksi Icecast/AzuraCast.
- Gunakan server yang diberikan:
  - listener URL: `https://radio.mahadtaqriibussunnah.my.id/listen/radio/radio.mp3`
  - port: `8005`
  - IP: `151.245.85.182`
- Konek ke host, port, mount point, username, dan password DJ.
- Handle authentication failed.
- Handle server unreachable.
- Handle reconnect.

Hasil:

- Default config awal di Flutter disetel ke:
  - host `151.245.85.182`
  - port `8005`
  - mount point `/listen/radio/radio.mp3`
- `IcecastClient.kt` ditambahkan.
- Native client membuat koneksi TCP ke Icecast/AzuraCast.
- Client mengirim header `SOURCE` dengan Basic Auth.
- Encoder AAC-LC sekarang menghasilkan frame ADTS.
- Output encoder dikirim ke `IcecastClient`.
- Status native mengirim:
  - `connecting`
  - `live`
  - `authenticationFailed`
  - `serverUnreachable`
  - `connectionDropped`
  - `reconnecting`
  - `stopped`
- Permission `INTERNET` ditambahkan ke AndroidManifest.
- Monitoring upload real, reconnect count real, dan log native real belum dibuat.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## File Utama yang Ditambahkan atau Diubah

Flutter:

```text
lib/models/broadcaster_config.dart
lib/models/broadcast_log.dart
lib/models/connection_status.dart
lib/providers/broadcaster_provider.dart
lib/services/broadcast_log_storage_service.dart
lib/services/config_storage_service.dart
lib/services/connection_test_service.dart
lib/services/microphone_permission_service.dart
lib/services/native_broadcast_service.dart
lib/services/network_info_service.dart
lib/pages/setup_page.dart
lib/pages/live_page.dart
lib/pages/log_page.dart
```

Android:

```text
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/radiotaqriibussunnah/broadcaster/MainActivity.kt
android/app/src/main/kotlin/com/radiotaqriibussunnah/broadcaster/BroadcastService.kt
android/app/src/main/kotlin/com/radiotaqriibussunnah/broadcaster/AudioEncoder.kt
android/app/src/main/kotlin/com/radiotaqriibussunnah/broadcaster/IcecastClient.kt
```

Dokumentasi:

```text
README.md
COMMAND_LOG.md
```

## Tahap 7: Monitoring Real

Instruksi:

- Lanjutkan pekerjaan aplikasi dari tahap terakhir.
- Rencana berikutnya pada README adalah monitoring real:
  - data upload real memakai `TrafficStats`
  - kecepatan upload real
  - reconnect count real
  - log real dari service

Hasil:

- `BroadcastService.kt` sekarang mengirim stats native lewat EventChannel:
  - total upload bytes
  - kecepatan upload kbps
  - rata-rata upload kbps
  - jumlah reconnect
- Stats upload memakai `TrafficStats.getUidTxBytes()` dengan fallback hitungan byte frame AAC yang benar-benar ditulis ke socket.
- `IcecastClient.kt` menambahkan callback byte terkirim setelah frame AAC berhasil di-write dan flush ke socket.
- Reconnect count bertambah saat native masuk status `reconnecting`.
- Log native dikirim lewat EventChannel untuk status koneksi penting seperti connecting, live, reconnecting, auth gagal, server unreachable, dan connection dropped.
- `MainActivity.kt` mendaftarkan EventChannel stats dan log yang sebelumnya sudah disiapkan di Flutter.
- Provider Flutter memakai `connectionDropped` sebagai status sementara, sehingga log sesi tidak tersimpan prematur saat service masih mencoba reconnect.
- Tombol utama tetap menampilkan Stop Siaran saat status `connectionDropped`, sehingga operator tetap bisa menghentikan service.
- README diupdate agar status monitoring real tercatat selesai.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```
