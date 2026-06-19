class BuildInfoModel {
  const BuildInfoModel({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.buildNumber,
    required this.buildChannel,
    required this.patchName,
    required this.environment,
    required this.buildDate,
    required this.gitCommit,
  });

  final String appName;
  final String packageName;
  final String versionName;
  final String buildNumber;
  final String buildChannel;
  final String patchName;
  final String environment;
  final String buildDate;
  final String gitCommit;

  BuildInfoModel copyWith({
    String? appName,
    String? packageName,
    String? versionName,
    String? buildNumber,
    String? buildChannel,
    String? patchName,
    String? environment,
    String? buildDate,
    String? gitCommit,
  }) {
    return BuildInfoModel(
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      versionName: versionName ?? this.versionName,
      buildNumber: buildNumber ?? this.buildNumber,
      buildChannel: buildChannel ?? this.buildChannel,
      patchName: patchName ?? this.patchName,
      environment: environment ?? this.environment,
      buildDate: buildDate ?? this.buildDate,
      gitCommit: gitCommit ?? this.gitCommit,
    );
  }

  @override
  String toString() {
    return 'BuildInfoModel(appName: $appName, packageName: $packageName, '
        'versionName: $versionName, buildNumber: $buildNumber, '
        'buildChannel: $buildChannel, patchName: $patchName, '
        'environment: $environment, buildDate: $buildDate, '
        'gitCommit: $gitCommit)';
  }
}
