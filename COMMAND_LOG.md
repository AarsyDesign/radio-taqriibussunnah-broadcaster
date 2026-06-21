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
Formatted 20 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Final Stabilization

Instruksi:

- Stabilkan aplikasi agar siap dipakai live ke AzuraCast/SHOUTcast.
- Tambahkan bitrate 32 kbps.
- Ganti test connection dummy menjadi native real handshake.
- Jangan tampilkan live sebelum server menerima handshake.
- Batasi reconnect otomatis dan hindari reconnect tanpa batas untuk error final.

Hasil:

- Default bitrate diubah ke 64 kbps.
- SetupPage menampilkan bitrate 32/64/96/128 kbps, dengan label hemat data dan rekomendasi.
- Validasi konfigurasi diperketat untuk host, port, password, bitrate, input audio, mount source Icecast, dan listener URL.
- Provider Flutter dipulihkan agar memakai `BroadcastLogStorageService` normal dan status test native.
- `NativeBroadcastService` menambahkan method `testBroadcastConnection(config)`.
- `MainActivity.kt` menambahkan MethodChannel `testBroadcastConnection`.
- `IcecastClient.kt` diganti utuh dengan handshake real:
  - Icecast/AzuraCast memakai `SOURCE mount ICE/1.0` dan Basic Auth.
  - SHOUTcast v1 memakai source password dan metadata `icy-*`.
  - Test connection hanya menjalankan handshake, tanpa mengirim audio.
- `BroadcastService.kt` diganti utuh untuk menghapus placeholder, memulai audio capture setelah handshake sukses, menjaga rekaman WAV lokal, mengirim stats real, dan menghentikan service bersih pada status final.
- Reconnect otomatis dibatasi 5 kali dengan delay bertahap 2/5/10/20/30 detik.
- Status tambahan sudah dipetakan: timeout, invalidConfig, protocolRejected, unsupportedCodec, unknownError.

Verifikasi wajib:

```powershell
dart.bat format lib test
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 20 files
Got dependencies!
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Dukungan SHOUTcast

Instruksi:

- Server stream berubah dari Icecast ke SHOUTcast.
- Aplikasi reconnect terus dan belum bisa digunakan.
- Pastikan konfigurasi yang disimpan dipahami sebagai lokal atau global.

Hasil:

- `BroadcasterConfig` menambahkan `serverType` dengan pilihan `SHOUTcast` dan `Icecast/AzuraCast`.
- Default tipe server diubah ke `SHOUTcast`.
- SetupPage menambahkan dropdown tipe server.
- Untuk SHOUTcast, field username dan mount point tidak wajib.
- `ConfigStorageService` menyimpan tipe server per perangkat.
- `NativeBroadcastService` mengirim tipe server ke native Android.
- Native Android membaca `serverType` dan memilih handshake:
  - SHOUTcast: kirim source password, tunggu respons `OK`, lalu kirim metadata `icy-*`
  - Icecast/AzuraCast: tetap memakai `SOURCE mount ICE/1.0` dan Basic Auth
- README menjelaskan bahwa tombol Simpan menyimpan konfigurasi lokal per HP operator, bukan sinkron otomatis ke semua pengguna.

Catatan:

- Implementasi SHOUTcast saat ini menargetkan source protocol SHOUTcast v1.
- Audio yang dikirim masih AAC-LC ADTS. Jika server SHOUTcast hanya menerima MP3, streaming tetap perlu encoder MP3 atau konfigurasi server yang menerima AAC.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 20 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Fitur Rekam Audio Lokal

Instruksi:

- Tambahkan fitur rekam audio.
- Rekaman harus bisa berjalan bersamaan dengan broadcast.
- Sumber rekaman harus suara yang masuk ke HP, bukan audio dari jaringan.

Hasil:

- `AudioRecorder.kt` ditambahkan untuk membuat file WAV lokal dari PCM `AudioRecord`.
- `BroadcastService.kt` memulai rekaman saat service broadcast mulai dan menghentikan rekaman saat service berhenti.
- Rekaman ditulis dari buffer microphone/USB input sebelum audio masuk encoder dan sebelum dikirim ke Icecast/AzuraCast.
- File rekaman disimpan di folder app external files `Music/recordings` dengan nama `radio-taqriibussunnah-YYYYMMDD-HHMMSS.wav`.
- Stats native mengirim path file rekaman dan ukuran rekaman ke Flutter.
- Monitoring Live menampilkan ukuran dan nama file rekaman.
- Log siaran menyimpan ukuran dan nama file rekaman.

Verifikasi:

```powershell
dart.bat format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 20 files
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
Formatted 20 files
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
Formatted 20 files
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
Formatted 20 files
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
Formatted 20 files
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Patch build-info-01

Instruksi:

- Caveman mode, perubahan sekecil mungkin.
- Jangan ubah broadcast connection, audio engine, atau metadata flow.
- Tambahkan informasi build yang terlihat di aplikasi.
- Tambahkan model, service, changelog, tombol salin info build, dan version `0.8.4+24`.

Hasil:

- `package_info_plus` ditambahkan untuk membaca app name, package name, version, dan build number.
- `BuildInfoModel` ditambahkan sebagai immutable model dengan `copyWith()` dan `toString()`.
- `BuildInfoService` membaca `PackageInfo` dan dart-define:
  - `BUILD_CHANNEL`
  - `PATCH_NAME`
  - `ENVIRONMENT`
  - `BUILD_DATE`
  - `GIT_COMMIT`
- `appChangelog` ditambahkan dengan patch `build-info-01`.
- LogPage tab Riwayat menampilkan card `Informasi Build` di bawah log.
- Tombol `Salin Info Build` menyalin identitas APK ke clipboard.
- Changelog terbaru tampil maksimal 5 catatan.
- `pubspec.yaml` diupdate ke `version: 0.8.4+24`.

Verifikasi:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=BUILD_CHANNEL=debug --dart-define=PATCH_NAME=build-info-01 --dart-define=ENVIRONMENT=internal-test --dart-define=BUILD_DATE=2026-06-19 --dart-define=GIT_COMMIT=local
```

Output penting:

```text
Got dependencies!
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Step 2: Live Reconnect Protection

Instruksi:

- Jangan ubah handshake koneksi yang sudah berhasil.
- Tambahkan perlindungan saat jaringan HP putus sebentar.
- Foreground service, AudioRecord, encoder, dan rekaman lokal harus tetap berjalan saat reconnect.
- Tambahkan status `networkLost`, `reconnecting`, `liveRestored`, dan `reconnectFailed`.
- Reconnect hanya untuk gangguan sementara, bukan authentication/config/protocol/codec error.
- Gunakan reconnect policy maksimal 10 attempt dengan delay 500 ms, 1 detik, 2 detik, 3 detik, 5 detik, 10 detik, 15 detik, 20 detik, 30 detik, 30 detik.
- Tambahkan Network Watchdog, Socket Watchdog, buffer output kecil, dan warning README tentang batasan AutoDJ.

Hasil:

- Flutter mengenali status baru `networkLost`, `liveRestored`, dan `reconnectFailed`.
- Tombol utama tetap `Stop Siaran` saat network lost/reconnecting/live restored.
- Monitoring internet menampilkan attempt reconnect aktif dan delay berikutnya.
- Native `BroadcastService` menambahkan Network Watchdog berbasis `ConnectivityManager.NetworkCallback` pada Android N ke atas, dengan fallback deteksi socket write failure.
- Saat jaringan hilang, status menjadi `networkLost` dan socket lama ditutup aman agar client masuk reconnect tanpa menghentikan audio capture, encoder, atau rekaman lokal.
- `IcecastClient` memakai reconnect policy 10 attempt sesuai delay instruksi.
- Handshake SHOUTcast dan Icecast/AzuraCast tetap memakai jalur lama yang sudah berhasil.
- Buffer frame AAC dibatasi sekitar beberapa detik; saat penuh frame lama dibuang dan log `Output buffer penuh, frame lama dibuang.` dikirim.
- Saat reconnect berhasil, handshake mengirim ulang metadata terakhir dan status menjadi `liveRestored`.
- `reconnectCount` bertambah saat reconnect berhasil, sedangkan attempt aktif dikirim sebagai telemetry terpisah.
- Jika reconnect gagal setelah batas attempt, status menjadi `reconnectFailed` dan service berhenti aman dengan log sesi tersimpan.
- README menambahkan warning bahwa aplikasi tidak bisa sepenuhnya mencegah AutoDJ masuk jika server sudah melihat source live disconnect, serta menyarankan grace/delay fallback AutoDJ atau relay VPS.

Verifikasi wajib:

```powershell
dart.bat format lib test
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
Got dependencies!
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Step 3: Audio Diagnostic + Test Recording 15 Detik

Instruksi:

- Fokus hanya diagnosa audio.
- Jangan ubah handshake koneksi yang sudah berhasil.
- Tambahkan Tes Rekam 15 Detik sebelum live.
- Tampilkan hasil test recording: nama file, path file, ukuran file, durasi, tombol Putar, dan tombol Hapus.
- Tambahkan status volume berdasarkan PCM input: terlalu kecil, aman, terlalu keras.
- Deteksi clipping jika sample PCM sering mendekati batas maksimum.
- Tambahkan log `[AUDIO INPUT]`, `[AUDIO LEVEL]`, dan `[TEST RECORDING]`.

Hasil:

- LivePage menambahkan section `Kualitas Audio`.
- Tombol `Tes Rekam 15 Detik` meminta izin microphone, lalu memanggil native recorder.
- Native membuat file WAV test di folder app external files `Music/test-recordings`.
- Hasil test recording menampilkan nama file, path, ukuran, durasi, tombol Putar, dan tombol Hapus.
- Tombol Putar memakai native `MediaPlayer`.
- Tombol Hapus menghapus file WAV test dari storage aplikasi.
- Native menambahkan EventChannel audio diagnostic berisi RMS, peak, clipping, dan volume status.
- Provider Flutter menampilkan status volume `Terlalu kecil`, `Aman`, atau `Terlalu keras` beserta pesan operator.
- Broadcast live juga mengirim diagnostic audio yang sama, tanpa mengubah handshake server.
- Log native menambahkan:
  - `[AUDIO INPUT] source=... sampleRate=44100 channel=mono pcmFormat=16bit`
  - `[AUDIO LEVEL] rms=... peak=... clipping=... volumeStatus=...`
  - `[TEST RECORDING] file=... size=... duration=...`

Verifikasi wajib:

```powershell
dart.bat format lib test
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Output penting:

```text
Formatted 21 files
Got dependencies!
No issues found!
All tests passed!
Built build\app\outputs\flutter-apk\app-debug.apk
```

## Step 4: Audio Quality Control + Filter Suara

Instruksi:

- Jangan ubah koneksi, metadata, atau desain besar-besaran.
- Tambahkan UI Kualitas Audio: preset, input gain, noise suppression, high-pass filter, limiter, dan audio source mode.
- Simpan setting audio ke `SharedPreferences`.
- Native menerima setting audio aktif.
- Broadcast dan test recording memakai setting audio aktif.
- Cek availability NoiseSuppressor, AGC, dan AEC, tanpa crash jika tidak tersedia.

Hasil:

- `BroadcasterConfig` menambahkan setting audio dengan default Standar Kajian / 64 kbps.
- `ConfigStorageService` menyimpan `audioPreset`, `inputGainDb`, `noiseSuppressionLevel`, `highPassFilterHz`, `limiterEnabled`, dan `audioSourceMode`.
- SetupPage menambahkan section `Kualitas Audio` tanpa mengubah alur koneksi.
- Preset audio mengatur bitrate dan pilihan processing awal:
  - Hemat Data: 32 kbps, Low, 80 Hz, limiter On
  - Standar Kajian: 64 kbps, Low, 80 Hz, limiter On
  - Jernih: 96 kbps, Low, 80 Hz, limiter On
  - Maksimal: 128 kbps, Off, 80 Hz, limiter On
- Native menerima setting audio lewat MethodChannel start broadcast dan test recording.
- `AudioProcessing.kt` ditambahkan untuk high-pass filter ringan, input gain, dan soft limiter sebelum recorder/encoder.
- Broadcast live dan test recording memakai PCM hasil processing yang sama.
- NoiseSuppressor Android diaktifkan hanya jika tersedia dan level bukan Off.
- AGC dan AEC hanya dicek availability dan dilog; tidak aktif default.
- Handshake Icecast/SHOUTcast dan metadata tidak diubah.

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

## PATCH 2 — admin-content-01

Tanggal: 2026-06-20

Perubahan:

- Menambahkan model `AdminContent` untuk Informasi Radio, Pengumuman, Live Notice, Jadwal Kajian, Ustadz, Dauroh, dan Maintenance.
- Menambahkan `AdminContentStorageService` untuk penyimpanan konten via `SharedPreferences`.
- Menambahkan Admin PIN 6 digit via `FlutterSecureStorage`.
- Mengintegrasikan state admin content ke `BroadcasterProvider`.
- Menambahkan halaman `AdminContentPage` sebagai CMS internal lokal.
- Menambahkan tab Admin pada bottom navigation.
- Menaikkan versi aplikasi ke `0.9.0+30`.

Verifikasi:

```powershell
dart format lib
flutter analyze
```

Catatan:

- Backend tahap awal masih lokal.
- Backend tahap berikutnya disiapkan untuk Supabase + REST API.

## PATCH 3 — reconnect-fix-01

Tanggal: 2026-06-20

Perubahan:

- Menguatkan socket watchdog di `IcecastClient.kt`.
- Menambahkan klasifikasi log untuk Timeout, Broken Pipe, Connection Reset, Network Lost, dan Write Failure.
- `forceReconnect()` mengirim status `networkLost` ketika alasan watchdog menunjukkan network/offline.
- Reconnect delay dipastikan mengikuti roadmap 10 attempt: 500ms, 1s, 2s, 3s, 5s, 10s, 15s, 20s, 30s, 30s.
- Buffer encoded frame tetap bounded agar reconnect tidak membuat memori membesar.
- Menaikkan versi aplikasi ke `0.9.1+31`.

Verifikasi lokal:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Catatan:

- Sandbox ini tidak menyediakan `flutter`/`dart`, sehingga verifikasi Flutter perlu dijalankan di mesin development.
## PATCH 4 — recording-upload-01

Tanggal: 2026-06-21

Perubahan:

- Mengubah folder rekaman utama Android menjadi `Music/RadioTaqriibussunnah/Recordings`.
- Mengubah folder test recording menjadi `Music/RadioTaqriibussunnah/TestRecordings`.
- Menambahkan model `RecordingUpload` dan status upload pending/uploading/uploaded/failed.
- Menambahkan `RecordingUploadService` untuk queue upload lokal via `SharedPreferences`.
- Broadcast log dengan file rekaman otomatis masuk queue upload lokal.
- Menaikkan versi aplikasi ke `0.9.2+32`.

Catatan:

- Upload server masih placeholder karena credential/backend Supabase belum dikonfigurasi.
- Verifikasi Flutter perlu dijalankan di mesin development karena sandbox tidak memiliki Flutter/Dart CLI.
