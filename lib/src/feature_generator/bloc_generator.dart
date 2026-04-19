import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

/// Generates or additively updates BLoC and Cubit files.
/// Sentinel comments in the generated code mark safe insertion points.
final class BlocGenerator {
  static const _eventsSentinel = '// <<EVENTS>>';
  static const _stateSentinel = '// <<STATES>>';
  static const _handlerSentinel = '// <<HANDLERS>>';

  Future<void> createBloc({
    required String projectPath,
    required String pkg,
    required String feature,
    required String blocName,
  }) async {
    final pascal = StringUtils.toPascalCase(blocName);
    final snake = StringUtils.toSnakeCase(blocName);
    final featurePascal = StringUtils.toPascalCase(feature);
    final featureSnake = StringUtils.toSnakeCase(feature);
    final dir = p.join(projectPath, 'lib/features/$feature/presentation');

    final testDir = p.join(
      projectPath,
      'test/features/$feature/presentation',
    );

    await Future.wait([
      _writeBlocBase(
        dir: dir,
        pkg: pkg,
        feature: feature,
        pascal: pascal,
        snake: snake,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
      ),
      _writeBlocEvents(dir: dir, pascal: pascal, snake: snake),
      _writeBlocStates(dir: dir, pascal: pascal, snake: snake),
      _writeBlocTest(
        testDir: testDir,
        pkg: pkg,
        feature: feature,
        pascal: pascal,
        snake: snake,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
      ),
    ]);
  }

  Future<void> createCubit({
    required String projectPath,
    required String pkg,
    required String feature,
    required String cubitName,
  }) async {
    final pascal = StringUtils.toPascalCase(cubitName);
    final snake = StringUtils.toSnakeCase(cubitName);
    final featurePascal = StringUtils.toPascalCase(feature);
    final featureSnake = StringUtils.toSnakeCase(feature);
    final dir = p.join(projectPath, 'lib/features/$feature/presentation');

    final testDir = p.join(
      projectPath,
      'test/features/$feature/presentation',
    );

    await Future.wait([
      _writeCubit(
        dir: dir,
        pkg: pkg,
        feature: feature,
        pascal: pascal,
        snake: snake,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
      ),
      _writeCubitTest(
        testDir: testDir,
        pkg: pkg,
        feature: feature,
        pascal: pascal,
        snake: snake,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
      ),
    ]);
  }

  // ── Additive operations ────────────────────────────────────────────────────

  Future<void> addEventToBloc({
    required String projectPath,
    required String pkg,
    required String feature,
    required String blocName,
    required String endpointName,
    required String requestClass,
    required String responseClass,
    required String endpointType, // 'rest' | 'websocket'
  }) async {
    final blocPascal = StringUtils.toPascalCase(blocName);
    final endpointPascal = StringUtils.toPascalCase(endpointName);
    final endpointCamel = StringUtils.toCamelCase(endpointName);
    final snake = StringUtils.toSnakeCase(blocName);
    final requestSnake = '${StringUtils.toSnakeCase(endpointName)}_request';
    final responseSnake = '${StringUtils.toSnakeCase(endpointName)}_response';
    final dir = p.join(projectPath, 'lib/features/$feature/presentation');

    final eventsFile = p.join(dir, '${snake}_event.dart');
    final statesFile = p.join(dir, '${snake}_state.dart');
    final blocFile = p.join(dir, '${snake}_bloc.dart');

    for (final path in [eventsFile, statesFile, blocFile]) {
      if (!File(path).existsSync()) {
        throw StateError(
          'BLoC file not found: $path\n'
          'Run the generator to create the BLoC first.',
        );
      }
    }

    await Future.wait([
      _addEvent(
        eventsFile,
        endpointPascal,
        requestClass,
        blocPascal,
        endpointType,
      ),
      _addState(
        statesFile,
        endpointPascal,
        responseClass,
        blocPascal,
        endpointType,
      ),
      _addHandler(
        filePath: blocFile,
        pkg: pkg,
        feature: feature,
        endpointPascal: endpointPascal,
        endpointCamel: endpointCamel,
        blocPascal: blocPascal,
        requestClass: requestClass,
        responseClass: responseClass,
        requestSnake: requestSnake,
        responseSnake: responseSnake,
        endpointType: endpointType,
      ),
    ]);
  }

  Future<void> addMethodToCubit({
    required String projectPath,
    required String pkg,
    required String feature,
    required String cubitName,
    required String endpointName,
    required String requestClass,
    required String responseClass,
    required String endpointType, // 'rest' | 'websocket'
  }) async {
    final cubitPascal = StringUtils.toPascalCase(cubitName);
    final endpointPascal = StringUtils.toPascalCase(endpointName);
    final endpointCamel = StringUtils.toCamelCase(endpointName);
    final snake = StringUtils.toSnakeCase(cubitName);
    final requestSnake = '${StringUtils.toSnakeCase(endpointName)}_request';
    final responseSnake = '${StringUtils.toSnakeCase(endpointName)}_response';
    final dir = p.join(projectPath, 'lib/features/$feature/presentation');

    final cubitFile = p.join(dir, '${snake}_cubit.dart');
    final statesFile = p.join(dir, '${snake}_state.dart');

    for (final path in [cubitFile, statesFile]) {
      if (!File(path).existsSync()) {
        throw StateError('Cubit file not found: $path');
      }
    }

    await Future.wait([
      _addCubitState(
        statesFile,
        endpointPascal,
        responseClass,
        cubitPascal,
        endpointType,
      ),
      _addCubitMethod(
        filePath: cubitFile,
        pkg: pkg,
        feature: feature,
        endpointPascal: endpointPascal,
        endpointCamel: endpointCamel,
        cubitPascal: cubitPascal,
        requestClass: requestClass,
        responseClass: responseClass,
        requestSnake: requestSnake,
        responseSnake: responseSnake,
        endpointType: endpointType,
      ),
    ]);
  }

  // ── BLoC creation helpers ─────────────────────────────────────────────────

  Future<void> _writeBlocBase({
    required String dir,
    required String pkg,
    required String feature,
    required String pascal,
    required String snake,
    required String featurePascal,
    required String featureSnake,
  }) async {
    await FileUtils.writeFile(
      p.join(dir, '${snake}_bloc.dart'),
      '''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:$pkg/error/failures.dart';
import 'package:$pkg/features/$feature/domain/repositories/${featureSnake}_repository.dart';
import 'package:$pkg/shared/blocs/base_states.dart';

part '${snake}_event.dart';
part '${snake}_state.dart';

@injectable
class ${pascal}Bloc extends Bloc<${pascal}Event, ${pascal}State> {
  ${pascal}Bloc(this._repository) : super(const ${pascal}Initial()) {
    $_handlerSentinel
  }

  final ${featurePascal}Repository _repository;
}
''',
    );
  }

  Future<void> _writeBlocEvents({
    required String dir,
    required String pascal,
    required String snake,
  }) async {
    await FileUtils.writeFile(
      p.join(dir, '${snake}_event.dart'),
      '''
part of '${snake}_bloc.dart';

$_eventsSentinel
abstract base class ${pascal}Event extends Equatable {
  const ${pascal}Event();
}
''',
    );
  }

  Future<void> _writeBlocStates({
    required String dir,
    required String pascal,
    required String snake,
  }) async {
    await FileUtils.writeFile(
      p.join(dir, '${snake}_state.dart'),
      '''
part of '${snake}_bloc.dart';

$_stateSentinel
abstract base class ${pascal}State extends Equatable {
  const ${pascal}State();
}

final class ${pascal}Initial extends ${pascal}State {
  const ${pascal}Initial();
  @override
  List<Object?> get props => const [];
}

/// Single shared loading state for this BLoC.
/// Emitted by every REST endpoint handler before the API call.
/// [BaseViewMixin] detects [AppLoadingState] and shows the loading overlay.
final class ${pascal}Loading extends ${pascal}State with AppLoadingState {
  const ${pascal}Loading();
  @override
  List<Object?> get props => const [];
}
''',
    );
  }

  // ── Cubit creation helpers ─────────────────────────────────────────────────

  Future<void> _writeCubit({
    required String dir,
    required String pkg,
    required String feature,
    required String pascal,
    required String snake,
    required String featurePascal,
    required String featureSnake,
  }) async {
    await Future.wait([
      FileUtils.writeFile(
        p.join(dir, '${snake}_cubit.dart'),
        '''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:$pkg/error/failures.dart';
import 'package:$pkg/features/$feature/domain/repositories/${featureSnake}_repository.dart';
import 'package:$pkg/shared/blocs/base_states.dart';

part '${snake}_state.dart';

@injectable
class ${pascal}Cubit extends Cubit<${pascal}State> {
  ${pascal}Cubit(this._repository) : super(const ${pascal}Initial());

  final ${featurePascal}Repository _repository;

  $_handlerSentinel
}
''',
      ),
      FileUtils.writeFile(
        p.join(dir, '${snake}_state.dart'),
        '''
part of '${snake}_cubit.dart';

$_stateSentinel
abstract base class ${pascal}State extends Equatable {
  const ${pascal}State();
}

final class ${pascal}Initial extends ${pascal}State {
  const ${pascal}Initial();
  @override
  List<Object?> get props => const [];
}

/// Single shared loading state for this Cubit.
/// Emitted by every REST method before the API call.
/// [BaseViewMixin] detects [AppLoadingState] and shows the loading overlay.
final class ${pascal}Loading extends ${pascal}State with AppLoadingState {
  const ${pascal}Loading();
  @override
  List<Object?> get props => const [];
}
''',
      ),
    ]);
  }

  // ── Additive helpers ──────────────────────────────────────────────────────

  Future<void> _addEvent(
    String filePath,
    String endpointPascal,
    String requestClass,
    String blocPascal,
    String endpointType,
  ) async {
    await FileUtils.patchFile(filePath, (content) {
      _assertSentinel(content, _eventsSentinel, filePath);
      final String newEvent;
      if (endpointType == 'websocket') {
        newEvent =
            'final class ${endpointPascal}WebSocketStarted extends ${blocPascal}Event {\n'
            '  const ${endpointPascal}WebSocketStarted();\n'
            '  @override\n'
            '  List<Object?> get props => const [];\n'
            '}\n\n';
      } else {
        newEvent =
            'final class ${endpointPascal}Started extends ${blocPascal}Event {\n'
            '  const ${endpointPascal}Started(this.request);\n'
            '  final $requestClass request;\n'
            '  @override\n'
            '  List<Object?> get props => [request];\n'
            '}\n\n';
      }
      return content.replaceFirst(
        _eventsSentinel,
        '$_eventsSentinel\n$newEvent',
      );
    });
  }

  Future<void> _addState(
    String filePath,
    String endpointPascal,
    String responseClass,
    String blocPascal,
    String endpointType,
  ) async {
    await FileUtils.patchFile(filePath, (content) {
      _assertSentinel(content, _stateSentinel, filePath);
      final String newStates;
      if (endpointType == 'websocket') {
        // WebSocket: Connecting (NOT AppLoadingState — BaseViewMixin ignores it)
        // + Success + Failure.
        newStates =
            '/// Emitted while the WebSocket connection is being established.\n'
            '/// Not handled by BaseViewMixin — the UI reacts to this manually.\n'
            'final class ${endpointPascal}WebSocketConnecting extends ${blocPascal}State {\n'
            '  const ${endpointPascal}WebSocketConnecting();\n'
            '  @override\n'
            '  List<Object?> get props => const [];\n'
            '}\n\n'
            'final class ${endpointPascal}Success extends ${blocPascal}State {\n'
            '  const ${endpointPascal}Success(this.data);\n'
            '  final $responseClass data;\n'
            '  @override\n'
            '  List<Object?> get props => [data];\n'
            '}\n\n'
            'final class ${endpointPascal}Failure extends ${blocPascal}State with FailureState {\n'
            '  const ${endpointPascal}Failure(this.failure);\n'
            '  @override\n'
            '  final Failure failure;\n'
            '  @override\n'
            '  List<Object?> get props => [failure];\n'
            '}\n\n';
      } else {
        // REST: Success + Failure only; AppLoadingState is on the BLoC itself.
        newStates =
            'final class ${endpointPascal}Success extends ${blocPascal}State {\n'
            '  const ${endpointPascal}Success(this.data);\n'
            '  final $responseClass data;\n'
            '  @override\n'
            '  List<Object?> get props => [data];\n'
            '}\n\n'
            'final class ${endpointPascal}Failure extends ${blocPascal}State with FailureState {\n'
            '  const ${endpointPascal}Failure(this.failure);\n'
            '  @override\n'
            '  final Failure failure;\n'
            '  @override\n'
            '  List<Object?> get props => [failure];\n'
            '}\n\n';
      }
      return content.replaceFirst(
        _stateSentinel,
        '$_stateSentinel\n$newStates',
      );
    });
  }

  Future<void> _addHandler({
    required String filePath,
    required String pkg,
    required String feature,
    required String endpointPascal,
    required String endpointCamel,
    required String blocPascal,
    required String requestClass,
    required String responseClass,
    required String requestSnake,
    required String responseSnake,
    required String endpointType,
  }) async {
    await FileUtils.patchFile(filePath, (content) {
      _assertSentinel(content, _handlerSentinel, filePath);

      // Add model imports before the first `part` directive if not present.
      var updated = content;
      if (!updated.contains("'../data/models/$requestSnake.dart'")) {
        updated = updated.replaceFirst(
          '\npart ',
          "\nimport '../data/models/$requestSnake.dart';"
          "\nimport '../data/models/$responseSnake.dart';\n\npart ",
        );
      }

      final String registration;
      final String handler;

      if (endpointType == 'websocket') {
        // Inject fpdart import so Either is resolvable in the handler.
        if (!updated.contains("'package:fpdart/fpdart.dart'")) {
          updated = updated.replaceFirst(
            '\npart ',
            "\nimport 'package:fpdart/fpdart.dart';\n\npart ",
          );
        }
        registration =
            'on<${endpointPascal}WebSocketStarted>(_on${endpointPascal}WebSocket);';
        handler =
            '\n  Future<void> _on${endpointPascal}WebSocket(\n'
            '    ${endpointPascal}WebSocketStarted event,\n'
            '    Emitter<${blocPascal}State> emit,\n'
            '  ) async {\n'
            '    emit(const ${endpointPascal}WebSocketConnecting());\n'
            '    await emit.forEach(\n'
            '      _repository.$endpointCamel(),\n'
            '      onData: (either) => either.fold(\n'
            '        (failure) => ${endpointPascal}Failure(failure),\n'
            '        (data) => ${endpointPascal}Success(data),\n'
            '      ),\n'
            '    );\n'
            '  }\n';
      } else {
        registration =
            'on<${endpointPascal}Started>(_on$endpointPascal);';
        handler =
            '\n  Future<void> _on$endpointPascal(\n'
            '    ${endpointPascal}Started event,\n'
            '    Emitter<${blocPascal}State> emit,\n'
            '  ) async {\n'
            '    emit(const ${blocPascal}Loading());\n'
            '    final result = await _repository.$endpointCamel(event.request);\n'
            '    result.fold(\n'
            '      (failure) => emit(${endpointPascal}Failure(failure)),\n'
            '      (data) => emit(${endpointPascal}Success(data)),\n'
            '    );\n'
            '  }\n';
      }

      return updated
          .replaceFirst(
            _handlerSentinel,
            '$_handlerSentinel\n    $registration',
          )
          .replaceFirst(RegExp(r'\}\s*$'), '$handler}\n');
    });
  }

  Future<void> _addCubitState(
    String filePath,
    String endpointPascal,
    String responseClass,
    String cubitPascal,
    String endpointType,
  ) async {
    await FileUtils.patchFile(filePath, (content) {
      _assertSentinel(content, _stateSentinel, filePath);
      final String newStates;
      if (endpointType == 'websocket') {
        newStates =
            '/// Emitted while the WebSocket connection is being established.\n'
            '/// Not handled by BaseViewMixin — the UI reacts to this manually.\n'
            'final class ${endpointPascal}WebSocketConnecting extends ${cubitPascal}State {\n'
            '  const ${endpointPascal}WebSocketConnecting();\n'
            '  @override\n'
            '  List<Object?> get props => const [];\n'
            '}\n\n'
            'final class ${endpointPascal}Success extends ${cubitPascal}State {\n'
            '  const ${endpointPascal}Success(this.data);\n'
            '  final $responseClass data;\n'
            '  @override\n'
            '  List<Object?> get props => [data];\n'
            '}\n\n'
            'final class ${endpointPascal}Failure extends ${cubitPascal}State with FailureState {\n'
            '  const ${endpointPascal}Failure(this.failure);\n'
            '  @override\n'
            '  final Failure failure;\n'
            '  @override\n'
            '  List<Object?> get props => [failure];\n'
            '}\n\n';
      } else {
        newStates =
            'final class ${endpointPascal}Success extends ${cubitPascal}State {\n'
            '  const ${endpointPascal}Success(this.data);\n'
            '  final $responseClass data;\n'
            '  @override\n'
            '  List<Object?> get props => [data];\n'
            '}\n\n'
            'final class ${endpointPascal}Failure extends ${cubitPascal}State with FailureState {\n'
            '  const ${endpointPascal}Failure(this.failure);\n'
            '  @override\n'
            '  final Failure failure;\n'
            '  @override\n'
            '  List<Object?> get props => [failure];\n'
            '}\n\n';
      }
      return content.replaceFirst(
        _stateSentinel,
        '$_stateSentinel\n$newStates',
      );
    });
  }

  Future<void> _addCubitMethod({
    required String filePath,
    required String pkg,
    required String feature,
    required String endpointPascal,
    required String endpointCamel,
    required String cubitPascal,
    required String requestClass,
    required String responseClass,
    required String requestSnake,
    required String responseSnake,
    required String endpointType,
  }) async {
    await FileUtils.patchFile(filePath, (content) {
      _assertSentinel(content, _handlerSentinel, filePath);

      // Add model imports before the first `part` directive if not present.
      var updated = content;
      if (!updated.contains("'../data/models/$requestSnake.dart'")) {
        updated = updated.replaceFirst(
          '\npart ',
          "\nimport '../data/models/$requestSnake.dart';"
          "\nimport '../data/models/$responseSnake.dart';\n\npart ",
        );
      }

      final String newMethod;
      if (endpointType == 'websocket') {
        // Inject fpdart import so Either is resolvable in the method.
        if (!updated.contains("'package:fpdart/fpdart.dart'")) {
          updated = updated.replaceFirst(
            '\npart ',
            "\nimport 'package:fpdart/fpdart.dart';\n\npart ",
          );
        }
        newMethod =
            '  Future<void> $endpointCamel() async {\n'
            '    emit(const ${endpointPascal}WebSocketConnecting());\n'
            '    await for (final either in _repository.$endpointCamel()) {\n'
            '      either.fold(\n'
            '        (failure) => emit(${endpointPascal}Failure(failure)),\n'
            '        (data) => emit(${endpointPascal}Success(data)),\n'
            '      );\n'
            '    }\n'
            '  }\n\n';
      } else {
        newMethod =
            '  Future<void> $endpointCamel($requestClass request) async {\n'
            '    emit(const ${cubitPascal}Loading());\n'
            '    final result = await _repository.$endpointCamel(request);\n'
            '    result.fold(\n'
            '      (failure) => emit(${endpointPascal}Failure(failure)),\n'
            '      (data) => emit(${endpointPascal}Success(data)),\n'
            '    );\n'
            '  }\n\n';
      }
      return updated.replaceFirst(
        _handlerSentinel,
        '$_handlerSentinel\n$newMethod',
      );
    });
  }

  // ── Test scaffolds ────────────────────────────────────────────────────────

  Future<void> _writeBlocTest({
    required String testDir,
    required String pkg,
    required String feature,
    required String pascal,
    required String snake,
    required String featurePascal,
    required String featureSnake,
  }) async {
    await FileUtils.writeFile(
      p.join(testDir, '${snake}_bloc_test.dart'),
      '''
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:$pkg/features/$feature/domain/repositories/${featureSnake}_repository.dart';
import 'package:$pkg/features/$feature/presentation/${snake}_bloc.dart';

class _Mock${featurePascal}Repository extends Mock
    implements ${featurePascal}Repository {}

void main() {
  late ${featurePascal}Repository repository;
  late ${pascal}Bloc bloc;

  setUp(() {
    repository = _Mock${featurePascal}Repository();
    bloc = ${pascal}Bloc(repository);
  });

  tearDown(() => bloc.close());

  group('${pascal}Bloc', () {
    test('initial state is ${pascal}Initial', () {
      expect(bloc.state, isA<${pascal}Initial>());
    });

    // TODO: add blocTest<${pascal}Bloc, ${pascal}State> cases for each endpoint.
    // Example:
    //
    // blocTest<${pascal}Bloc, ${pascal}State>(
    //   'emits [${pascal}Loading, LoginSuccess] when LoginStarted succeeds',
    //   build: () {
    //     when(() => repository.login(any()))
    //         .thenAnswer((_) async => const Right(LoginResponse(...)));
    //     return bloc;
    //   },
    //   act: (b) => b.add(LoginStarted(const LoginRequest(...))),
    //   expect: () => [
    //     isA<${pascal}Loading>(),
    //     isA<LoginSuccess>(),
    //   ],
    // );
  });
}
''',
    );
  }

  Future<void> _writeCubitTest({
    required String testDir,
    required String pkg,
    required String feature,
    required String pascal,
    required String snake,
    required String featurePascal,
    required String featureSnake,
  }) async {
    await FileUtils.writeFile(
      p.join(testDir, '${snake}_cubit_test.dart'),
      '''
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:$pkg/features/$feature/domain/repositories/${featureSnake}_repository.dart';
import 'package:$pkg/features/$feature/presentation/${snake}_cubit.dart';

class _Mock${featurePascal}Repository extends Mock
    implements ${featurePascal}Repository {}

void main() {
  late ${featurePascal}Repository repository;
  late ${pascal}Cubit cubit;

  setUp(() {
    repository = _Mock${featurePascal}Repository();
    cubit = ${pascal}Cubit(repository);
  });

  tearDown(() => cubit.close());

  group('${pascal}Cubit', () {
    test('initial state is ${pascal}Initial', () {
      expect(cubit.state, isA<${pascal}Initial>());
    });

    // TODO: add blocTest<${pascal}Cubit, ${pascal}State> cases for each method.
    // Example:
    //
    // blocTest<${pascal}Cubit, ${pascal}State>(
    //   'emits [${pascal}Loading, LoginSuccess] when login succeeds',
    //   build: () {
    //     when(() => repository.login(any()))
    //         .thenAnswer((_) async => const Right(LoginResponse(...)));
    //     return cubit;
    //   },
    //   act: (c) => c.login(const LoginRequest(...)),
    //   expect: () => [
    //     isA<${pascal}Loading>(),
    //     isA<LoginSuccess>(),
    //   ],
    // );
  });
}
''',
    );
  }

  void _assertSentinel(String content, String sentinel, String filePath) {
    if (!content.contains(sentinel)) {
      throw StateError(
        'Sentinel "$sentinel" not found in $filePath.\n'
        'The file may have been manually edited. Add the sentinel '
        'comment to re-enable additive generation.',
      );
    }
  }
}
