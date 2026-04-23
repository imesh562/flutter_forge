import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

final class AnalyticsGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    final base = p.join(config.projectPath, 'lib', 'core', 'analytics');

    final futs = <Future<void>>[
      _writeInterface(base),
    ];

    if (config.useFirebase) futs.add(_writeFirebaseService(base));
    if (config.hasMixpanel) futs.add(_writeMixpanelService(base, pkg));
    futs.add(_writeCompositeService(base, config));

    await Future.wait(futs);
  }

  Future<void> _writeInterface(String base) async {
    await FileUtils.writeFile(
      p.join(base, 'analytics_service.dart'),
      '''
/// Contract that all analytics providers must implement.
abstract interface class AnalyticsService {
  Future<void> initialize();
  Future<void> logEvent(String name, Map<String, dynamic> params);
  Future<void> setUserProperty(String key, String value);
  Future<void> logScreen(String name);
}
''',
    );
  }

  Future<void> _writeFirebaseService(String base) async {
    await FileUtils.writeFile(
      p.join(base, 'firebase_analytics_service.dart'),
      '''
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:injectable/injectable.dart';

import 'analytics_service.dart';

@lazySingleton
final class FirebaseAnalyticsService implements AnalyticsService {
  final _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(String name, Map<String, dynamic> params) =>
      _analytics.logEvent(name: name, parameters: params.cast<String, Object>());

  @override
  Future<void> setUserProperty(String key, String value) =>
      _analytics.setUserProperty(name: key, value: value);

  @override
  Future<void> logScreen(String name) =>
      _analytics.logScreenView(screenName: name);
}
''',
    );
  }

  Future<void> _writeMixpanelService(String base, String pkg) async {
    await FileUtils.writeFile(
      p.join(base, 'mixpanel_analytics_service.dart'),
      '''
import 'package:injectable/injectable.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

import 'package:$pkg/flavors/flavor_config.dart';
import 'analytics_service.dart';

@lazySingleton
final class MixpanelAnalyticsService implements AnalyticsService {
  Mixpanel? _mixpanel;

  @override
  Future<void> initialize() async {
    final token = FlavorConfig.instance.mixpanelToken;
    if (token == null) return;
    _mixpanel = await Mixpanel.init(token, trackAutomaticEvents: true);
  }

  @override
  Future<void> logEvent(String name, Map<String, dynamic> params) async {
    _mixpanel?.track(name, properties: params);
  }

  @override
  Future<void> setUserProperty(String key, String value) async {
    _mixpanel?.getPeople().set(key, value);
  }

  @override
  Future<void> logScreen(String name) async {
    _mixpanel?.track('screen_view', properties: {'screen_name': name});
  }
}
''',
    );
  }

  Future<void> _writeCompositeService(
    String base,
    ProjectConfig config,
  ) async {
    final imports = StringBuffer();
    final ctorParams = StringBuffer();
    final fields = StringBuffer();
    final servicesList = StringBuffer('[');

    if (config.useFirebase) {
      imports.writeln("import 'firebase_analytics_service.dart';");
      ctorParams.writeln('    this._firebase,');
      fields.writeln('  final FirebaseAnalyticsService _firebase;');
      servicesList.write('_firebase');
    }
    if (config.hasMixpanel) {
      imports.writeln("import 'mixpanel_analytics_service.dart';");
      ctorParams.writeln('    this._mixpanel,');
      fields.writeln('  final MixpanelAnalyticsService _mixpanel;');
      if (config.useFirebase) servicesList.write(', ');
      servicesList.write('_mixpanel');
    }
    servicesList.write(']');

    await FileUtils.writeFile(
      p.join(base, 'composite_analytics_service.dart'),
      '''
import 'package:injectable/injectable.dart';

import 'analytics_service.dart';
${imports.toString().trimRight()}

/// Fans out every analytics call to all registered providers.
/// To add or remove a provider, update the DI registration — no logic changes
/// required here.
@LazySingleton(as: AnalyticsService)
final class CompositeAnalyticsService implements AnalyticsService {
  CompositeAnalyticsService(
${ctorParams.toString().trimRight()}
  );

${fields.toString().trimRight()}

  List<AnalyticsService> get _services => $servicesList;

  @override
  Future<void> initialize() =>
      Future.wait(_services.map((s) => s.initialize()));

  @override
  Future<void> logEvent(String name, Map<String, dynamic> params) =>
      Future.wait(_services.map((s) => s.logEvent(name, params)));

  @override
  Future<void> setUserProperty(String key, String value) =>
      Future.wait(_services.map((s) => s.setUserProperty(key, value)));

  @override
  Future<void> logScreen(String name) =>
      Future.wait(_services.map((s) => s.logScreen(name)));
}
''',
    );
  }
}
