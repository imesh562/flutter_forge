# flutter_forge

A powerful CLI toolkit to **scaffold, scale, and maintain production-grade Flutter applications** using Clean Architecture, BLoC/Cubit, and automated code generation.

---

## ⚙️ Installation

### 1. Clone the Repository

```bash
git clone <your-repo-url> ~/tools/flutter_forge
cd ~/tools/flutter_forge
```

---

### 2. Activate Globally

```bash
dart pub global activate --source path .
```

---

### 3. Add to PATH

**macOS**

```bash
export PATH="$HOME/.pub-cache/bin:$PATH"
source ~/.zshrc
```

**Windows**
Add this to your user PATH:

```
C:\Users\<YourUser>\AppData\Local\Pub\Cache\bin
```

---

### 4. Verify Installation

```bash
flutter_forge --version
flutter_forge_generate --version
flutter_forge_color --version
```

---

## 🚀 Quick Start (How to Use)

Once installed, you will primarily use **three commands**:

```bash
flutter_forge
```

➡️ Creates a **new Flutter project** with full architecture, flavors, and setup.

```bash
flutter_forge_generate
```

➡️ Adds **features, APIs, screens, widgets, and models** to your project.

```bash
flutter_forge_color
```

➡️ Manages **app color tokens** (light/dark themes).

---

## 📘 Full Tutorial

👉 Follow the complete step-by-step guide here:
https://docs.google.com/document/d/1ycJFqUP7yTUJYBbgxLV9prcv68uTpzYFV7rEfAh6kyk/edit?usp=sharing

---

## 🏗️ What flutter_forge Generates

Running:

```bash
flutter_forge
```

Creates a complete, production-ready Flutter project:

```
my_app/
├── lib/
│   ├── core/           # DI, configs, exceptions
│   ├── features/       # Feature-based modules
│   ├── navigation/     # Routing (go_router)
│   ├── shared/         # Shared UI + theme
│   └── main_dev.dart   # Entry points (flavors)
├── android/            # Flavor-configured builds
├── ios/                # Xcode schemes (macOS)
├── .vscode/            # Run configs
└── codegen_registry.json
```

---

## 🔧 Core Features

* ✅ Clean Architecture (data / domain / presentation)
* ✅ BLoC / Cubit state management
* ✅ Flavor support (DEV / STG / PROD)
* ✅ API + WebSocket scaffolding
* ✅ Auto code generation (Freezed, models)
* ✅ Dependency Injection setup
* ✅ Navigation (go_router)
* ✅ Theme & color token system
* ✅ VS Code ready-to-run configs

---

## 🧩 Feature Generation

Run inside your project:

```bash
flutter_forge_generate
```

You can:

* Generate API endpoints
* Create full features
* Add screens & widgets
* Update models
* Rename/delete features
* Manage color tokens

---

## 🎨 Color Token Management

```bash
flutter_forge_color add primary "#FFFFFF" "#000000"
flutter_forge_color update primary --light="#F0F0F0"
flutter_forge_color remove primary
flutter_forge_color list
```

Use in Flutter:

```dart
context.appColors.primary
```

---

## ▶️ Running Your App

After project creation:

```bash
cd my_app
dart run build_runner build --delete-conflicting-outputs
```

Run app:

```bash
# With flavors
flutter run --flavor dev --target lib/main_dev.dart

# Without flavors
flutter run
```

---

## 🔄 Updating the Tool

After pulling updates:

```bash
dart pub global activate --source path .
```

---

## 🛠️ Troubleshooting

| Issue                 | Fix                     |
| --------------------- | ----------------------- |
| Command not found     | Add pub cache to PATH   |
| Missing registry file | Run inside project root |
| Build errors          | Run build_runner        |
| iOS issues on Windows | Configure on macOS      |
| Flutter issues        | Run `flutter doctor`    |

---

## 📌 Summary

**Workflow:**

1. Create project → `flutter_forge`
2. Build features → `flutter_forge_generate`
3. Manage UI theme → `flutter_forge_color`

---

## 📄 License

This project is licensed under the MIT License.

---

## 🤝 Contributing

Contributions are welcome. Open issues or submit pull requests.

---
