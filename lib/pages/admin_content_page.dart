
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_content.dart';
import '../providers/broadcaster_provider.dart';
import '../theme/app_theme.dart';

class AdminContentPage extends StatelessWidget {
  const AdminContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcasterProvider>();
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!provider.hasAdminPin) return const _PinSetupView();
    if (!provider.isAdminUnlocked) return const _PinUnlockView();
    return const _AdminEditorView();
  }
}

class _PinSetupView extends StatefulWidget {
  const _PinSetupView();
  @override
  State<_PinSetupView> createState() => _PinSetupViewState();
}

class _PinSetupViewState extends State<_PinSetupView> {
  final _pin = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) => _AdminShell(
    title: 'Admin Radio',
    subtitle: 'Buat PIN admin 6 digit untuk membuka CMS internal.',
    child: Column(
      children: [
        _TextInput(controller: _pin, label: 'PIN Admin 6 Digit', keyboardType: TextInputType.number, obscureText: true),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            if (!RegExp(r'^\d{6}$').hasMatch(_pin.text)) {
              setState(() => _error = 'PIN harus 6 digit angka.');
              return;
            }
            await context.read<BroadcasterProvider>().setAdminPin(_pin.text);
          },
          icon: const Icon(Icons.lock_rounded),
          label: const Text('Simpan PIN'),
        ),
      ],
    ),
  );
}

class _PinUnlockView extends StatefulWidget {
  const _PinUnlockView();
  @override
  State<_PinUnlockView> createState() => _PinUnlockViewState();
}

class _PinUnlockViewState extends State<_PinUnlockView> {
  final _pin = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) => _AdminShell(
    title: 'Admin Radio',
    subtitle: 'Masukkan PIN admin untuk mengubah konten radio.',
    child: Column(
      children: [
        _TextInput(controller: _pin, label: 'PIN Admin', keyboardType: TextInputType.number, obscureText: true),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final ok = await context.read<BroadcasterProvider>().unlockAdmin(_pin.text);
            if (!ok) setState(() => _error = 'PIN salah.');
          },
          icon: const Icon(Icons.login_rounded),
          label: const Text('Buka Admin'),
        ),
      ],
    ),
  );
}

class _AdminEditorView extends StatefulWidget {
  const _AdminEditorView();
  @override
  State<_AdminEditorView> createState() => _AdminEditorViewState();
}

class _AdminEditorViewState extends State<_AdminEditorView> {
  final _radioName = TextEditingController();
  final _tagline = TextEditingController();
  final _website = TextEditingController();
  final _telegram = TextEditingController();
  final _androidUrl = TextEditingController();
  final _logoUrl = TextEditingController();
  final _announcementTitle = TextEditingController();
  final _announcementBody = TextEditingController();
  final _announcementExpiry = TextEditingController();
  final _runningText = TextEditingController();
  final _liveMessage = TextEditingController();
  final _minimumVersion = TextEditingController();
  final _maintenanceMessage = TextEditingController();
  bool _announcementActive = false;
  bool _liveNoticeActive = false;
  bool _maintenanceMode = false;
  bool _forceUpdate = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final c = context.read<BroadcasterProvider>().adminContent;
    _radioName.text = c.radioInfo.name;
    _tagline.text = c.radioInfo.tagline;
    _website.text = c.radioInfo.website;
    _telegram.text = c.radioInfo.telegram;
    _androidUrl.text = c.radioInfo.androidAppUrl;
    _logoUrl.text = c.radioInfo.logoUrl;
    _announcementTitle.text = c.announcement.title;
    _announcementBody.text = c.announcement.body;
    _announcementExpiry.text = _dateText(c.announcement.expiresAt);
    _announcementActive = c.announcement.isActive;
    _runningText.text = c.liveNotice.runningText;
    _liveMessage.text = c.liveNotice.liveMessage;
    _liveNoticeActive = c.liveNotice.isActive;
    _minimumVersion.text = c.maintenance.minimumVersion;
    _maintenanceMessage.text = c.maintenance.message;
    _maintenanceMode = c.maintenance.maintenanceMode;
    _forceUpdate = c.maintenance.forceUpdate;
    _ready = true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BroadcasterProvider>();
    final content = provider.adminContent;
    return _AdminShell(
      title: 'Panel Admin Radio',
      subtitle: 'CMS internal tahap awal. Data tersimpan lokal di perangkat.',
      trailing: TextButton.icon(
        onPressed: provider.lockAdmin,
        icon: const Icon(Icons.lock_outline_rounded),
        label: const Text('Kunci'),
      ),
      child: Column(
        children: [
          _SectionCard(title: 'Informasi Radio', icon: Icons.info_outline_rounded, children: [
            _TextInput(controller: _radioName, label: 'Nama Radio'),
            _TextInput(controller: _tagline, label: 'Tagline'),
            _TextInput(controller: _website, label: 'Website'),
            _TextInput(controller: _telegram, label: 'Telegram'),
            _TextInput(controller: _androidUrl, label: 'Link Aplikasi Android'),
            _TextInput(controller: _logoUrl, label: 'Logo URL'),
          ]),
          _SectionCard(title: 'Pengumuman', icon: Icons.campaign_rounded, children: [
            SwitchListTile(value: _announcementActive, onChanged: (v) => setState(() => _announcementActive = v), title: const Text('Aktif')),
            _TextInput(controller: _announcementTitle, label: 'Judul'),
            _TextInput(controller: _announcementBody, label: 'Isi', maxLines: 3),
            _TextInput(controller: _announcementExpiry, label: 'Kadaluarsa (YYYY-MM-DD)'),
          ]),
          _SectionCard(title: 'Live Notice', icon: Icons.live_tv_rounded, children: [
            SwitchListTile(value: _liveNoticeActive, onChanged: (v) => setState(() => _liveNoticeActive = v), title: const Text('Aktif')),
            _TextInput(controller: _runningText, label: 'Running Text'),
            _TextInput(controller: _liveMessage, label: 'Pesan Live', maxLines: 2),
          ]),
          _CrudSection<ScheduleItem>(
            title: 'Jadwal Kajian',
            icon: Icons.calendar_month_rounded,
            items: content.schedules,
            label: (i) => '${i.day} ${i.time} • ${i.title}',
            subtitle: (i) => i.ustadz,
            active: (i) => i.isActive,
            onAdd: () => _addSchedule(content),
            onDelete: (i) => provider.saveAdminContent(content.copyWith(schedules: content.schedules.where((x) => x.id != i.id).toList())),
          ),
          _CrudSection<UstadzItem>(
            title: 'Ustadz',
            icon: Icons.person_rounded,
            items: content.ustadzList,
            label: (i) => i.name,
            subtitle: (i) => i.bio,
            active: (i) => i.isActive,
            onAdd: () => _addUstadz(content),
            onDelete: (i) => provider.saveAdminContent(content.copyWith(ustadzList: content.ustadzList.where((x) => x.id != i.id).toList())),
          ),
          _CrudSection<DaurohItem>(
            title: 'Dauroh',
            icon: Icons.event_available_rounded,
            items: content.daurohList,
            label: (i) => i.title,
            subtitle: (i) => '${i.location} • ${i.date}',
            active: (i) => i.isActive,
            onAdd: () => _addDauroh(content),
            onDelete: (i) => provider.saveAdminContent(content.copyWith(daurohList: content.daurohList.where((x) => x.id != i.id).toList())),
          ),
          _SectionCard(title: 'Maintenance', icon: Icons.build_circle_rounded, children: [
            SwitchListTile(value: _maintenanceMode, onChanged: (v) => setState(() => _maintenanceMode = v), title: const Text('Maintenance Mode')),
            SwitchListTile(value: _forceUpdate, onChanged: (v) => setState(() => _forceUpdate = v), title: const Text('Force Update')),
            _TextInput(controller: _minimumVersion, label: 'Versi Minimum'),
            _TextInput(controller: _maintenanceMessage, label: 'Pesan Maintenance', maxLines: 2),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Simpan Semua Konten')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final old = context.read<BroadcasterProvider>().adminContent;
    await context.read<BroadcasterProvider>().saveAdminContent(old.copyWith(
      radioInfo: RadioInfo(name: _radioName.text, tagline: _tagline.text, website: _website.text, telegram: _telegram.text, androidAppUrl: _androidUrl.text, logoUrl: _logoUrl.text),
      announcement: AnnouncementContent(title: _announcementTitle.text, body: _announcementBody.text, isActive: _announcementActive, expiresAt: DateTime.tryParse(_announcementExpiry.text)),
      liveNotice: LiveNoticeContent(runningText: _runningText.text, liveMessage: _liveMessage.text, isActive: _liveNoticeActive),
      maintenance: MaintenanceContent(maintenanceMode: _maintenanceMode, forceUpdate: _forceUpdate, minimumVersion: _minimumVersion.text, message: _maintenanceMessage.text),
    ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konten admin tersimpan.')));
  }

  Future<void> _addSchedule(AdminContent c) async {
    final item = await _showScheduleDialog(context);
    if (item != null && mounted) await context.read<BroadcasterProvider>().saveAdminContent(c.copyWith(schedules: [...c.schedules, item]));
  }

  Future<void> _addUstadz(AdminContent c) async {
    final item = await _showSimpleDialog<UstadzItem>(context, 'Tambah Ustadz', ['Nama', 'Bio', 'Foto URL'], (v) => UstadzItem(id: _id(), name: v[0], bio: v[1], photoUrl: v[2]));
    if (item != null && mounted) await context.read<BroadcasterProvider>().saveAdminContent(c.copyWith(ustadzList: [...c.ustadzList, item]));
  }

  Future<void> _addDauroh(AdminContent c) async {
    final item = await _showSimpleDialog<DaurohItem>(context, 'Tambah Dauroh', ['Judul', 'Lokasi', 'Tanggal', 'Deskripsi', 'Link Pendaftaran'], (v) => DaurohItem(id: _id(), title: v[0], location: v[1], date: v[2], description: v[3], registrationUrl: v[4]));
    if (item != null && mounted) await context.read<BroadcasterProvider>().saveAdminContent(c.copyWith(daurohList: [...c.daurohList, item]));
  }
}

class _AdminShell extends StatelessWidget {
  const _AdminShell({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppTheme.muted))])), if (trailing != null) trailing!]),
      const SizedBox(height: 18),
      child,
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]), const SizedBox(height: 12), ...children]),
    ),
  );
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.controller, required this.label, this.maxLines = 1, this.keyboardType, this.obscureText = false});
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, obscureText: obscureText, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)));
}

class _CrudSection<T> extends StatelessWidget {
  const _CrudSection({required this.title, required this.icon, required this.items, required this.label, required this.subtitle, required this.active, required this.onAdd, required this.onDelete});
  final String title;
  final IconData icon;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) subtitle;
  final bool Function(T) active;
  final VoidCallback onAdd;
  final void Function(T) onDelete;
  @override
  Widget build(BuildContext context) => _SectionCard(title: title, icon: icon, children: [
    if (items.isEmpty) const Text('Belum ada data.', style: TextStyle(color: AppTheme.muted)),
    for (final item in items) ListTile(contentPadding: EdgeInsets.zero, title: Text(label(item)), subtitle: Text(subtitle(item)), leading: Icon(active(item) ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded), trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => onDelete(item))),
    Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: Text('Tambah $title'))),
  ]);
}

Future<ScheduleItem?> _showScheduleDialog(BuildContext context) => _showSimpleDialog<ScheduleItem>(context, 'Tambah Jadwal', ['Judul', 'Ustadz', 'Hari', 'Jam', 'Deskripsi'], (v) => ScheduleItem(id: _id(), title: v[0], ustadz: v[1], day: v[2], time: v[3], description: v[4]));

Future<T?> _showSimpleDialog<T>(BuildContext context, String title, List<String> labels, T Function(List<String>) build) async {
  final controllers = labels.map((_) => TextEditingController()).toList();
  return showDialog<T>(context: context, builder: (context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < labels.length; i++) _TextInput(controller: controllers[i], label: labels[i])])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, build(controllers.map((c) => c.text).toList())), child: const Text('Simpan'))],
  ));
}

String _id() => DateTime.now().microsecondsSinceEpoch.toString();
String _dateText(DateTime? value) => value == null ? '' : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
