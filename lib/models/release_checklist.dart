
class ReleaseChecklistSection {
  const ReleaseChecklistSection({required this.title, required this.items});
  final String title;
  final List<String> items;
}

const releaseCandidateChecklist = [
  ReleaseChecklistSection(title: 'Audio', items: ['Mic HP', 'USB Audio Interface', 'Mixer', 'Audio clipping aman']),
  ReleaseChecklistSection(title: 'Jaringan', items: ['WiFi', 'Mobile Data', 'Pindah jaringan', 'Internet mati 3 detik', 'Internet mati 10 detik']),
  ReleaseChecklistSection(title: 'Background', items: ['Screen off', 'Minimize app', 'Battery saver', 'Foreground service tetap hidup']),
  ReleaseChecklistSection(title: 'Siaran Panjang', items: ['1 jam', '2 jam', '4 jam']),
  ReleaseChecklistSection(title: 'Stress Test', items: ['Reconnect berulang', 'Upload sambil siaran', 'Recording sambil siaran', 'Metadata update saat live']),
  ReleaseChecklistSection(title: 'SOP Sebelum Kajian', items: ['Tes Koneksi', 'Tes Rekam', 'Isi Metadata', 'Mulai Siaran', 'Cek Status LIVE']),
  ReleaseChecklistSection(title: 'SOP Sesudah Kajian', items: ['Stop Siaran', 'Cek Rekaman', 'Upload Rekaman', 'Cek Log']),
];
