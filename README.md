# Radio Taqriibussunnah Broadcaster

Aplikasi Android internal untuk operator Radio Taqriibussunnah. Tahap saat ini fokus pada UI Flutter, konfigurasi permanen lokal, permission microphone, network info, log lokal, native Android Foreground Service, audio capture microphone, encoder AAC-LC, dan koneksi dasar SHOUTcast serta Icecast/AzuraCast.

## Status Saat Ini

### PATCH 4 — recording-upload-01

- Rekaman siaran utama disimpan lebih mudah ditemukan di `Music/RadioTaqriibussunnah/Recordings`.
- Rekaman test disimpan di `Music/RadioTaqriibussunnah/TestRecordings`.
- Queue upload rekaman tahap awal ditambahkan berbasis `SharedPreferences`.
- Metadata rekaman siap upload: judul, tema, ustadz, tanggal, durasi, ukuran file, path lokal.
- Upload backend masih placeholder siap Supabase Storage/VPS/S3.
- Versi aplikasi dinaikkan ke `0.9.2+32`.


### PATCH 3 — reconnect-fix-01

- Reconnect delay dipastikan sesuai roadmap: 500ms, 1s, 2s, 3s, 5s, 10s, 15s, 20s, 30s, 30s.
- Socket watchdog diperjelas untuk Timeout, Broken Pipe, Connection Reset, Network Lost, dan Write Failure.
- `forceReconnect()` sekarang mengirim status `networkLost` saat watchdog mendeteksi offline/perubahan jaringan.
- Buffer kecil encoded frame tetap aktif agar AudioRecord, encoder, dan recording tidak perlu dimatikan saat reconnect.
- Versi aplikasi dinaikkan ke `0.9.1+31`.


### PATCH 2 — admin-content-01

- Panel Admin Radio/CMS internal ditambahkan sebagai tab Admin.
- Informasi Radio, Pengumuman, Live Notice, Jadwal Kajian, Ustadz, Dauroh, dan Maintenance bisa dikelola dari aplikasi.
- Konten tahap awal disimpan lokal via `SharedPreferences`.
- Admin PIN 6 digit disimpan aman via `FlutterSecureStorage`.
- Tidak ada secret API yang disimpan di APK.
- Versi aplikasi dinaikkan ke `0.9.0+30`.


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
- Native TCP client SHOUTcast dan Icecast/AzuraCast sudah tersedia.
- Output AAC encoder sudah dikirim ke server melalui socket.
- Handling dasar tersedia untuk authentication failed, server unreachable, reconnecting, dan connection dropped.
- Monitoring upload/reconnect/log real sudah tersambung dari native Android.
- Rekaman lokal WAV otomatis tersimpan saat broadcast berjalan.

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
- Pilihan tipe server:
  - SHOUTcast
  - Icecast/AzuraCast
- Input mount point atau stream ID.
- Input username DJ.
- Input password DJ atau source password SHOUTcast.
- Dropdown bitrate:
  - 32 kbps
  - 64 kbps
  - 96 kbps
  - 128 kbps
- Dropdown input audio:
  - Mic HP
  - USB Audio Interface
- Bagian Kualitas Audio:
  - Preset Audio: Hemat Data, Standar Kajian, Jernih, Maksimal
  - Input Gain -12 dB sampai +12 dB
  - Noise Suppression Off/Low/Medium/High
  - High-pass Filter Off/80 Hz/100 Hz
  - Limiter On/Off
  - Audio Source Mode Natural/MIC atau Voice Processing/VOICE_COMMUNICATION
- Tombol Tes Koneksi.
- Tombol Simpan untuk menyimpan konfigurasi permanen.
- Hasil test connection native:
  - success
  - authentication failed
  - server unreachable
  - timeout
  - invalid config
  - protocol rejected
  - unsupported codec
- Validasi form:
  - host wajib diisi
  - port wajib angka
  - mount point wajib diisi untuk Icecast/AzuraCast
  - username wajib diisi untuk Icecast/AzuraCast
  - password wajib diisi

Tes koneksi membuka socket native, menjalankan handshake sesuai tipe server, lalu menutup koneksi tanpa mengirim audio.

Default server awal:

- host/IP: `151.245.85.182`
- port: `8005`
- tipe server: `SHOUTcast`
- listener URL lama: `https://radio.mahadtaqriibussunnah.my.id/listen/radio/radio.mp3`

## Halaman Live

- Kartu status besar:
  - offline
  - connecting
  - live
  - networkLost
  - reconnecting
  - liveRestored
  - reconnectFailed
  - authenticationFailed
  - serverUnreachable
  - microphoneDenied
  - connectionDropped
  - stopped
- Timer durasi siaran.
- Audio level meter dummy.
- Saat native service berjalan, audio level meter memakai level microphone real dari `AudioRecord`.
- Bagian Kualitas Audio menampilkan status volume Terlalu kecil, Aman, atau Terlalu keras.
- Clipping indicator tampil jika sample PCM sering mendekati batas maksimum.
- Tombol Tes Rekam 15 Detik membuat file WAV test sebelum live, lalu menampilkan nama file, path, ukuran, durasi, tombol Putar, dan tombol Hapus.
- Monitoring internet:
  - upload keluar
  - kecepatan upload
  - rata-rata upload
  - estimasi data per jam
  - jenis jaringan
  - jumlah reconnect
  - ukuran dan nama file rekaman lokal
- Tombol besar Mulai Siaran.
- Saat live, tombol berubah menjadi Stop Siaran.
- Saat jaringan putus sementara atau reconnecting, tombol tetap Stop Siaran.
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

Bagian bawah Riwayat menampilkan Informasi Build:

- app name
- version name
- build number
- build channel
- patch name
- environment
- build date
- git commit
- tombol Salin Info Build
- changelog sederhana

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
  - tipe server
  - audio preset
  - input gain
  - noise suppression
  - high-pass filter
  - limiter
  - audio source mode
  - log dummy lokal sebagai JSON list
- `FlutterSecureStorage` menyimpan:
  - password DJ

Password DJ tidak disimpan di `SharedPreferences`.
Konfigurasi yang disimpan bersifat lokal per perangkat operator. Jika aplikasi dipasang di HP lain, perangkat itu perlu konfigurasi sendiri kecuali default config dibundel di aplikasi atau diambil dari backend.

## Native Android

Tahap native saat ini sudah memiliki service, audio capture, encoder, dan koneksi dasar SHOUTcast serta Icecast/AzuraCast.

MethodChannel:

- `startBroadcastService()`
- `stopBroadcastService()`
- `getServiceStatus()`

EventChannel mengirim status:

- `offline`
- `connecting`
- `live`
- `networkLost`
- `reconnecting`
- `liveRestored`
- `reconnectFailed`
- `authenticationFailed`
- `serverUnreachable`
- `connectionDropped`
- `stopped`

EventChannel audio level mengirim nilai:

- `0.0` sampai `1.0`
- sumber data dari `AudioRecord`

EventChannel audio diagnostic mengirim:

- RMS input PCM
- peak input PCM
- clipping true/false
- volume status `small`, `safe`, atau `clipping`

`BroadcastService` melakukan:

- berjalan sebagai Foreground Service
- menampilkan notifikasi "Kajian live sedang berjalan"
- mengirim status dummy `connecting` lalu `live`
- menangkap input microphone dengan `AudioRecord`
- merekam input audio lokal ke file WAV dari buffer `AudioRecord`
- menghitung level audio real
- menghitung diagnostic audio real: RMS, peak, clipping, dan volume status
- membuat test recording WAV 15 detik untuk cek kualitas input sebelum live
- memutar dan menghapus file test recording dari tombol di UI
- menerapkan high-pass filter ringan, input gain, dan limiter sebelum recorder/encoder
- memakai NoiseSuppressor Android jika tersedia dan diaktifkan
- mencatat availability NoiseSuppressor, AGC, dan AEC tanpa mengaktifkan AGC/AEC default
- encode audio PCM ke AAC-LC menggunakan `MediaCodec`
- memakai bitrate 64/96/128 kbps dari konfigurasi Flutter
- konek ke Icecast/AzuraCast lewat TCP socket
- konek ke SHOUTcast v1 lewat source password dan metadata `icy-*`
- mengirim AAC ADTS frame ke server
- menangani authentication failed
- menangani server unreachable
- melakukan reconnect otomatis sampai 10 percobaan saat jaringan/socket putus sementara
- menjaga AudioRecord, encoder, dan rekaman lokal tetap aktif saat reconnecting
- memakai buffer output kecil untuk membantu gangguan jaringan sangat singkat
- mengirim level audio ke Flutter
- mengirim total upload, kecepatan upload, rata-rata upload, dan jumlah reconnect ke Flutter
- mengirim path dan ukuran file rekaman ke Flutter
- mengirim pesan log native ke Flutter
- mengirim `stopped` saat service dihentikan

`BroadcastService` belum melakukan:

- uji stabilitas panjang di perangkat Android produksi

```dart
enum ConnectionStatus {
  offline,
  connecting,
  live,
  networkLost,
  reconnecting,
  liveRestored,
  reconnectFailed,
  authenticationFailed,
  serverUnreachable,
  microphoneDenied,
  connectionDropped,
  stopped,
}
```

## Catatan AutoDJ Saat Jaringan Putus

Jika AutoDJ tetap masuk saat jaringan putus sangat singkat, itu karena server melihat source live benar-benar disconnect.

Aplikasi bisa mempercepat reconnect, tetapi tidak bisa sepenuhnya mencegah AutoDJ masuk jika koneksi source ke server sudah terputus.

Solusi server-side yang lebih kuat:

- atur grace/delay fallback AutoDJ jika tersedia di AzuraCast
- atau gunakan relay di VPS yang selalu terhubung ke AzuraCast dan mengirim silence saat HP broadcaster putus sebentar

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
