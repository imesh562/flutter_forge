import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

final class NavigationGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    final base = '${config.projectPath}/lib';

    await Future.wait([
      _writeAppRouter(base, pkg),
      _writeRouteGuards(base, pkg),
      _writeStubPages(base, pkg),
      _writeLogoutUseCase(base, pkg),
    ]);
  }

  Future<void> _writeAppRouter(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/navigation/app_router.dart',
      '''
import 'package:go_router/go_router.dart';

import 'package:$pkg/features/auth/presentation/pages/splash_page.dart';
import 'package:$pkg/features/onboarding/presentation/pages/login_page.dart';
import 'package:$pkg/shared/widgets/force_update_view.dart';
import 'package:$pkg/shared/widgets/maintenance_view.dart';
import 'route_guards.dart';

abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: RouteGuards.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.forceUpdate,
        builder: (context, state) => const ForceUpdateView(),
      ),
      GoRoute(
        path: AppRoutes.maintenance,
        builder: (context, state) => const MaintenanceView(),
      ),
    ],
  );
}

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const forceUpdate = '/force-update';
  static const maintenance = '/maintenance';
}
''',
    );
  }

  Future<void> _writeLogoutUseCase(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/shared/usecases/logout_usecase.dart',
      '''
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Clears all locally-stored session credentials.
///
/// Called by [BaseViewMixin.logout] on every [UnAuthorizedFailure], and can
/// also be invoked explicitly from a logout button in the UI layer.
///
/// Keeping this in the domain layer means the cleanup logic is testable
/// independently of the UI and can be extended (e.g. invalidate a server
/// session, clear Hive boxes) without touching presentation code.
@lazySingleton
class LogoutUseCase {
  const LogoutUseCase();

  static const _storage = FlutterSecureStorage();

  /// Deletes the auth token from secure storage.
  /// Returns normally even if the token was already absent.
  Future<void> call() async {
    await _storage.delete(key: 'auth_token');
  }
}
''',
    );
  }

  Future<void> _writeRouteGuards(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/navigation/route_guards.dart',
      '''
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

abstract final class RouteGuards {
  /// Returns a redirect path when the user should not access [state.uri.path],
  /// or null to allow navigation to proceed.
  ///
  /// Replace the stubs below with real auth-state checks (e.g. from an
  /// injectable service or a provider) once auth logic is implemented.
  static String? redirect(BuildContext context, GoRouterState state) {
    const isAuthenticated = false;
    final path = state.uri.path;

    // System-level routes — always reachable regardless of auth state.
    if (path == AppRoutes.splash) return null;
    if (path == AppRoutes.forceUpdate) return null;
    if (path == AppRoutes.maintenance) return null;

    if (!isAuthenticated && path != AppRoutes.login) return AppRoutes.login;
    if (isAuthenticated && path == AppRoutes.login) return null;

    return null;
  }
}
''',
    );
  }

  Future<void> _writeStubPages(String base, String pkg) async {
    // SplashPage — auth feature, navigates to /login after a short delay.
    await FileUtils.writeFile(
      '$base/features/auth/presentation/pages/splash_page.dart',
      '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:$pkg/features/auth/presentation/auth_bloc.dart';
import 'package:$pkg/navigation/app_router.dart';
import 'package:$pkg/shared/widgets/base_view.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with BaseViewMixin<AuthBloc, AuthState, SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void onState(BuildContext context, AuthState state) {}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: FlutterLogo(size: 80)),
    );
  }
}
''',
    );

    // LoginPage — onboarding feature stub.
    await FileUtils.writeFile(
      '$base/features/onboarding/presentation/pages/login_page.dart',
      '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$pkg/features/onboarding/presentation/onboarding_bloc.dart';
import 'package:$pkg/shared/widgets/base_view.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with BaseViewMixin<OnboardingBloc, OnboardingState, LoginPage> {
  @override
  void onState(BuildContext context, OnboardingState state) {}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('LoginPage')),
    );
  }
}
''',
    );

    // ForceUpdateView — shown by BaseView when a ForceUpdateFailure is received.
    await FileUtils.writeFile(
      '$base/shared/widgets/force_update_view.dart',
      '''
import 'package:flutter/material.dart';

/// Shown automatically by [BaseView] when a [ForceUpdateFailure] is received.
///
/// Replace the body with your app's real force-update UI (store deep-link,
/// release notes, etc.). This screen is intentionally non-dismissible —
/// [PopScope] blocks the back button and [BaseView] navigates here with
/// [context.go] so there is no previous route to return to.
class ForceUpdateView extends StatelessWidget {
  const ForceUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_alt_rounded, size: 64),
              SizedBox(height: 16),
              Text(
                'Update Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Please update the app to continue.'),
            ],
          ),
        ),
      ),
    );
  }
}
''',
    );

    // MaintenanceView — shown by BaseView when a MaintenanceFailure is received.
    await FileUtils.writeFile(
      '$base/shared/widgets/maintenance_view.dart',
      '''
import 'package:flutter/material.dart';

/// Shown automatically by [BaseView] when a [MaintenanceFailure] is received.
///
/// Replace the body with your app's real maintenance UI (estimated time,
/// status page link, etc.). This screen is intentionally non-dismissible —
/// [PopScope] blocks the back button and [BaseView] navigates here with
/// [context.go] so there is no previous route to return to.
class MaintenanceView extends StatelessWidget {
  const MaintenanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded, size: 64),
              SizedBox(height: 16),
              Text(
                'Under Maintenance',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text("We'll be back shortly. Please try again later."),
            ],
          ),
        ),
      ),
    );
  }
}
''',
    );
  }
}
