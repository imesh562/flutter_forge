import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

final class DiGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    final base = '${config.projectPath}/lib/core/di';

    await Future.wait([
      _writeInjection(base, pkg),
      _writeRegisterModule(base),
      _writeInjectionConfigStub(base, config),
    ]);
  }

  Future<void> _writeInjection(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/injection.dart',
      '''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureInjection(String environment) async =>
    getIt.init(environment: environment);

/// Environment constants that map directly to Flutter build flavors.
abstract final class Environment {
  static const String dev = 'dev';
  static const String stg = 'stg';
  static const String preProd = 'pre_prod';
  static const String prod = 'prod';
}
''',
    );
  }

  Future<void> _writeRegisterModule(String base) async {
    await FileUtils.writeFile(
      '$base/register_module.dart',
      '''
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RegisterModule {
  @preResolve
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();

  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage();
}
''',
    );
  }

  Future<void> _writeInjectionConfigStub(
    String base,
    ProjectConfig config,
  ) async {
    // This compilable stub is replaced by `dart run build_runner build`.
    // It is complete enough to compile and run without build_runner so that
    // the project works out-of-the-box.
    final analyticsLine = _buildAnalyticsRegistration(config);

    await FileUtils.writeFile(
      '$base/injection.config.dart',
      '''
// GENERATED CODE — run `dart run build_runner build` to regenerate.
// ignore_for_file: type=lint, unnecessary_lambdas, lines_longer_than_80_chars

import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../network/api_helper.dart' as _i938;
import '../storage/preferences_service.dart' as _i636;
import '../storage/secure_storage_service.dart' as _i666;
import 'register_module.dart' as _i291;
$analyticsLine

const String _dev = 'dev';
const String _stg = 'stg';
const String _pre_prod = 'pre_prod';
const String _prod = 'prod';

extension GetItInjectableX on _i174.GetIt {
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _\$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.sharedPreferences,
      preResolve: true,
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
        () => registerModule.flutterSecureStorage);
    gh.lazySingleton<_i938.ApiHelper>(
      () => _i938.ApiHelper(),
      registerFor: {_dev, _stg, _pre_prod, _prod},
    );
    gh.lazySingleton<_i636.PreferencesService>(
        () => _i636.PreferencesService(gh<_i460.SharedPreferences>()));
    gh.lazySingleton<_i666.SecureStorageService>(
        () => _i666.SecureStorageService(gh<_i558.FlutterSecureStorage>()));
${_buildAnalyticsBody(config)}    return this;
  }
}

class _\$RegisterModule extends _i291.RegisterModule {}
''',
    );
  }

  String _buildAnalyticsRegistration(ProjectConfig config) {
    final buf = StringBuffer();
    if (config.useFirebase) {
      buf.writeln(
        "import '../notifications/local_push_service.dart' as _i_lpush;",
      );
      buf.writeln(
        "import '../analytics/firebase_analytics_service.dart' as _firebase;",
      );
    }
    if (config.hasMixpanel) {
      buf.writeln(
        "import '../analytics/mixpanel_analytics_service.dart' as _mixpanel;",
      );
    }
    if (config.useFirebase || config.hasMixpanel) {
      buf.writeln(
        "import '../analytics/analytics_service.dart' as _i726;",
      );
      buf.writeln(
        "import '../analytics/composite_analytics_service.dart' as _composite;",
      );
    }
    return buf.toString().trimRight();
  }

  String _buildAnalyticsBody(ProjectConfig config) {
    if (!config.useFirebase && !config.hasMixpanel) return '';
    final buf = StringBuffer();
    if (config.useFirebase) {
      buf.writeln(
        '    gh.lazySingleton<_i_lpush.LocalPushService>('
        '() => _i_lpush.LocalPushService(gh<_i636.PreferencesService>()));',
      );
      buf.writeln(
        '    gh.lazySingleton<_firebase.FirebaseAnalyticsService>('
        '() => _firebase.FirebaseAnalyticsService());',
      );
    }
    if (config.hasMixpanel) {
      buf.writeln(
        '    gh.lazySingleton<_mixpanel.MixpanelAnalyticsService>('
        '() => _mixpanel.MixpanelAnalyticsService());',
      );
    }
    final args = [
      if (config.useFirebase) 'gh<_firebase.FirebaseAnalyticsService>()',
      if (config.hasMixpanel) 'gh<_mixpanel.MixpanelAnalyticsService>()',
    ].join(', ');
    buf.writeln(
      '    gh.lazySingleton<_i726.AnalyticsService>('
      '() => _composite.CompositeAnalyticsService($args));',
    );
    return buf.toString();
  }
}
