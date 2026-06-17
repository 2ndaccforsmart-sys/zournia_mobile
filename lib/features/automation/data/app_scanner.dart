import 'dart:io';
import 'dart:convert';

class AppInfo {
  final String packageName;
  String launcherActivity;
  String appName;
  DateTime lastSeen;

  AppInfo({
    required this.packageName,
    this.launcherActivity = '',
    this.appName = '',
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'launcherActivity': launcherActivity,
    'appName': appName,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory AppInfo.fromJson(Map<String, dynamic> json) => AppInfo(
    packageName: json['packageName'] ?? '',
    launcherActivity: json['launcherActivity'] ?? '',
    appName: json['appName'] ?? '',
    lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : DateTime.now(),
  );
}

class AppScanner {
  static const String _cacheFile = 'discovered_apps.json';
  static const Duration _scanInterval = Duration(hours: 12);

  Map<String, AppInfo> _apps = {};
  DateTime? _lastScanTime;
  bool _scanning = false;

  Map<String, AppInfo> get apps => Map.from(_apps);
  bool get isScanning => _scanning;
  DateTime? get lastScanTime => _lastScanTime;
  bool get needsScan => _lastScanTime == null || DateTime.now().difference(_lastScanTime!) >= _scanInterval;

  Future<void> loadCache() async {
    try {
      final file = File(_cacheFile);
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _lastScanTime = data['lastScanTime'] != null ? DateTime.parse(data['lastScanTime']) : null;
        final appsList = data['apps'] as List? ?? [];
        _apps = {
          for (final a in appsList)
            a['packageName']: AppInfo.fromJson(a)
        };
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final data = {
        'lastScanTime': _lastScanTime?.toIso8601String(),
        'apps': _apps.values.map((a) => a.toJson()).toList(),
      };
      await File(_cacheFile).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {}
  }

  Future<void> scanNow() async {
    if (_scanning) return;
    _scanning = true;

    try {
      final packageResult = await Process.run('sh', ['-c', 'pm list packages 2>&1 </dev/null']);
      if (packageResult.exitCode != 0) return;

      final lines = packageResult.stdout.toString().split('\n');
      final packages = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('package:')) {
          packages.add(trimmed.substring(8));
        }
      }

      final knownApps = <String, String>{
        'com.google.android.youtube': 'YouTube',
        'com.google.android.apps.youtube.music': 'YouTube Music',
        'com.spotify.music': 'Spotify',
        'com.netflix.mediaclient': 'Netflix',
        'com.zhiliaoapp.musically': 'TikTok',
        'com.discord': 'Discord',
        'com.whatsapp': 'WhatsApp',
        'com.instagram.android': 'Instagram',
        'com.facebook.katana': 'Facebook',
        'com.twitter.android': 'Twitter/X',
        'com.telegram.messenger': 'Telegram',
        'org.telegram.messenger': 'Telegram',
        'com.android.chrome': 'Chrome',
        'com.android.settings': 'Settings',
        'com.google.android.gm': 'Gmail',
        'com.google.android.apps.maps': 'Maps',
        'com.openai.chatgpt': 'ChatGPT',
        'com.github.android': 'GitHub',
        'com.amazon.mShop.android.shopping': 'Amazon',
        'com.soundcloud.android': 'SoundCloud',
        'tv.twitch.android.app': 'Twitch',
        'com.plexapp.android': 'Plex',
        'com.slack.android': 'Slack',
        'com.microsoft.teams': 'Teams',
        'com.linkedin.android': 'LinkedIn',
        'com.reddit.frontpage': 'Reddit',
        'com.snapchat.android': 'Snapchat',
        'com.pinterest': 'Pinterest',
        'com.tumblr': 'Tumblr',
        'com.medium.android': 'Medium',
        'com.substack.android': 'Substack',
        'com.shazam.android': 'Shazam',
        'com.vkontakte.android': 'VK',
        'com.opera.browser': 'Opera',
        'com.brave.browser': 'Brave',
        'org.mozilla.firefox': 'Firefox',
        'com.microsoft.emmx': 'Edge',
        'com.UCMobile': 'UC Browser',
        'com.android.filemanager': 'File Manager',
        'com.android.calculator2': 'Calculator',
        'com.android.calendar': 'Calendar',
        'com.android.deskclock': 'Clock',
        'com.android.camera2': 'Camera',
        'com.google.android.GoogleCamera': 'Google Camera',
        'com.android.contacts': 'Contacts',
        'com.android.messaging': 'Messages',
        'com.google.android.apps.messaging': 'Google Messages',
        'com.android.phone': 'Phone',
        'com.google.android.dialer': 'Google Phone',
        'com.google.android.apps.photos': 'Google Photos',
        'com.android.gallery3d': 'Gallery',
        'com.spotify.lite': 'Spotify Lite',
        'com.instagram.lite': 'Instagram Lite',
        'com.facebook.lite': 'Facebook Lite',
        'com.twitter.lite': 'Twitter Lite',
        'com.zhiliaoapp.musically.go': 'TikTok Lite',
        'com.google.android.apps.nbu.files': 'Files by Google',
        'com.sec.android.app.sbrowser': 'Samsung Internet',
        'com.samsung.android.app.spage': 'Samsung Free',
        'com.sec.android.app.launcher': 'Samsung Launcher',
        'com.miui.home': 'MIUI Launcher',
        'com.huawei.android.launcher': 'Huawei Launcher',
        'com.android.vending': 'Google Play Store',
        'com.google.android.gms': 'Google Play Services',
        'com.google.android.youtube.kids': 'YouTube Kids',
        'com.google.android.apps.chromecast.app': 'Google Home',
        'com.amazon.avod': 'Prime Video',
        'com.disney.disneyplus': 'Disney+',
        'com.hbo.hbonow': 'HBO Max',
        'com.hulu.livetv': 'Hulu',
        'com.peacocktv.peacockcolor': 'Peacock',
        'com.apple.android.music': 'Apple Music',
        'com.amazon.mp3': 'Amazon Music',
        'deezer.android.app': 'Deezer',
        'com.tidal.music': 'Tidal',
        'com.saavn.android': 'JioSaavn',
        'com.gaana': 'Gaana',
        'com.wynk.music': 'Wynk Music',
        'com.ktc.jiochat': 'JioChat',
      };

      for (final pkg in packages) {
        if (_apps.containsKey(pkg)) {
          _apps[pkg]!.lastSeen = DateTime.now();
          continue;
        }

        String appName = knownApps[pkg] ?? pkg.split('.').last;
        String launcher = '';

        try {
          final resolveResult = await Process.run('sh', ['-c', 'cmd package resolve-activity --brief $pkg 2>&1 </dev/null']);
          if (resolveResult.exitCode == 0) {
            final rLines = resolveResult.stdout.toString().trim().split('\n');
            for (final line in rLines) {
              if (line.contains('/') && !line.startsWith('priority=')) {
                launcher = line.trim();
                break;
              }
            }
          }
        } catch (_) {}

        _apps[pkg] = AppInfo(
          packageName: pkg,
          launcherActivity: launcher,
          appName: appName,
          lastSeen: DateTime.now(),
        );
      }

      _lastScanTime = DateTime.now();
      await _saveCache();
    } catch (_) {}
    _scanning = false;
  }

  String? resolveLauncher(String packageName) {
    final app = _apps[packageName];
    if (app != null && app.launcherActivity.isNotEmpty) {
      return app.launcherActivity;
    }
    return null;
  }

  String? findApp(String query) {
    final q = query.toLowerCase();
    for (final app in _apps.values) {
      if (app.appName.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q)) {
        return app.packageName;
      }
    }
    return null;
  }

  List<Map<String, String>> searchApps(String query) {
    final q = query.toLowerCase();
    final results = <Map<String, String>>[];
    for (final app in _apps.values) {
      if (app.appName.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q)) {
        results.add({
          'name': app.appName,
          'package': app.packageName,
          'launcher': app.launcherActivity,
        });
      }
    }
    return results;
  }

  String getAppsSummary() {
    final sorted = _apps.values.toList()
      ..sort((a, b) => a.appName.compareTo(b.appName));
    final buffer = StringBuffer('Discovered ${sorted.length} installed apps:\n');
    for (final app in sorted) {
      buffer.writeln('  - ${app.appName} (${app.packageName})');
    }
    return buffer.toString();
  }

  List<String> getKnownPackageNames() {
    return _apps.keys.toList();
  }
}
