# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mindful is a FOSS Android digital-wellbeing app (screen-time limits, focus sessions, app/website blocking, notification batching, bedtime mode, parental controls). It is **Android-only** — the UI is Flutter/Dart, but all enforcement (usage tracking, blocking overlays, VPN, accessibility, DND) lives in native Kotlin. Neither half works alone; understanding a feature almost always means reading both sides of the bridge.

## Commands

```sh
flutter pub get                       # install deps
dart run build_runner build -d        # REQUIRED before first build; regenerates *.g.dart (Drift DB, etc.)
flutter analyze                       # lint (flutter_lints, see analysis_options.yaml)
flutter run                           # run on connected device/emulator
flutter build apk                     # release APK
```

- **`build_runner` is not optional.** Drift generates `app_database.g.dart` and other `*.g.dart` files that are gitignored. A fresh checkout won't compile until you run it. Re-run after touching any `@DriftDatabase`, table, DAO, or other codegen-annotated file.
- **No test suite exists** (`test/` is empty, only `flutter_test` is wired up). There is no `flutter test` to run.
- Development happens on the **`dev` branch**; PRs target `dev`, not `main` (see docs/CONTRIBUTING.md).
- Native code is **Kotlin** under `android/app/src/main/java/com/mindful/android/` (74 files). App id `com.mindful.android`.

## Architecture

### The Flutter ↔ native bridge is the spine of the app

Three `MethodChannel`s connect the two halves:

| Channel | Direction | Defined in |
|---|---|---|
| `...methodchannel.fg` | Flutter → native (foreground: start/stop services, query usage, permissions, open activities) | [lib/core/services/method_channel_service.dart](lib/core/services/method_channel_service.dart) ↔ [android/.../FgMethodCallHandler.kt](android/app/src/main/java/com/mindful/android/FgMethodCallHandler.kt) |
| `...methodchannel.bg` | native → Flutter (headless Dart isolate for boot/midnight work) | [lib/core/services/bg_executor_service.dart](lib/core/services/bg_executor_service.dart) |

`MethodChannelService` (singleton) is the Dart-side API surface for everything native — every service update, permission check, and external-activity launch goes through it. When you add native behavior, you add a method here **and** a matching `case` in `FgMethodCallHandler.kt`. Args are usually JSON-encoded model objects.

**Config flows one way: DB → native services.** [lib/initializer.dart](lib/initializer.dart) (`Initializer.initializeServicesAndSchedules`) reads all restriction/bedtime/wellbeing/notification records from Drift and pushes them into the native services via `MethodChannelService`. After the user changes a setting, the corresponding provider persists to Drift **and** re-pushes to native through the same methods. Native services hold the pushed state and enforce it; they don't read the DB.

### Background isolate (`@pragma('vm:entry-point')`)

`initBgExecutorService` in [lib/main.dart](lib/main.dart) is a **second Dart entry point** run in a headless isolate by [FlutterBgExecutionWorker.kt](android/app/src/main/java/com/mindful/android/workers/FlutterBgExecutionWorker.kt). Native fires it on boot / app-update (`onBootOrAppUpdate` → re-initializes services) and at midnight (`onMidnightReset` → backs up yesterday's usage into Drift, prunes old usage/notifications). Every task must finish within 5 minutes and signal completion back over the `.bg` channel.

### Native services (`android/.../services/`)

Each enforcement mechanism is its own foreground service, bound from `FgMethodCallHandler` via `SafeServiceConnection`:

- **tracking/** `MindfulTrackerService` — screen-time limits & launch counts, draws blocking `Overlay*` when a limit is hit; `RestrictionManager`, `ReminderManager`.
- **vpn/** `MindfulVpnService` — a **local** VPN tunnel (no server) used purely to drop traffic for internet-blocked apps. This is why the manifest requests INTERNET permission (see README).
- **accessibility/** `MindfulAccessibilityService` — reads on-screen content to block short-form feeds (Reels/Shorts), NSFW/websites in browsers (`BrowserManager`, `ShortsPlatformManager`), and toggles device features.
- **notification/** `MindfulNotificationListenerService` — batches/schedules notifications.
- **timer/** `FocusSessionService`, `EmergencyPauseService`. **quickTiles/** `FocusQuickTileService`.

### Data layer — Drift (SQLite)

[lib/core/database/app_database.dart](lib/core/database/app_database.dart) defines the schema (currently **v9**). Two DAOs split responsibility: `UniqueRecordsDao` (single-row settings: bedtime, wellbeing, notifications, mindful settings, parental controls) and `DynamicRecordsDao` (collections: per-app restrictions, restriction groups, usage rows, notifications, focus sessions, crash logs).

**Changing the schema requires the exact 6-step ritual documented at the top of `app_database.dart`** — modify table → bump `schemaVersion` → `build_runner build -d` → `drift_dev schema dump` → `drift_dev schema steps` → add a `fromNToM` migration under `migrations/`. Always write upgrades to tolerate importing a backup from a *newer* schema on an older app version (see the `runSafe`/comment note in the migration strategy).

### Flutter app structure

- **State: Riverpod.** Providers in [lib/providers/](lib/providers/) are grouped by domain (apps, focus, notifications, restrictions, system, usage). They are the read/write intermediaries between UI and the DB+native layer.
- **UI:** [lib/ui/screens/](lib/ui/screens/) mirror the feature set; `lib/ui/common`, `dialogs`, `permissions`, `onboarding` hold shared widgets. Navigation via [lib/config/navigation/](lib/config/navigation/).
- **Deep links / API:** the app registers `com.mindful.android://open/...` deep links (via `app_links`) to jump to any screen; full route/param table in [docs/API.md](docs/API.md).
- **Localization:** ARB files in `lib/l10n/` (`app_en.arb` is the template), generated into `lib/l10n/generated/` per [l10n.yaml](l10n.yaml). Translations are managed via Crowdin (`crowdin.yml`, GitHub workflows) — **edit `app_en.arb` only**; other locales sync from Crowdin.

## Conventions

- Source files carry a GPL-2.0 copyright header — keep it on new files.
- Prefer routing new native capability through the existing `MethodChannelService`/`FgMethodCallHandler` pair rather than opening new channels.
