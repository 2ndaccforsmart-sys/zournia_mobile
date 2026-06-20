class SecurityJail {
  final String allowedDirectory;
  final List<String> blockedPaths;
  final List<String> allowedShellCommands;

  SecurityJail({
    required this.allowedDirectory,
    this.blockedPaths = const [
      '/etc/passwd',
      '/etc/shadow',
      '/system/build.prop',
    ],
    this.allowedShellCommands = const [
      'ls', 'cat', 'grep', 'find', 'pwd', 'echo', 'whoami', 'date',
      'input', 'am', 'pm', 'dumpsys', 'screencap', 'uiautomator',
      'content', 'getprop', 'cmd', 'monkey', 'df', 'free', 'uname',
      'termux-clipboard-get', 'termux-clipboard-set', 'termux-notification',
    ],
  });

  /// Validate that a file path is safe to access.
  bool validatePath(String path) {
    final normalized = _normalizePath(path);

    // Block access to sensitive system paths
    for (final blocked in blockedPaths) {
      if (normalized.startsWith(blocked)) return false;
    }

    // Block path traversal
    if (normalized.contains('..')) return false;

    return true;
  }

  /// Validate that a shell command is allowed to execute.
  bool allowExecution(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return false;

    // Extract the base command (first word)
    final parts = trimmed.split(RegExp(r'\s+'));
    final baseCommand = parts.first.split('/').last;

    // Check against allowed commands
    return allowedShellCommands.any((allowed) => baseCommand == allowed);
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }
}
