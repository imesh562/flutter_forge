import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Generates main.dart (flavor router) and the flavor-specific entrypoints.
final class EntrypointGenerator {
  Future<void> run(ProjectConfig config) async {
    if (config.useFlavors) {
      await _writeMainRouter(config);
      for (final flavor in Flavor.values) {
        await _writeFlavorMain(config, flavor);
      }
    } else {
      await _writeSingleMain(config);
    }
  }

  // ── Multi-flavor mode ──────────────────────────────────────────────────────

  Future<void> _writeMainRouter(ProjectConfig config) async {
    await FileUtils.writeFile(
      p.join(config.projectPath, 'lib', 'main.dart'),
      '''
// This file is intentionally minimal — run a flavor-specific entrypoint.
// Use: flutter run --flavor dev --target lib/main_dev.dart
void main() => throw UnimplementedError(
      'Run a flavor entrypoint: main_dev.dart, main_stg.dart, '
      'main_pre_prod.dart, or main_prod.dart',
    );
''',
    );
  }

  Future<void> _writeFlavorMain(
    ProjectConfig config,
    Flavor flavor,
  ) async {
    final s = config.settingsFor(flavor);
    final pkg = config.projectName;
    final envConst = switch (flavor) {
      Flavor.dev => 'Environment.dev',
      Flavor.stg => 'Environment.stg',
      Flavor.preProd => 'Environment.preProd',
      Flavor.prod => 'Environment.prod',
    };
    final envName = flavor.envName;
    final fileName = switch (flavor) {
      Flavor.dev => 'main_dev',
      Flavor.stg => 'main_stg',
      Flavor.preProd => 'main_pre_prod',
      Flavor.prod => 'main_prod',
    };

    final firebaseImports = config.useFirebase
        ? '''
import 'package:firebase_core/firebase_core.dart';

import 'package:$pkg/core/analytics/analytics_service.dart';
import 'package:$pkg/core/di/injection.dart';
import 'package:$pkg/core/notifications/local_push_service.dart';'''
        : '''
import 'package:$pkg/core/di/injection.dart';''';

    final notificationProviderImport = config.useFirebase
        ? "\nimport 'package:$pkg/shared/providers/notification_provider.dart';"
        : '';

    final analyticsImport =
        (!config.useFirebase && config.hasMixpanel)
            ? "\nimport 'package:$pkg/core/analytics/analytics_service.dart';"
            : '';

    // Per-flavor token may be null even when hasMixpanel=true (another flavor
    // may have provided the token).
    final mixpanelTokenLine = config.hasMixpanel
        ? "\n    mixpanelToken: ${s.mixpanelToken != null ? "'${s.mixpanelToken}'" : 'null'},"
        : '';

    final firebaseInit = config.useFirebase
        ? '''

  await Firebase.initializeApp();
  await getIt<LocalPushService>().initialize();
  await getIt<AnalyticsService>().initialize();'''
        : (config.hasMixpanel
            ? '''

  await getIt<AnalyticsService>().initialize();'''
            : '');

    final notificationProvider = config.useFirebase
        ? '\n        ChangeNotifierProvider(create: (_) => NotificationProvider()),'
        : '';

    final isProd = flavor == Flavor.prod;
    final appTitle = isProd
        ? config.appDisplayName
        : '${config.appDisplayName} ${flavor.label}';
    final appBuilder = isProd
        ? '''
      builder: (context, child) => MaterialApp.router(
        title: '$appTitle',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: AppRouter.router,
      ),'''
        : '''
      builder: (context, child) => MaterialApp.router(
        title: '$appTitle',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: AppRouter.router,
        builder: (context, child) => Banner(
          message: '${flavor.label}',
          location: BannerLocation.topStart,
          child: child!,
        ),
      ),''';

    await FileUtils.writeFile(
      p.join(config.projectPath, 'lib', '$fileName.dart'),
      '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

$firebaseImports$analyticsImport
import 'package:$pkg/flavors/flavor.dart';
import 'package:$pkg/flavors/flavor_config.dart';
import 'package:$pkg/navigation/app_router.dart';$notificationProviderImport
import 'package:$pkg/shared/blocs/theme_cubit.dart';
import 'package:$pkg/shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  FlavorConfig.instance = FlavorConfig(
    flavor: Flavor.$envName,
    name: '${flavor.label}',
    baseUrl: '${s.baseUrl}',
    wsUrl: '${s.wsUrl}',$mixpanelTokenLine
  );

  await configureInjection($envConst);
$firebaseInit

  runApp(
    MultiProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),$notificationProvider
      ],
      child: const _App(),
    ),
  );
}

final class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    return ScreenUtilInit(
      designSize: const Size(390, 844),
$appBuilder
    );
  }
}
''',
    );
  }

  // ── Single-env mode (no flavors) ───────────────────────────────────────────

  Future<void> _writeSingleMain(ProjectConfig config) async {
    final s = config.flavorSettings.first;
    final pkg = config.projectName;

    final firebaseImports = config.useFirebase
        ? '''
import 'package:firebase_core/firebase_core.dart';

import 'package:$pkg/core/analytics/analytics_service.dart';
import 'package:$pkg/core/di/injection.dart';
import 'package:$pkg/core/notifications/local_push_service.dart';'''
        : '''
import 'package:$pkg/core/di/injection.dart';''';

    final notificationProviderImport = config.useFirebase
        ? "\nimport 'package:$pkg/shared/providers/notification_provider.dart';"
        : '';

    final analyticsImport =
        (!config.useFirebase && config.hasMixpanel)
            ? "\nimport 'package:$pkg/core/analytics/analytics_service.dart';"
            : '';

    final mixpanelTokenLine = config.hasMixpanel
        ? "\n    mixpanelToken: '${s.mixpanelToken}',"
        : '';

    final firebaseInit = config.useFirebase
        ? '''

  await Firebase.initializeApp();
  await getIt<LocalPushService>().initialize();
  await getIt<AnalyticsService>().initialize();'''
        : (config.hasMixpanel
            ? '''

  await getIt<AnalyticsService>().initialize();'''
            : '');

    final notificationProvider = config.useFirebase
        ? '\n        ChangeNotifierProvider(create: (_) => NotificationProvider()),'
        : '';

    await FileUtils.writeFile(
      p.join(config.projectPath, 'lib', 'main.dart'),
      '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

$firebaseImports$analyticsImport
import 'package:$pkg/flavors/flavor_config.dart';
import 'package:$pkg/navigation/app_router.dart';$notificationProviderImport
import 'package:$pkg/shared/blocs/theme_cubit.dart';
import 'package:$pkg/shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  FlavorConfig.instance = FlavorConfig(
    baseUrl: '${s.baseUrl}',
    wsUrl: '${s.wsUrl}',$mixpanelTokenLine
  );

  await configureInjection(Environment.prod);
$firebaseInit

  runApp(
    MultiProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),$notificationProvider
      ],
      child: const _App(),
    ),
  );
}

final class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp.router(
        title: '${config.appDisplayName}',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
''',
    );
  }
}
