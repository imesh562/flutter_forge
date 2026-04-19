# ⚒️ flutter_forge

**Stop writing boilerplate. Start building products.**

---

## ⚡ Quick Start (2-minute setup)

```bash
# 1. Activate the CLI (example)
dart pub global activate flutter_forge

# 2. Create a new production-ready Flutter project
flutter_forge

# 3. Navigate into your project
cd your_project_name

# 4. Generate your first feature
flutter_forge_generate

# 5. Run the app
flutter run --flavor dev
```

📚 **Full step-by-step tutorial:**
https://docs.google.com/document/d/1ycJFqUP7yTUJYBbgxLV9prcv68uTpzYFV7rEfAh6kyk/edit?usp=sharing

---

## 🚀 What is flutter_forge?

flutter_forge is a powerful CLI tool that generates **production-ready Flutter applications and features in seconds** — using Clean Architecture, best practices, and consistent patterns out of the box.

---

## 🚀 Why flutter_forge?

Every Flutter project starts the same way:

* Setting up folders
* Wiring dependency injection
* Creating repositories, models, BLoC/Cubit
* Configuring flavors, networking, storage

That’s hours (or days) of work… repeated every single time.

flutter_forge eliminates that entire phase.

👉 Generate full projects and features instantly
👉 Enforce consistent architecture across teams
👉 Reduce bugs caused by manual boilerplate
👉 Let developers focus on real business logic

---

## ✨ What it does

### 🏗 Project Scaffolding

* Clean Architecture (domain, data, presentation)
* DI setup (GetIt + injectable)
* Networking (Dio + error handling)
* Storage layer (secure + local)
* GoRouter navigation
* Light/Dark theming
* Build flavors (dev, stg, preProd, prod)
* Optional Firebase integration

### ⚡ Feature Generation

* Full feature structure (datasource, repository, BLoC/Cubit)
* API endpoint generation (models + wiring)
* Auto DI registration
* Auto route registration
* Safe, non-destructive updates

### 🎯 Smart Developer Experience

* Interactive CLI wizard
* Additive code generation (never overwrite your work)
* Registry tracking for all generated artifacts
* Built-in conventions for scalable teams

---

## 🧠 Philosophy

flutter_forge is **not a framework**.

It generates clean, production-ready Flutter code that:

* You fully own
* You can modify freely
* Has **zero runtime dependency** on the tool

---

## ⚙️ Example Workflow

```bash
# Create a new project
flutter_forge

# Generate a new feature
flutter_forge_generate

# Add an API endpoint
flutter_forge_generate → Endpoint
```

---

## 🎯 Who is this for?

* Flutter developers who hate repetitive setup
* Teams that want **consistent architecture**
* Startups that need to **move fast without breaking structure**
* Junior devs who need **guided best practices**

---

## 🛠 Requirements

* Flutter SDK (3.x)
* Dart SDK (3.x)

---

## 🤝 Contributing

Contributions, ideas, and feedback are welcome.
If you’ve ever been frustrated by Flutter boilerplate — this project is for you.

---

## ⭐ Vision

> Enable any Flutter developer to go from **idea → production-ready app in minutes**, not days.

---

## 📄 License

MIT License

## On Windows

iOS flavor generation requires macOS + Xcode + CocoaPods.
