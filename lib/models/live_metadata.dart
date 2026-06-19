const liveMetadataFallback = 'Kajian Live Radio Taqriibussunnah';

String cleanLiveMetadataField(String value, {required int maxLength}) {
  final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.length <= maxLength) return cleaned;
  return cleaned.substring(0, maxLength);
}

String buildLiveMetadata(
  String ustadzName,
  String kajianTitle,
  String kajianTheme,
) {
  final parts = [
    cleanLiveMetadataField(ustadzName, maxLength: 80),
    cleanLiveMetadataField(kajianTitle, maxLength: 80),
    cleanLiveMetadataField(kajianTheme, maxLength: 120),
  ].where((part) => part.isNotEmpty).toList();

  if (parts.isEmpty) return liveMetadataFallback;
  return parts.join(' - ');
}
