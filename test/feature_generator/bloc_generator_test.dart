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
          p.join(tmp.path, 'lib/features/auth/presentation');
      final testDir =
          p.join(tmp.path, 'test/features/auth/presentation');

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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_bloc.dart'),
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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_event.dart'),
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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_state.dart'),
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
          'test/features/auth/presentation/auth_bloc_test.dart',
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
          'lib/features/profile/presentation/profile_cubit.dart',
        )).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(
          tmp.path,
          'lib/features/profile/presentation/profile_state.dart',
        )).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(
          tmp.path,
          'test/features/profile/presentation/profile_cubit_test.dart',
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
          'lib/features/profile/presentation/profile_cubit.dart',
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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_event.dart'),
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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_state.dart'),
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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_bloc.dart'),
      ).readAsString();

      expect(content, contains('on<LoginStarted>(_onLogin)'));
      expect(content, contains('Future<void> _onLogin('));
      expect(content, contains('emit(const AuthLoading())'));
    });

    test('throws StateError when sentinel is missing', () async {
      final dir = Directory(
        p.join(tmp.path, 'lib/features/auth/presentation'),
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
        p.join(tmp.path, 'lib/features/auth/presentation/auth_event.dart'),
      ).readAsString();

      expect(
        eventContent,
        contains('final class LoginWebSocketStarted extends AuthEvent'),
      );

      final stateContent = await File(
        p.join(tmp.path, 'lib/features/auth/presentation/auth_state.dart'),
      ).readAsString();

      expect(
        stateContent,
        contains('final class LoginWebSocketConnecting extends AuthState'),
      );
    });
  });
}
