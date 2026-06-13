# Zournia PC — Agent Guide

## Commands
```
flutter pub get          # install deps
flutter run              # launch desktop app
flutter analyze          # lint
flutter test             # run tests
```

## Architecture
- **Entry point**: `lib/main.dart` → bootstraps `window_manager` (hidden title bar, 1200×750) then runs `ZourniaOS` → `ZourniaShell`.
- **Shell**: `lib/features/shell/presentation/zournia_shell.dart` — dark-charcoal workspace with floating chat bar, model selector (Qwen / Gemini / Auto), and `DragToMoveArea` for window dragging.
- **Theme tokens**: `lib/core/theme/zournia_theme.dart` — light-mode colors (`bgPrimary`, `cardBg`, `borderPrimary`, `textPrimary`, `textMuted`, `accentGreen`). Use these, never hardcode colors.
- **Feature-first layout**: `lib/features/<feature>/presentation/` for UI, `data/` for models, `widgets/` for reusable pieces.

## Key Constraints
- **No `Scaffold` or `MaterialApp` inside feature widgets** — the shell already provides them.
- **Never put `color` and `decoration` on the same `Container`** — background color must live inside `BoxDecoration(color: ...)`.
- **Always use `ZourniaTheme` tokens** for colors; do not invent new theme properties.
- **`window_manager` is required** for all window control buttons (minimize, maximize/unmaximize, close).
- **API keys** for Gemini and Qwen are managed in the Settings tab; they are empty strings by default and must be filled before making real HTTP calls.

## Dependencies
- `window_manager` — native window controls (hidden title bar, drag-to-move).
- `http` — REST calls to Gemini / Qwen endpoints.
- `file_picker` — attachment handling in chat input.
- `intl` — date/time formatting in dashboard.

## Testing
- Single test file: `test/widget_test.dart`. Run with `flutter test`.
- No integration test suite or mock services configured yet.
