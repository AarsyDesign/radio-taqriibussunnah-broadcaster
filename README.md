# Radio Taqriibussunnah Broadcaster

Aplikasi Android internal untuk operator Radio Taqriibussunnah. Tahap saat ini fokus pada UI Flutter, konfigurasi permanen, permission microphone, network info, log lokal, native Android Foreground Service, audio capture microphone, encoder AAC-LC, dan koneksi dasar Icecast/AzuraCast.

## Status Saat Ini

- UI Flutter sudah dibuat ulang.
- State dummy menggunakan `provider`.
- Konfigurasi operator disimpan permanen.
- Password DJ disimpan aman menggunakan `flutter_secure_storage`.
- Log siaran dummy disimpan lokal sebagai JSON di `SharedPreferences`.
- Permission microphone sudah dicek sebelum mulai siaran dummy.
- Jenis jaringan dibaca dengan `connectivity_plus`.
- Platform Channel Flutter <-> Kotlin sudah tersedia.
- Native Android Foreground Service dummy sudah tersedia.
- Notifikasi foreground menampilkan "Kajian live sedang berjalan".
- Status dummy dari native diterima Flutter melalui EventChannel.
- Native `AudioRecord` sudah menangkap input microphone.
- Audio level real dikirim dari Kotlin ke Flutter melalui EventChannel.
- Native encoder AAC-LC berbasis `MediaCodec` sudah tersedia.
- Bitrate encoder mengikuti pilihan Setup: 64/96/128 kbps.
- Native TCP client Icecast/AzuraCast sudah tersedia.
- Output AAC encoder sudah dikirim ke server melalui socket.
- Handling dasar tersedia untuk authentication failed, server unreachable, reconnecting, dan connection dropped.
- Monitoring upload/reconnect/log real sudah tersambung dari native Android.

## Package Utama

- `provider`
- `shared_preferences`
- `flutter_secure_storage`
- `permission_handler`
- `connectivity_plus`

## Fitur UI

- Tema hijau tua, krem, dan putih hangat.
- Tampilan minimalis untuk kebutuhan pondok/pesantren.
- Tombol besar agar mudah dipakai operator.
- Bottom navigation dengan 3 halaman:
  - Setup
  - Live
  - Log

## Halaman Setup

- Input host/server.
- Input port.
- Input mount point.
- Input username DJ.
- Input password DJ.
- Dropdown bitrate:
  - 64 kbps
  - 96 kbps
  - 128 kbps
- Dropdown input audio:
  - Mic HP
  - USB Audio Interface
- Tombol Tes Koneksi.
- Tombol Simpan untuk menyimpan konfigurasi permanen.
- Hasil test connection dummy:
  - success
  - authentication failed
  - server unreachable
- Validasi form:
  - host wajib diisi
  - port wajib angka
  - mount point wajib diisi
  - username wajib diisi
  - password wajib diisi

Catatan dummy test:
- Host berisi `down` atau `offline` menghasilkan `server unreachable`.
- Username berisi `fail` atau password `salah` menghasilkan `authentication failed`.
- Selain itu menghasilkan `success`.

Default server awal:

- host/IP: `151.245.85.182`
- port: `8005`
- mount point: `/listen/radio/radio.mp3`
- listener URL: `https://radio.mahadtaqriibussunnah.my.id/listen/radio/radio.mp3`

## Halaman Live

- Kartu status besar:
  - offline
  - connecting
  - live
  - reconnecting
  - authenticationFailed
  - serverUnreachable
  - microphoneDenied
  - connectionDropped
  - stopped
- Timer durasi siaran.
- Audio level meter dummy.
- Saat native service berjalan, audio level meter memakai level microphone real dari `AudioRecord`.
- Monitoring internet:
  - upload keluar
  - kecepatan upload
  - rata-rata upload
  - estimasi data per jam
  - jenis jaringan
  - jumlah reconnect
- Tombol besar Mulai Siaran.
- Saat live, tombol berubah menjadi Stop Siaran.
- Saat stop ditekan, muncul dialog konfirmasi.
- Sebelum mulai siaran, aplikasi memastikan konfigurasi sudah lengkap.
- Sebelum live dummy, aplikasi meminta permission microphone.
- Jika aman, Flutter memanggil native `startBroadcastService()`.
- Saat stop dikonfirmasi, Flutter memanggil native `stopBroadcastService()`.
- Jika permission microphone ditolak, status menjadi `microphoneDenied`.
- Jenis jaringan tampil dari `connectivity_plus`: WiFi, Mobile Data, Offline, atau Unknown.
- Ada pilihan Status Dummy untuk mencoba semua state UI.

## Halaman Log

List riwayat dummy dibaca dari storage lokal dan berisi:

- waktu live mulai
- waktu stop
- durasi
- total upload
- jumlah reconnect
- status akhir
- tombol hapus log

## Struktur Folder

```text
lib/
  main.dart
  app.dart
  theme/
    app_theme.dart
  models/
    broadcaster_config.dart
    broadcast_log.dart
    connection_status.dart
  providers/
    broadcaster_provider.dart
  services/
    broadcast_log_storage_service.dart
    config_storage_service.dart
    connection_test_service.dart
    microphone_permission_service.dart
    native_broadcast_service.dart
    network_info_service.dart
  pages/
    setup_page.dart
    live_page.dart
    log_page.dart
  widgets/
    status_card.dart
    audio_level_meter.dart
    internet_monitor_card.dart
    primary_live_button.dart
```

```text
android/app/src/main/kotlin/com/radiotaqriibussunnah/broadcaster/
  MainActivity.kt
  BroadcastService.kt
  AudioEncoder.kt
  IcecastClient.kt
```

## State

State aplikasi memakai `Provider` melalui `BroadcasterProvider`.

Enum status koneksi ada di:

```text
lib/models/connection_status.dart
```

Model konfigurasi ada di:

```text
lib/models/broadcaster_config.dart
```

Model log ada di:

```text
lib/models/broadcast_log.dart
```

## Storage

- `SharedPreferences` menyimpan:
  - host
  - port
  - mount point
  - username
  - bitrate
  - input audio
  - log dummy lokal sebagai JSON list
- `FlutterSecureStorage` menyimpan:
  - password DJ

Password DJ tidak disimpan di `SharedPreferences`.

## Native Android

Tahap native saat ini sudah memiliki service, audio capture, encoder, dan koneksi dasar Icecast/AzuraCast.

MethodChannel:

- `startBroadcastService()`
- `stopBroadcastService()`
- `getServiceStatus()`

EventChannel mengirim status:

- `offline`
- `connecting`
- `live`
- `reconnecting`
- `authenticationFailed`
- `serverUnreachable`
- `connectionDropped`
- `stopped`

EventChannel audio level mengirim nilai:

- `0.0` sampai `1.0`
- sumber data dari `AudioRecord`

`BroadcastService` melakukan:

- berjalan sebagai Foreground Service
- menampilkan notifikasi "Kajian live sedang berjalan"
- mengirim status dummy `connecting` lalu `live`
- menangkap input microphone dengan `AudioRecord`
- menghitung level audio real
- encode audio PCM ke AAC-LC menggunakan `MediaCodec`
- memakai bitrate 64/96/128 kbps dari konfigurasi Flutter
- konek ke Icecast/AzuraCast lewat TCP socket
- mengirim AAC ADTS frame ke server
- menangani authentication failed
- menangani server unreachable
- melakukan reconnect dasar saat koneksi putus
- mengirim level audio ke Flutter
- mengirim total upload, kecepatan upload, rata-rata upload, dan jumlah reconnect ke Flutter
- mengirim pesan log native ke Flutter
- mengirim `stopped` saat service dihentikan

`BroadcastService` belum melakukan:

- uji stabilitas panjang di perangkat Android produksi

```dart
enum ConnectionStatus {
  offline,
  connecting,
  live,
  reconnecting,
  authenticationFailed,
  serverUnreachable,
  microphoneDenied,
  connectionDropped,
  stopped,
}
```

## Build dan Test

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Output APK debug:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Verifikasi Terakhir

Perubahan terakhir sudah dicek dengan:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Hasilnya sukses.

## Log Pengerjaan

Ringkasan instruksi, pekerjaan yang dilakukan, command verifikasi, dan output penting dicatat di:

```text
COMMAND_LOG.md
```

## Rencana Berikutnya

Tahap 3 sampai Tahap 7 sudah selesai. Setelah koneksi Icecast/AzuraCast stabil di perangkat Android, lanjut ke uji perangkat, hardening reconnect, dan penyesuaian produksi.
