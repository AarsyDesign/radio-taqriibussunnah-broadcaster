
class RadioInfo {
  const RadioInfo({
    this.name = 'Radio Taqriibussunnah',
    this.tagline = 'Radio dakwah sunnah',
    this.website = '',
    this.telegram = '',
    this.androidAppUrl = '',
    this.logoUrl = '',
  });

  final String name;
  final String tagline;
  final String website;
  final String telegram;
  final String androidAppUrl;
  final String logoUrl;

  Map<String, dynamic> toJson() => {
    'name': name,
    'tagline': tagline,
    'website': website,
    'telegram': telegram,
    'androidAppUrl': androidAppUrl,
    'logoUrl': logoUrl,
  };

  factory RadioInfo.fromJson(Map<String, dynamic> json) => RadioInfo(
    name: json['name'] as String? ?? 'Radio Taqriibussunnah',
    tagline: json['tagline'] as String? ?? 'Radio dakwah sunnah',
    website: json['website'] as String? ?? '',
    telegram: json['telegram'] as String? ?? '',
    androidAppUrl: json['androidAppUrl'] as String? ?? '',
    logoUrl: json['logoUrl'] as String? ?? '',
  );
}

class AnnouncementContent {
  const AnnouncementContent({
    this.title = '',
    this.body = '',
    this.isActive = false,
    this.expiresAt,
  });

  final String title;
  final String body;
  final bool isActive;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'isActive': isActive,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory AnnouncementContent.fromJson(Map<String, dynamic> json) =>
      AnnouncementContent(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
        expiresAt: _parseDate(json['expiresAt'] as String?),
      );
}

class LiveNoticeContent {
  const LiveNoticeContent({
    this.runningText = '',
    this.liveMessage = '',
    this.isActive = false,
  });

  final String runningText;
  final String liveMessage;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'runningText': runningText,
    'liveMessage': liveMessage,
    'isActive': isActive,
  };

  factory LiveNoticeContent.fromJson(Map<String, dynamic> json) =>
      LiveNoticeContent(
        runningText: json['runningText'] as String? ?? '',
        liveMessage: json['liveMessage'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
      );
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.ustadz,
    required this.day,
    required this.time,
    this.description = '',
    this.isActive = true,
  });

  final String id;
  final String title;
  final String ustadz;
  final String day;
  final String time;
  final String description;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'ustadz': ustadz,
    'day': day,
    'time': time,
    'description': description,
    'isActive': isActive,
  };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    id: json['id'] as String? ?? _newId(),
    title: json['title'] as String? ?? '',
    ustadz: json['ustadz'] as String? ?? '',
    day: json['day'] as String? ?? '',
    time: json['time'] as String? ?? '',
    description: json['description'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );
}

class UstadzItem {
  const UstadzItem({
    required this.id,
    required this.name,
    this.bio = '',
    this.photoUrl = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String bio;
  final String photoUrl;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bio': bio,
    'photoUrl': photoUrl,
    'isActive': isActive,
  };

  factory UstadzItem.fromJson(Map<String, dynamic> json) => UstadzItem(
    id: json['id'] as String? ?? _newId(),
    name: json['name'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    photoUrl: json['photoUrl'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );
}

class DaurohItem {
  const DaurohItem({
    required this.id,
    required this.title,
    this.location = '',
    this.date = '',
    this.description = '',
    this.registrationUrl = '',
    this.isActive = true,
  });

  final String id;
  final String title;
  final String location;
  final String date;
  final String description;
  final String registrationUrl;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'location': location,
    'date': date,
    'description': description,
    'registrationUrl': registrationUrl,
    'isActive': isActive,
  };

  factory DaurohItem.fromJson(Map<String, dynamic> json) => DaurohItem(
    id: json['id'] as String? ?? _newId(),
    title: json['title'] as String? ?? '',
    location: json['location'] as String? ?? '',
    date: json['date'] as String? ?? '',
    description: json['description'] as String? ?? '',
    registrationUrl: json['registrationUrl'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );
}

class MaintenanceContent {
  const MaintenanceContent({
    this.maintenanceMode = false,
    this.forceUpdate = false,
    this.minimumVersion = '',
    this.message = '',
  });

  final bool maintenanceMode;
  final bool forceUpdate;
  final String minimumVersion;
  final String message;

  Map<String, dynamic> toJson() => {
    'maintenanceMode': maintenanceMode,
    'forceUpdate': forceUpdate,
    'minimumVersion': minimumVersion,
    'message': message,
  };

  factory MaintenanceContent.fromJson(Map<String, dynamic> json) =>
      MaintenanceContent(
        maintenanceMode: json['maintenanceMode'] as bool? ?? false,
        forceUpdate: json['forceUpdate'] as bool? ?? false,
        minimumVersion: json['minimumVersion'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class AdminContent {
  const AdminContent({
    this.radioInfo = const RadioInfo(),
    this.announcement = const AnnouncementContent(),
    this.liveNotice = const LiveNoticeContent(),
    this.schedules = const [],
    this.ustadzList = const [],
    this.daurohList = const [],
    this.maintenance = const MaintenanceContent(),
  });

  final RadioInfo radioInfo;
  final AnnouncementContent announcement;
  final LiveNoticeContent liveNotice;
  final List<ScheduleItem> schedules;
  final List<UstadzItem> ustadzList;
  final List<DaurohItem> daurohList;
  final MaintenanceContent maintenance;

  AdminContent copyWith({
    RadioInfo? radioInfo,
    AnnouncementContent? announcement,
    LiveNoticeContent? liveNotice,
    List<ScheduleItem>? schedules,
    List<UstadzItem>? ustadzList,
    List<DaurohItem>? daurohList,
    MaintenanceContent? maintenance,
  }) => AdminContent(
    radioInfo: radioInfo ?? this.radioInfo,
    announcement: announcement ?? this.announcement,
    liveNotice: liveNotice ?? this.liveNotice,
    schedules: schedules ?? this.schedules,
    ustadzList: ustadzList ?? this.ustadzList,
    daurohList: daurohList ?? this.daurohList,
    maintenance: maintenance ?? this.maintenance,
  );

  Map<String, dynamic> toJson() => {
    'radioInfo': radioInfo.toJson(),
    'announcement': announcement.toJson(),
    'liveNotice': liveNotice.toJson(),
    'schedules': schedules.map((item) => item.toJson()).toList(),
    'ustadzList': ustadzList.map((item) => item.toJson()).toList(),
    'daurohList': daurohList.map((item) => item.toJson()).toList(),
    'maintenance': maintenance.toJson(),
  };

  factory AdminContent.fromJson(Map<String, dynamic> json) => AdminContent(
    radioInfo: RadioInfo.fromJson(json['radioInfo'] as Map<String, dynamic>? ?? {}),
    announcement: AnnouncementContent.fromJson(json['announcement'] as Map<String, dynamic>? ?? {}),
    liveNotice: LiveNoticeContent.fromJson(json['liveNotice'] as Map<String, dynamic>? ?? {}),
    schedules: _list(json['schedules']).map(ScheduleItem.fromJson).toList(),
    ustadzList: _list(json['ustadzList']).map(UstadzItem.fromJson).toList(),
    daurohList: _list(json['daurohList']).map(DaurohItem.fromJson).toList(),
    maintenance: MaintenanceContent.fromJson(json['maintenance'] as Map<String, dynamic>? ?? {}),
  );
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

DateTime? _parseDate(String? value) => value == null ? null : DateTime.tryParse(value);
String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
