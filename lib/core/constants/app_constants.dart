class AppConstants {
  // ── File paths ──────────────────────────────────────────────────────────
  static const String apiKeysFile = 'api_keys.json';
  static const String legacyApiKeyFile = 'api_key.txt';
  static const String customModelsFile = 'custom_models.json';
  static const String sessionStateFile = 'session_state.json';
  static const String learnedPatternsFile = 'learned_patterns.json';
  static const String discoveredAppsFile = 'discovered_apps.json';

  // ── Android paths ───────────────────────────────────────────────────────
  static const String screenshotPath = '/sdcard/zournia_screenshot.png';
  static const String uiDumpPath = '/sdcard/zournia_ui.xml';

  // ── UI constants ────────────────────────────────────────────────────────
  static const double windowWidth = 1200;
  static const double windowHeight = 750;
  static const double bottomBarWidth = 760;
  static const double sidebarWidth = 260;

  // ── AI constants ────────────────────────────────────────────────────────
  static const int maxTokens = 4096;
  static const int chatHistoryWindow = 10;
  static const int fileReadTruncationLimit = 8000;

  // ── Timing ──────────────────────────────────────────────────────────────
  static const int defaultSwipeDuration = 300;
  static const int defaultLongPressDuration = 1000;
  static const Duration uiDumpCacheTTL = Duration(seconds: 3);
  static const Duration appScanInterval = Duration(hours: 12);

  // ── Command prefixes (single source of truth) ───────────────────────────
  static const List<String> commandPrefixes = [
    'EXECUTE:', 'CLOSE:', 'SEARCH:', 'TAP:', 'SWIPE:', 'TYPE:', 'NAV:',
    'SCREENSHOT:', 'DUMPUI:', 'VISION:',
    'OPENAPP:', 'LAUNCH:', 'LISTAPPS:', 'UNINSTALL:',
    'READ_FILE:', 'WRITE_FILE:', 'EDIT_FILE:', 'LIST_DIR:', 'DELETE_FILE:',
    'MKDIR:', 'COPY_FILE:', 'MOVE_FILE:', 'FILE_APPEND:',
    'CLIPBOARD:', 'CLIP_SET:', 'CLIPBOARD_SET:',
    'CONTACTS:', 'SMS:', 'CALL_LOG:', 'CALENDAR:',
    'NOTIFICATIONS:', 'POST_NOTIF:',
    'CAMERA:', 'RECORD:', 'GALLERY:', 'MIC:',
    'DEVICE_INFO:', 'BATTERY:', 'STORAGE:', 'RAM:', 'NETWORK:', 'ENV:',
    'WAKE:', 'SLEEP:', 'UNLOCK:',
    'DOUBLE_TAP:', 'LONGPRESS:', 'PINCH:', 'SELECT_ALL:', 'COPY_TEXT:', 'PASTE_TEXT:',
    'WINDOW_LIST:', 'DESKTOP_SCREENSHOT:',
    'SHELL:',
    'AUTONOMOUS:',
  ];

  // ── Status message prefixes ─────────────────────────────────────────────
  static const List<String> statusPrefixes = [
    'Executing', 'Terminating', 'Searching', 'Tapping', 'Swiping',
    'Typing', 'Navigation', 'Taking', 'Scanning', 'Opening',
    'Listing', 'Loading', 'Analyzing', 'Running', 'Gathering', 'Checking',
  ];

  // ── Media platforms ─────────────────────────────────────────────────────
  static const List<String> knownPlatforms = [
    'youtube', 'spotify', 'netflix', 'tiktok', 'google', 'amazon', 'twitch', 'soundcloud',
  ];

  static const Map<String, String> platformHomepages = {
    'youtube': 'https://www.youtube.com',
    'spotify': 'https://open.spotify.com',
    'netflix': 'https://www.netflix.com',
    'tiktok': 'https://www.tiktok.com',
    'google': 'https://www.google.com',
    'amazon': 'https://www.amazon.com',
    'twitch': 'https://www.twitch.tv',
    'soundcloud': 'https://soundcloud.com',
  };

  static const Map<String, Map<String, String>> platformDeepLinks = {
    'youtube': {
      'package': 'com.google.android.youtube',
      'deepLink': 'intent://search?q={q}#Intent;package=com.google.android.youtube;end',
      'webUrl': 'https://www.youtube.com/results?search_query={q}',
    },
    'spotify': {
      'package': 'com.spotify.music',
      'deepLink': 'spotify:search:{q}',
      'webUrl': 'https://open.spotify.com/search/{q}',
    },
    'netflix': {
      'package': 'com.netflix.mediaclient',
      'deepLink': 'nflx://search?q={q}',
      'webUrl': 'https://www.netflix.com/search?q={q}',
    },
    'tiktok': {
      'package': 'com.zhiliaoapp.musically',
      'deepLink': 'snssdk1128://search?keyword={q}',
      'webUrl': 'https://www.tiktok.com/search?q={q}',
    },
    'google': {
      'webUrl': 'https://www.google.com/search?q={q}',
    },
    'amazon': {
      'package': 'com.amazon.mShop.android.shopping',
      'webUrl': 'https://www.amazon.com/s?k={q}',
    },
    'twitch': {
      'package': 'tv.twitch.android.app',
      'webUrl': 'https://www.twitch.tv/search?term={q}',
    },
    'soundcloud': {
      'package': 'com.soundcloud.android',
      'webUrl': 'https://soundcloud.com/search?q={q}',
    },
  };
}
