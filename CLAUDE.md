# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Running the App
- Start the application: `flutter run`
- Build for Windows: `flutter build windows`
- Build for macOS: `flutter build macos`
- Build for Linux: `flutter build linux`
- Build APK (Android): `flutter build apk`
- Build iOS: `flutter build ios`

### Testing
- Run all tests: `flutter test`
- Run a specific test file: `flutter test test/widget_test.dart`
- Run a specific test by name: `flutter test --name "Counter increments smoke test"`
- Run tests with coverage: `flutter test --coverage`

### Linting and Analysis
- Analyze code for linting errors: `flutter analyze`
- Fix linting errors automatically (where possible): `flutter format .`

### Dependency Management
- Get dependencies: `flutter pub get`
- Upgrade dependencies: `flutter pub upgrade`
- Check for outdated dependencies: `flutter pub outdated`

## Project Structure

### High-Level Architecture
This is a Flutter desktop application (primarily targeting Windows) with a custom window appearance (transparent background, hidden title bar). The app follows a feature-based architecture:

- **lib/main.dart**: Entry point. Initializes window management and runs the `ZourniaOS` app.
- **lib/core**: Contains core utilities, constants, security components, and theme definitions used across the app.
  - `core/theme/zournia_theme.dart`: Defines the application's dark theme.
  - `core/security/`: Includes security-related components like permission ranges and security jail.
  - `core/constants/zournia_offsets.dart`: Contains offset constants.
- **lib/features**: Each feature is self-contained with its own presentation, data, and view_model layers.
  - **features/shell**: Contains the main shell UI (`zournia_shell.dart`) and title bar (`title_bar.dart`).
  - **features/dashboard**: Displays metrics UI (`dashboard_view.dart`, `metric_card.dart`).
  - **features/hud_terminal**: AI-powered HUD panel (`ai_hud_panel.dart`).
  - **features/workspace_router**: Handles workspace coordination with a canvas (`workspace_canvas.dart`) and web frames (`web_frame.dart`).
  - **features/ui_components**: Reusable UI components like dropdown menus (`dropdown_menu.dart`).
  - **features/view_models**: Business logic components like `prompt_parser.dart`.

### Key Files
- `pubspec.yaml`: Defines Flutter dependencies (window_manager, http, file_picker, etc.) and dev dependencies (flutter_test, flutter_lints).
- `analysis_options.yaml`: Configures Dart analyzer with recommended Flutter lint rules.
- `test/widget_test.dart`: Example widget test demonstrating Flutter testing patterns.

### Notes
- The app uses `window_manager` for custom window properties (size, position, transparency, hidden title bar).
- State management appears to be scattered; look for stateful widgets and view models within features.
- Assets are loaded from the `assets/` directory as specified in pubspec.yaml.