# Changelog

All notable changes to **flutter_forge** are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

---

## [1.0.0] — 2026-04-14

### Added

#### Phase 1–3 · Project Scaffold (`dart run bin/flutter_forge.dart`)

- **Interactive project wizard** (`ProjectWizard`) — collects project name, app display name, output directory, and per-flavor settings with inline validation before writing any files.
- **Four-flavor support** — DEV, STG, PRE_PROD, and PROD; each flavor captures its own bundle / package ID, base API URL, WebSocket URL, Firebase config, and Mixpanel token.
- **Guard against overwriting** — aborts early with a clear error if the target directory already exists.
- **14-step scaffold pipeline** with progress output:
  1. `flutter create` with org identifier derived from the DEV bundle ID.
  2. Removal of the default `lib/main.dart` entrypoint.
  3. Clean Architecture directory tree (`StructureGenerator`).
  4. `pubspec.yaml` generation with all required dependencies (`PubspecGenerator`).
  5. `analysis_options.yaml` using `very_good_analysis` lint rules with `public_member_api_docs` disabled (`AnalysisOptionsGenerator`).
  6. Per-flavor entrypoints — `main_dev.dart`, `main_stg.dart`, `main_pre_prod.dart`, `main_prod.dart` (`EntrypointGenerator`).
  7. Exception hierarchy (`ExceptionGenerator`).
  8. Networking layer with `ApiHelper` (real) and `MockApiHelper` (DEV) wired through DI (`NetworkingGenerator`).
  9. Storage services (`StorageGenerator`).
  10. Firebase & push notification services (`FirebaseGenerator`).
  11. Analytics — `CompositeAnalyticsService` fanning out to Firebase Analytics and Mixpanel (`AnalyticsGenerator`).
  12. Navigation using `go_router` with `StatefulShellRoute` for main tabs and separate routes for auth/onboarding (`NavigationGenerator`).
  13. Dependency injection via `get_it` + `injectable`; DEV environment resolves `MockApiHelper`, all other environments resolve `ApiHelper` (`DiGenerator`).
  14. Theme and shared providers (`ThemeGenerator`).
- **Android build file patches** — flavor-specific `applicationId`, `versionCode`, and `versionName` in `build.gradle` (`AndroidGenerator`).
- **VS Code run configurations** — one launch configuration per flavor, written to `.vscode/launch.json` (`VscodeGenerator`).
- **`codegen_registry.json`** — initialised at project root to track all generated features, BLoCs, Cubits, and endpoints.
- **`flutter pub get`** run automatically at the end of the scaffold.
- **Next-steps summary** printed on success, covering Firebase config files, `build_runner`, flavor launch commands, and the additive generator.

#### Phase 4 · Additive Feature Generator (`dart run bin/generate.dart [project_path]`)

- **`FeatureWizard`** — interactive CLI with four generation modes:
  1. **Endpoint** (REST or WebSocket) — prompts for endpoint name, HTTP method (GET / POST / PUT / PATCH / DELETE), URL path, request fields, and response fields; generates typed request/response model classes, adds a method to the data-source and repository layers, and wires the call into a BLoC or Cubit.
  2. **Feature scaffold** — creates the full Clean Architecture folder tree for a new feature (`presentation/pages`, `presentation/widgets`, `domain/entities`, `domain/repositories`, `domain/usecases`, `data/models`, `data/datasources`, `data/repositories`).
  3. **Empty widget** — scaffolds a `StatelessWidget` stub in the correct feature's `presentation/widgets/` directory.
  4. **Empty screen (page)** — scaffolds a `StatelessWidget`/`Scaffold` stub in the correct feature's `presentation/pages/` directory.
- **`BlocGenerator`** — creates new BLoC or Cubit files and additively injects events/states/handlers via sentinel comments (`// <<EVENTS>>`, `// <<STATES>>`, `// <<HANDLERS>>`); also supports `addEventToBloc` and `addMethodToCubit` for wiring endpoints into existing state-management files.
- **`ModelGenerator`** — generates `@JsonSerializable` request and response model classes.
- **`DatasourceGenerator`** — adds typed REST or WebSocket methods to the feature's data-source.
- **`RepositoryGenerator`** — adds matching method stubs to the feature's repository interface and implementation.
- **`RegistryManager`** — reads and writes `codegen_registry.json`; tracks features, BLoCs, Cubits, and endpoints; prevents duplicate generation.
- **Package name auto-detection** — extracts `name:` from the target project's `pubspec.yaml` so generated imports are always correct.
- **Guard against missing registry** — prints an actionable error and exits if `codegen_registry.json` is not found in the target directory.

#### Utilities & Models

- **`StringUtils`** — `toPascalCase`, `toSnakeCase`, `isSnakeCase`, `isValidBundleId`, `isValidUrl`, `isValidWsUrl`, `extractOrg`.
- **`FileUtils`** — `writeFile`, `writeJson`, `ensureDir`, `deleteIfExists`.
- **`ProcessUtils`** — `run` wrapper around `dart:io` `Process` with live stdout/stderr streaming and non-zero exit-code throwing.
- **`ProjectConfig`**, **`FlavorConfig`** / `FlavorSettings`, **`FirebaseConfig`** — strongly-typed value objects for all wizard-collected data.

[Unreleased]: https://github.com/your-org/flutter_forge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/your-org/flutter_forge/releases/tag/v1.0.0
