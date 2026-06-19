import 'package:package_info_plus/package_info_plus.dart';

import '../models/build_info_model.dart';

class BuildInfoService {
  Future<BuildInfoModel> loadBuildInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    return BuildInfoModel(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      versionName: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      buildChannel: const String.fromEnvironment(
        'BUILD_CHANNEL',
        defaultValue: 'debug',
      ),
      patchName: const String.fromEnvironment(
        'PATCH_NAME',
        defaultValue: 'local-dev',
      ),
      environment: const String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: 'internal-test',
      ),
      buildDate: const String.fromEnvironment(
        'BUILD_DATE',
        defaultValue: 'unknown',
      ),
      gitCommit: const String.fromEnvironment(
        'GIT_COMMIT',
        defaultValue: 'unknown',
      ),
    );
  }
}
