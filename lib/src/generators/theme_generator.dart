import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

final class ThemeGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    final themeBase = '${config.projectPath}/lib/shared/theme';
    final providersBase = '${config.projectPath}/lib/shared/providers';
    final blocsBase = '${config.projectPath}/lib/shared/blocs';

    final sharedBase = '${config.projectPath}/lib/shared';

    await Future.wait([
      _writeAppColorScheme(themeBase),
      _writeAppDimensions(themeBase),
      _writeAppTheme(themeBase, pkg),
      _writeThemeCubit(blocsBase),
      if (config.useFirebase)
        _writeNotificationProviderShim(providersBase, pkg),
      _writeFlavorsFiles(config),
      _writeExtensions(config, pkg),
      _writeBaseStates(sharedBase, pkg),
      _writeBaseView(sharedBase, pkg),
    ]);
  }

  Future<void> _writeAppColorScheme(String base) async {
    await FileUtils.writeFile(
      '$base/app_color_scheme.dart',
      '''
import 'package:flutter/material.dart';

/// Semantic color tokens surfaced via [ThemeExtension].
///
/// Access in widgets with [BuildContextX.appColors] (from utils/extensions.dart).
/// To override individual tokens for a specific screen or widget, copy the
/// current scheme and pass it through a local [Theme] ancestor:
///
/// ```dart
/// Theme(
///   data: Theme.of(context).copyWith(
///     extensions: [
///       context.appColors.copyWith(primary: Colors.red),
///     ],
///   ),
///   child: ...,
/// )
/// ```
@immutable
final class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.primary,
    required this.primaryVariant,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.error,
    required this.onError,
    required this.textSecondary,
    required this.divider,
    required this.shimmerBase,
    required this.shimmerHighlight,
    // forge:constructor
  });

  final Color primary;
  final Color primaryVariant;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color error;
  final Color onError;
  final Color textSecondary;
  final Color divider;
  final Color shimmerBase;
  final Color shimmerHighlight;
  // forge:fields

  static const light = AppColorScheme(
    primary: Color(0xFF1A73E8),
    primaryVariant: Color(0xFF1558B0),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF34A853),
    onSecondary: Color(0xFFFFFFFF),
    background: Color(0xFFFFFFFF),
    onBackground: Color(0xFF202124),
    surface: Color(0xFFF8F9FA),
    onSurface: Color(0xFF202124),
    error: Color(0xFFEA4335),
    onError: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF5F6368),
    divider: Color(0xFFE0E0E0),
    shimmerBase: Color(0xFFE0E0E0),
    shimmerHighlight: Color(0xFFF5F5F5),
    // forge:light
  );

  static const dark = AppColorScheme(
    primary: Color(0xFF8AB4F8),
    primaryVariant: Color(0xFF669DF6),
    onPrimary: Color(0xFF1A1A1A),
    secondary: Color(0xFF81C995),
    onSecondary: Color(0xFF1A1A1A),
    background: Color(0xFF121212),
    onBackground: Color(0xFFE8EAED),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFE8EAED),
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF9AA0A6),
    divider: Color(0xFF3C4043),
    shimmerBase: Color(0xFF2A2A2A),
    shimmerHighlight: Color(0xFF3A3A3A),
    // forge:dark
  );

  @override
  AppColorScheme copyWith({
    Color? primary,
    Color? primaryVariant,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? error,
    Color? onError,
    Color? textSecondary,
    Color? divider,
    Color? shimmerBase,
    Color? shimmerHighlight,
    // forge:copyWith-params
  }) =>
      AppColorScheme(
        primary: primary ?? this.primary,
        primaryVariant: primaryVariant ?? this.primaryVariant,
        onPrimary: onPrimary ?? this.onPrimary,
        secondary: secondary ?? this.secondary,
        onSecondary: onSecondary ?? this.onSecondary,
        background: background ?? this.background,
        onBackground: onBackground ?? this.onBackground,
        surface: surface ?? this.surface,
        onSurface: onSurface ?? this.onSurface,
        error: error ?? this.error,
        onError: onError ?? this.onError,
        textSecondary: textSecondary ?? this.textSecondary,
        divider: divider ?? this.divider,
        shimmerBase: shimmerBase ?? this.shimmerBase,
        shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
        // forge:copyWith-body
      );

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryVariant: Color.lerp(primaryVariant, other.primaryVariant, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      // forge:lerp
    );
  }
}
''',
    );
  }

  Future<void> _writeAppDimensions(String base) async {
    await FileUtils.writeFile(
      '$base/app_dimensions.dart',
      '''
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// App Dimensions — responsive typography system.
///
/// Every font size returns a [ScreenUtil]-scaled value (.sp) so the UI
/// adapts to any screen density automatically.
///
/// Usage:
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(
///     fontSize: AppDimensions.kFontSize16,
///     height: AppDimensions.kLineHeight16(24),      // 24px line-height
///     letterSpacing: AppDimensions.kLetterSpacing16(2), // 2% tracking
///   ),
/// )
/// ```
class AppDimensions {
  AppDimensions._();

  // Font size 6
  static double get kFontSize6 => 6.sp;
  static double kLineHeight6(double lineHeight) => lineHeight / 6;
  static double kLetterSpacing6(double percentage) => (percentage / 100) * 6.sp;

  // Font size 7
  static double get kFontSize7 => 7.sp;
  static double kLineHeight7(double lineHeight) => lineHeight / 7;
  static double kLetterSpacing7(double percentage) => (percentage / 100) * 7.sp;

  // Font size 8
  static double get kFontSize8 => 8.sp;
  static double kLineHeight8(double lineHeight) => lineHeight / 8;
  static double kLetterSpacing8(double percentage) => (percentage / 100) * 8.sp;

  // Font size 9
  static double get kFontSize9 => 9.sp;
  static double kLineHeight9(double lineHeight) => lineHeight / 9;
  static double kLetterSpacing9(double percentage) => (percentage / 100) * 9.sp;

  // Font size 10
  static double get kFontSize10 => 10.sp;
  static double kLineHeight10(double lineHeight) => lineHeight / 10;
  static double kLetterSpacing10(double percentage) =>
      (percentage / 100) * 10.sp;

  // Font size 11
  static double get kFontSize11 => 11.sp;
  static double kLineHeight11(double lineHeight) => lineHeight / 11;
  static double kLetterSpacing11(double percentage) =>
      (percentage / 100) * 11.sp;

  // Font size 12
  static double get kFontSize12 => 12.sp;
  static double kLineHeight12(double lineHeight) => lineHeight / 12;
  static double kLetterSpacing12(double percentage) =>
      (percentage / 100) * 12.sp;

  // Font size 13
  static double get kFontSize13 => 13.sp;
  static double kLineHeight13(double lineHeight) => lineHeight / 13;
  static double kLetterSpacing13(double percentage) =>
      (percentage / 100) * 13.sp;

  // Font size 14
  static double get kFontSize14 => 14.sp;
  static double kLineHeight14(double lineHeight) => lineHeight / 14;
  static double kLetterSpacing14(double percentage) =>
      (percentage / 100) * 14.sp;

  // Font size 15
  static double get kFontSize15 => 15.sp;
  static double kLineHeight15(double lineHeight) => lineHeight / 15;
  static double kLetterSpacing15(double percentage) =>
      (percentage / 100) * 15.sp;

  // Font size 16
  static double get kFontSize16 => 16.sp;
  static double kLineHeight16(double lineHeight) => lineHeight / 16;
  static double kLetterSpacing16(double percentage) =>
      (percentage / 100) * 16.sp;

  // Font size 17
  static double get kFontSize17 => 17.sp;
  static double kLineHeight17(double lineHeight) => lineHeight / 17;
  static double kLetterSpacing17(double percentage) =>
      (percentage / 100) * 17.sp;

  // Font size 18
  static double get kFontSize18 => 18.sp;
  static double kLineHeight18(double lineHeight) => lineHeight / 18;
  static double kLetterSpacing18(double percentage) =>
      (percentage / 100) * 18.sp;

  // Font size 19
  static double get kFontSize19 => 19.sp;
  static double kLineHeight19(double lineHeight) => lineHeight / 19;
  static double kLetterSpacing19(double percentage) =>
      (percentage / 100) * 19.sp;

  // Font size 20
  static double get kFontSize20 => 20.sp;
  static double kLineHeight20(double lineHeight) => lineHeight / 20;
  static double kLetterSpacing20(double percentage) =>
      (percentage / 100) * 20.sp;

  // Font size 21
  static double get kFontSize21 => 21.sp;
  static double kLineHeight21(double lineHeight) => lineHeight / 21;
  static double kLetterSpacing21(double percentage) =>
      (percentage / 100) * 21.sp;

  // Font size 22
  static double get kFontSize22 => 22.sp;
  static double kLineHeight22(double lineHeight) => lineHeight / 22;
  static double kLetterSpacing22(double percentage) =>
      (percentage / 100) * 22.sp;

  // Font size 24
  static double get kFontSize24 => 24.sp;
  static double kLineHeight24(double lineHeight) => lineHeight / 24;
  static double kLetterSpacing24(double percentage) =>
      (percentage / 100) * 24.sp;

  // Font size 26
  static double get kFontSize26 => 26.sp;
  static double kLineHeight26(double lineHeight) => lineHeight / 26;
  static double kLetterSpacing26(double percentage) =>
      (percentage / 100) * 26.sp;

  // Font size 28
  static double get kFontSize28 => 28.sp;
  static double kLineHeight28(double lineHeight) => lineHeight / 28;
  static double kLetterSpacing28(double percentage) =>
      (percentage / 100) * 28.sp;

  // Font size 30
  static double get kFontSize30 => 30.sp;
  static double kLineHeight30(double lineHeight) => lineHeight / 30;
  static double kLetterSpacing30(double percentage) =>
      (percentage / 100) * 30.sp;

  // Font size 32
  static double get kFontSize32 => 32.sp;
  static double kLineHeight32(double lineHeight) => lineHeight / 32;
  static double kLetterSpacing32(double percentage) =>
      (percentage / 100) * 32.sp;

  // Font size 34
  static double get kFontSize34 => 34.sp;
  static double kLineHeight34(double lineHeight) => lineHeight / 34;
  static double kLetterSpacing34(double percentage) =>
      (percentage / 100) * 34.sp;

  // Font size 35
  static double get kFontSize35 => 35.sp;
  static double kLineHeight35(double lineHeight) => lineHeight / 35;
  static double kLetterSpacing35(double percentage) =>
      (percentage / 100) * 35.sp;

  // Font size 40
  static double get kFontSize40 => 40.sp;
  static double kLineHeight40(double lineHeight) => lineHeight / 40;
  static double kLetterSpacing40(double percentage) =>
      (percentage / 100) * 40.sp;

  // Font size 41
  static double get kFontSize41 => 41.sp;
  static double kLineHeight41(double lineHeight) => lineHeight / 41;
  static double kLetterSpacing41(double percentage) =>
      (percentage / 100) * 41.sp;

  // Font size 42
  static double get kFontSize42 => 42.sp;
  static double kLineHeight42(double lineHeight) => lineHeight / 42;
  static double kLetterSpacing42(double percentage) =>
      (percentage / 100) * 42.sp;

  // Font size 44
  static double get kFontSize44 => 44.sp;
  static double kLineHeight44(double lineHeight) => lineHeight / 44;
  static double kLetterSpacing44(double percentage) =>
      (percentage / 100) * 44.sp;

  // Font size 48
  static double get kFontSize48 => 48.sp;
  static double kLineHeight48(double lineHeight) => lineHeight / 48;
  static double kLetterSpacing48(double percentage) =>
      (percentage / 100) * 48.sp;

  // Font size 49
  static double get kFontSize49 => 49.sp;
  static double kLineHeight49(double lineHeight) => lineHeight / 49;
  static double kLetterSpacing49(double percentage) =>
      (percentage / 100) * 49.sp;

  // Font size 50
  static double get kFontSize50 => 50.sp;
  static double kLineHeight50(double lineHeight) => lineHeight / 50;
  static double kLetterSpacing50(double percentage) =>
      (percentage / 100) * 50.sp;

  // Font size 54
  static double get kFontSize54 => 54.sp;
  static double kLineHeight54(double lineHeight) => lineHeight / 54;
  static double kLetterSpacing54(double percentage) =>
      (percentage / 100) * 54.sp;

  // Font size 77
  static double get kFontSize77 => 77.sp;
  static double kLineHeight77(double lineHeight) => lineHeight / 77;
  static double kLetterSpacing77(double percentage) =>
      (percentage / 100) * 77.sp;
}
''',
    );
  }

  Future<void> _writeAppTheme(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/app_theme.dart',
      '''
import 'package:flutter/material.dart';

import 'app_color_scheme.dart';

/// Builds [ThemeData] instances with [AppColorScheme] registered as a
/// [ThemeExtension]. All semantic colors should be read from the extension
/// rather than from [ColorScheme], so individual tokens can be overridden
/// per-screen without forking an entire theme.
///
/// Access in widgets:
/// ```dart
/// final colors = context.appColors; // via BuildContextX extension
/// ```
abstract final class AppTheme {
  static ThemeData get light => _build(AppColorScheme.light, Brightness.light);

  static ThemeData get dark => _build(AppColorScheme.dark, Brightness.dark);

  static ThemeData _build(AppColorScheme scheme, Brightness brightness) =>
      ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: scheme.primary,
          brightness: brightness,
        ),
        scaffoldBackgroundColor: scheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.background,
          foregroundColor: scheme.onBackground,
          elevation: 0,
          centerTitle: false,
        ),
        extensions: [scheme],
      );
}
''',
    );
  }

  Future<void> _writeThemeCubit(String base) async {
    await FileUtils.writeFile(
      '$base/theme_cubit.dart',
      '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the active [ThemeMode] for the whole app.
///
/// State is the current [ThemeMode] (defaults to [ThemeMode.system]).
/// Provide above [MaterialApp] via [BlocProvider] and consume with
/// `context.watch<ThemeCubit>().state`.
///
/// ```dart
/// // Change theme:
/// context.read<ThemeCubit>().setTheme(ThemeMode.dark);
///
/// // Reset to system on logout:
/// context.read<ThemeCubit>().reset();
/// ```
final class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  bool get isLight  => state == ThemeMode.light;
  bool get isDark   => state == ThemeMode.dark;
  bool get isSystem => state == ThemeMode.system;

  void setTheme(ThemeMode mode) {
    if (state == mode) return;
    emit(mode);
  }

  /// Resets to the device system theme.  Call on logout to avoid a
  /// leftover dark/light preference bleeding into the next session.
  void reset() => emit(ThemeMode.system);
}
''',
    );
  }

  Future<void> _writeNotificationProviderShim(
    String base,
    String pkg,
  ) async {
    // Re-export from core/notifications so callers can use either import path.
    await FileUtils.writeFile(
      '$base/notification_provider.dart',
      '''
export 'package:$pkg/core/notifications/notification_provider.dart';
''',
    );
  }

  Future<void> _writeFlavorsFiles(ProjectConfig config) async {
    final base = '${config.projectPath}/lib/flavors';

    if (config.useFlavors) {
      await FileUtils.writeFile(
        '$base/flavor.dart',
        '''
enum Flavor { dev, stg, preProd, prod }
''',
      );

      await FileUtils.writeFile(
        '$base/flavor_config.dart',
        '''
import 'flavor.dart';

final class FlavorConfig {
  FlavorConfig({
    required this.flavor,
    required this.name,
    required this.baseUrl,
    required this.wsUrl,
    this.mixpanelToken,
  });

  static late FlavorConfig instance;

  final Flavor flavor;

  /// Short uppercase label shown in debug banners and analytics.
  final String name;

  final String baseUrl;
  final String wsUrl;

  /// Null when Mixpanel is not configured for this flavor.
  final String? mixpanelToken;

  bool get isProduction => flavor == Flavor.prod;
}
''',
      );
    } else {
      // No flavor enum needed — single environment.
      await FileUtils.writeFile(
        '$base/flavor_config.dart',
        '''
final class FlavorConfig {
  FlavorConfig({
    required this.baseUrl,
    required this.wsUrl,
    this.mixpanelToken,
  });

  static late FlavorConfig instance;

  final String baseUrl;
  final String wsUrl;

  /// Null when Mixpanel is not configured.
  final String? mixpanelToken;
}
''',
      );
    }
  }

  Future<void> _writeExtensions(ProjectConfig config, String pkg) async {
    await FileUtils.writeFile(
      '${config.projectPath}/lib/utils/extensions.dart',
      '''
import 'package:flutter/material.dart';

import 'package:$pkg/shared/theme/app_color_scheme.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Access the current [AppColorScheme] extension.
  ///
  /// Throws if [AppTheme.light] / [AppTheme.dark] are not used, because the
  /// extension would not have been registered.
  AppColorScheme get appColors => Theme.of(this).extension<AppColorScheme>()!;
}

extension StringX on String {
  String get capitalised =>
      isEmpty ? this : '\${this[0].toUpperCase()}\${substring(1)}';
}
''',
    );
  }

  Future<void> _writeBaseStates(String sharedBase, String pkg) async {
    await FileUtils.writeFile(
      '$sharedBase/blocs/base_states.dart',
      '''
import 'package:$pkg/error/failures.dart';

/// Mix into the single loading state of each BLoC/Cubit.
/// [BaseView] detects this and shows the loading widget automatically.
///
/// Every BLoC/Cubit has exactly ONE state with this mixin (e.g. AuthLoading).
/// All REST endpoint handlers emit that one state before calling the API.
///
/// WebSocket "connecting" states do NOT use this mixin — they are
/// feature-specific and the developer handles them in [BaseView.onBuild].
mixin AppLoadingState {}

/// Mix into every generated failure state.
/// Carries the full [Failure] object so [BaseView] can distinguish
/// unauthorised / maintenance / network / server errors and treat each
/// differently without any per-feature wiring.
mixin FailureState {
  Failure get failure;
  String get message => failure.message;
}
''',
    );
  }

  Future<void> _writeBaseView(String sharedBase, String pkg) async {
    await FileUtils.writeFile(
      '$sharedBase/widgets/base_view.dart',
      '''
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:$pkg/error/failures.dart';
import 'package:$pkg/navigation/app_router.dart';
import 'package:$pkg/shared/blocs/base_states.dart';
import 'package:$pkg/shared/blocs/theme_cubit.dart';
import 'package:$pkg/shared/theme/app_color_scheme.dart';
import 'package:$pkg/shared/usecases/logout_usecase.dart';

/// Mixin for [State] subclasses that need a BLoC/Cubit and want automatic:
///   • [AppLoadingState]     → blurred loading overlay
///   • [UnAuthorizedFailure] → logout + navigate to [AppRoutes.login]
///   • [ForceUpdateFailure]  → navigate to [AppRoutes.forceUpdate]
///   • [MaintenanceFailure]  → navigate to [AppRoutes.maintenance]
///   • [NetworkFailure]      → floating snack-bar
///   • Other [FailureState]  → floating snack-bar with the server message
///
/// Override [onState] to react to incoming states and call [setState] to
/// update your page's own fields. Build a single, static widget tree in
/// [build] that reads those fields — no switching widgets per state.
///
/// Example:
/// ```dart
/// class _LoginPageState extends State<LoginPage>
///     with BaseViewMixin<LoginBloc, LoginState, LoginPage> {
///
///   String? errorMessage;
///   bool    submitEnabled = true;
///
///   @override
///   void onState(BuildContext context, LoginState state) {
///     if (state is LoginFailure) {
///       setState(() {
///         errorMessage   = state.failure.message;
///         submitEnabled  = true;
///       });
///     }
///     if (state is LoginSuccess) {
///       context.go(AppRoutes.home);
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: Column(
///         children: [
///           if (errorMessage != null) ErrorBanner(errorMessage!),
///           LoginForm(
///             enabled: submitEnabled,
///             onSubmit: (req) {
///               setState(() => submitEnabled = false);
///               context.read<LoginBloc>().add(LoginStarted(req));
///             },
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
mixin BaseViewMixin<B extends BlocBase<S>, S, W extends StatefulWidget> on State<W> {
  bool _loadingShowing = false;
  StreamSubscription<S>? _stateSub;
  B? _currentBloc;

  /// Override to react to BLoC/Cubit state changes.
  ///
  /// Called *after* the built-in loading/failure handling, so you never
  /// need to handle [AppLoadingState] or [FailureState] here yourself.
  /// Use [setState] to update your page's fields.
  void onState(BuildContext context, S state) {}

  /// Re-subscribes whenever the bloc instance provided above this widget
  /// changes (e.g. during navigation, tab switches, or in tests).
  /// This is the correct place to wire up BLoC listeners — [initState] fires
  /// before [InheritedWidget] dependencies are resolved.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBloc = context.read<B>();
    if (_currentBloc != newBloc) {
      _stateSub?.cancel();
      _currentBloc = newBloc;
      _stateSub = newBloc.stream.listen(_onState);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  void _onState(S state) {
    if (!mounted) return;
    if (state is AppLoadingState) {
      _showLoader();
    } else {
      _dismissLoader();
    }
    if (state is FailureState) {
      _handleFailure((state as FailureState).failure);
    }
    onState(context, state);
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  /// Runs [LogoutUseCase] (clears the auth token), resets the theme to
  /// [ThemeMode.system], then navigates to [AppRoutes.login].
  ///
  /// Called automatically on [UnAuthorizedFailure]. Can also be invoked
  /// manually — e.g. from a logout button:
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => BaseViewMixin.logout(context),
  ///   child: const Text('Logout'),
  /// )
  /// ```
  static void logout(BuildContext context) {
    // Fire-and-forget: auth token deletion is non-blocking.
    GetIt.I<LogoutUseCase>()().ignore();
    if (context.mounted) {
      context.read<ThemeCubit>().reset();
      context.go(AppRoutes.login);
    }
  }

  // ── Loader ───────────────────────────────────────────────────────────────

  void _showLoader() {
    if (_loadingShowing) return;
    _loadingShowing = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) {
        return PopScope(
          canPop: false,
          child: Transform.scale(
            scale: a1.value,
            child: Opacity(
              opacity: a1.value,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  alignment: FractionalOffset.center,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Wrap(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(ctx)
                              .extension<AppColorScheme>()!
                              .surface,
                        ),
                        child: CupertinoActivityIndicator(
                          color: Theme.of(ctx)
                              .extension<AppColorScheme>()!
                              .primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  void _dismissLoader() {
    if (!_loadingShowing) return;
    _loadingShowing = false;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  // ── Failure handling ─────────────────────────────────────────────────────

  void _handleFailure(Failure failure) {
    if (!mounted) return;
    switch (failure) {
      case UnAuthorizedFailure():
        BaseViewMixin.logout(context);
      case ForceUpdateFailure():
        context.go(AppRoutes.forceUpdate);
      case MaintenanceFailure():
        context.go(AppRoutes.maintenance);
      case NetworkFailure():
        _showSnackBar('No internet connection. Please try again.');
      default:
        _showSnackBar(failure.message);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
''',
    );
  }
}
