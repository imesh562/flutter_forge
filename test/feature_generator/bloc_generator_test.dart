import 'dart:io';

import 'package:flutter_forge/src/feature_generator/bloc_generator.dart';
import 'package:flutter_forge/src/feature_generator/model_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late BlocGenerator gen;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bloc_gen_test_');
    gen = BlocGenerator();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('BlocGenerator.createBloc', () {
    test('creates bloc, event, state, and test files', () async {
      await gen.createBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
      );

      final presentationDir =
          p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth');
      final testDir =
          p.join(tmp.path, 'test/features/auth/presentation/blocs/auth');

      for (final file in [
        p.join(presentationDir, 'auth_bloc.dart'),
        p.join(presentationDir, 'auth_event.dart'),
        p.join(presentationDir, 'auth_state.dart'),
        p.join(testDir, 'auth_bloc_test.dart'),
      ]) {
        expect(File(file).existsSync(), isTrue, reason: '$file must exist');
      }
    });

    test('bloc file contains correct class name and handler sentinel', () async {
      await gen.createBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_bloc.dart'),
      ).readAsString();

      expect(content, contains('class AuthBloc extends Bloc<AuthEvent, AuthState>'));
      expect(content, contains('// <<HANDLERS>>'));
      expect(content, contains('@injectable'));
    });

    test('event file contains event sentinel and base class', () async {
      await gen.createBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_event.dart'),
      ).readAsString();

      expect(content, contains('// <<EVENTS>>'));
      expect(content, contains('abstract base class AuthEvent extends Equatable'));
    });

    test('state file contains state sentinel, Initial, and Loading states',
        () async {
      await gen.createBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_state.dart'),
      ).readAsString();

      expect(content, contains('// <<STATES>>'));
      expect(content, contains('final class AuthInitial extends AuthState'));
      expect(content, contains('final class AuthLoading extends AuthState with AppLoadingState'));
    });

    test('test file references repository mock and BLoC', () async {
      await gen.createBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
      );

      final content = await File(
        p.join(
          tmp.path,
          'test/features/auth/presentation/blocs/auth/auth_bloc_test.dart',
        ),
      ).readAsString();

      expect(content, contains('class _MockAuthRepository'));
      expect(content, contains('AuthBloc bloc'));
    });
  });

  group('BlocGenerator.createCubit', () {
    test('creates cubit, state, and test files', () async {
      await gen.createCubit(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'profile',
        cubitName: 'profile',
      );

      expect(
        File(p.join(
          tmp.path,
          'lib/features/profile/presentation/cubits/profile/profile_cubit.dart',
        )).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(
          tmp.path,
          'lib/features/profile/presentation/cubits/profile/profile_state.dart',
        )).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(
          tmp.path,
          'test/features/profile/presentation/cubits/profile/profile_cubit_test.dart',
        )).existsSync(),
        isTrue,
      );
    });

    test('cubit file contains handler sentinel', () async {
      await gen.createCubit(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'profile',
        cubitName: 'profile',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/profile/presentation/cubits/profile/profile_cubit.dart',
        ),
      ).readAsString();

      expect(content, contains('class ProfileCubit extends Cubit<ProfileState>'));
      expect(content, contains('// <<HANDLERS>>'));
    });
  });

  group('BlocGenerator.addEventToBloc', () {
    Future<void> _setup() async {
      await gen.createBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
      );
      final modelGen = ModelGenerator();
      await modelGen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [{'name': 'email', 'type': 'String'}],
      );
      await modelGen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [{'name': 'token', 'type': 'String'}],
      );
    }

    test('appends event class to event file', () async {
      await _setup();
      await gen.addEventToBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
        endpointName: 'login',
        requestClass: 'LoginRequest',
        responseClass: 'LoginResponse',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_event.dart'),
      ).readAsString();

      expect(content, contains('final class LoginStarted extends AuthEvent'));
      expect(content, contains('final LoginRequest request;'));
    });

    test('appends Success and Failure states to state file', () async {
      await _setup();
      await gen.addEventToBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
        endpointName: 'login',
        requestClass: 'LoginRequest',
        responseClass: 'LoginResponse',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_state.dart'),
      ).readAsString();

      expect(content, contains('final class LoginSuccess extends AuthState'));
      expect(content, contains('final class LoginFailure extends AuthState with FailureState'));
      expect(content, contains('final LoginResponse data;'));
    });

    test('appends handler registration and method to bloc file', () async {
      await _setup();
      await gen.addEventToBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
        endpointName: 'login',
        requestClass: 'LoginRequest',
        responseClass: 'LoginResponse',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_bloc.dart'),
      ).readAsString();

      expect(content, contains('on<LoginStarted>(_onLogin)'));
      expect(content, contains('Future<void> _onLogin('));
      expect(content, contains('emit(const AuthLoading())'));
    });

    test('throws StateError when sentinel is missing', () async {
      final dir = Directory(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth'),
      );
      await dir.create(recursive: true);

      // Write a file WITHOUT the event sentinel.
      await File(p.join(dir.path, 'auth_event.dart'))
          .writeAsString('// no sentinel here\n');
      await File(p.join(dir.path, 'auth_state.dart'))
          .writeAsString('// <<STATES>>\n');
      await File(p.join(dir.path, 'auth_bloc.dart'))
          .writeAsString('// <<HANDLERS>>\n');

      expect(
        () => gen.addEventToBloc(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'auth',
          blocName: 'auth',
          endpointName: 'login',
          requestClass: 'LoginRequest',
          responseClass: 'LoginResponse',
          endpointType: 'rest',
        ),
        throwsStateError,
      );
    });

    test('generates WebSocket event and connecting state', () async {
      await _setup();
      await gen.addEventToBloc(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        blocName: 'auth',
        endpointName: 'login',
        requestClass: 'LoginRequest',
        responseClass: 'LoginResponse',
        endpointType: 'websocket',
      );

      final eventContent = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_event.dart'),
      ).readAsString();

      expect(
        eventContent,
        contains('final class LoginWebSocketStarted extends AuthEvent'),
      );

      final stateContent = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/blocs/auth/auth_state.dart'),
      ).readAsString();

      expect(
        stateContent,
        contains('final class LoginWebSocketConnecting extends AuthState'),
      );
    });
  });

  group('BlocGenerator.addCustomEventToBloc', () {
    Future<void> _setupBloc() => gen.createBloc(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'profile',
          blocName: 'profile',
        );

    test('adds event with request type, success with data, and handler stub', () async {
      await _setupBloc();
      await gen.addCustomEventToBloc(
        projectPath: tmp.path,
        feature: 'profile',
        blocName: 'profile',
        actionName: 'loadProfile',
        requestType: 'String',
        responseType: 'UserProfile',
      );

      final eventContent = await File(
        p.join(tmp.path, 'lib/features/profile/presentation/blocs/profile/profile_event.dart'),
      ).readAsString();
      expect(eventContent, contains('final class LoadProfileStarted extends ProfileEvent'));
      expect(eventContent, contains('final String request;'));

      final stateContent = await File(
        p.join(tmp.path, 'lib/features/profile/presentation/blocs/profile/profile_state.dart'),
      ).readAsString();
      expect(stateContent, contains('final class LoadProfileSuccess extends ProfileState'));
      expect(stateContent, contains('final UserProfile data;'));
      expect(stateContent, contains('final class LoadProfileFailure extends ProfileState'));

      final blocContent = await File(
        p.join(tmp.path, 'lib/features/profile/presentation/blocs/profile/profile_bloc.dart'),
      ).readAsString();
      expect(blocContent, contains('on<LoadProfileStarted>(_onLoadProfile);'));
      expect(blocContent, contains('Future<void> _onLoadProfile('));
      expect(blocContent, contains('emit(const ProfileLoading())'));
      // Handler is a stub — no real repository call, just TODO
      expect(blocContent, contains('// TODO: replace with the actual repository call'));
    });

    test('adds event with no request type (no-arg event)', () async {
      await _setupBloc();
      await gen.addCustomEventToBloc(
        projectPath: tmp.path,
        feature: 'profile',
        blocName: 'profile',
        actionName: 'refreshProfile',
      );

      final eventContent = await File(
        p.join(tmp.path, 'lib/features/profile/presentation/blocs/profile/profile_event.dart'),
      ).readAsString();
      expect(eventContent, contains('final class RefreshProfileStarted extends ProfileEvent'));
      expect(eventContent, isNot(contains('final  request;')));
      expect(eventContent, contains('List<Object?> get props => const []'));
    });

    test('success state has no data field when responseType is null', () async {
      await _setupBloc();
      await gen.addCustomEventToBloc(
        projectPath: tmp.path,
        feature: 'profile',
        blocName: 'profile',
        actionName: 'clearProfile',
        responseType: null,
      );

      final stateContent = await File(
        p.join(tmp.path, 'lib/features/profile/presentation/blocs/profile/profile_state.dart'),
      ).readAsString();
      expect(stateContent, contains('final class ClearProfileSuccess extends ProfileState'));
      expect(stateContent, isNot(contains('final  data;')));
      expect(stateContent, contains('List<Object?> get props => const []'));
    });

    test('throws StateError when bloc files do not exist', () async {
      expect(
        () => gen.addCustomEventToBloc(
          projectPath: tmp.path,
          feature: 'profile',
          blocName: 'profile',
          actionName: 'loadProfile',
        ),
        throwsStateError,
      );
    });
  });

  group('BlocGenerator.addCustomMethodToCubit', () {
    Future<void> _setupCubit() => gen.createCubit(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'cart',
          cubitName: 'cart',
        );

    test('adds method with request type, success with data, and method stub', () async {
      await _setupCubit();
      await gen.addCustomMethodToCubit(
        projectPath: tmp.path,
        feature: 'cart',
        cubitName: 'cart',
        actionName: 'addItem',
        requestType: 'CartItem',
        responseType: 'Cart',
      );

      final stateContent = await File(
        p.join(tmp.path, 'lib/features/cart/presentation/cubits/cart/cart_state.dart'),
      ).readAsString();
      expect(stateContent, contains('final class AddItemSuccess extends CartState'));
      expect(stateContent, contains('final Cart data;'));
      expect(stateContent, contains('final class AddItemFailure extends CartState'));

      final cubitContent = await File(
        p.join(tmp.path, 'lib/features/cart/presentation/cubits/cart/cart_cubit.dart'),
      ).readAsString();
      expect(cubitContent, contains('Future<void> addItem(CartItem request) async {'));
      expect(cubitContent, contains('emit(const CartLoading())'));
      expect(cubitContent, contains('// TODO: replace with the actual repository call'));
    });

    test('adds no-arg method when requestType is null', () async {
      await _setupCubit();
      await gen.addCustomMethodToCubit(
        projectPath: tmp.path,
        feature: 'cart',
        cubitName: 'cart',
        actionName: 'clearCart',
      );

      final cubitContent = await File(
        p.join(tmp.path, 'lib/features/cart/presentation/cubits/cart/cart_cubit.dart'),
      ).readAsString();
      expect(cubitContent, contains('Future<void> clearCart() async {'));
    });

    test('throws StateError when cubit files do not exist', () async {
      expect(
        () => gen.addCustomMethodToCubit(
          projectPath: tmp.path,
          feature: 'cart',
          cubitName: 'cart',
          actionName: 'addItem',
        ),
        throwsStateError,
      );
    });
  });
}
