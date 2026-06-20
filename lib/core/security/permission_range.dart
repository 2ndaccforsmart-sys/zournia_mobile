import 'dart:io';

class PermissionRange {
  final String allowedDirectory;
  final List<String> blockedPaths;
  final bool allowShellExec;

  PermissionRange({
    required this.allowedDirectory,
    this.blockedPaths = const [
      '/etc',
      '/system',
      '/proc',
      '/sys',
    ],
    this.allowShellExec = false,
  });

  /// Check if a path is within the allowed directory and not blocked.
  bool isPathAllowed(String path) {
    final normalized = _normalizePath(path);

    // Block sensitive system directories
    for (final blocked in blockedPaths) {
      if (normalized.startsWith(blocked)) return false;
    }

    // Block path traversal
    if (normalized.contains('..')) return false;

    // If allowedDirectory is set, check the path is within it
    if (allowedDirectory.isNotEmpty) {
      final allowedNorm = _normalizePath(allowedDirectory);
      if (!normalized.startsWith(allowedNorm)) return false;
    }

    return true;
  }

  /// Get a list of readable subdirectories within the allowed directory.
  Future<List<String>> getAccessiblePaths() async {
    final dir = Directory(allowedDirectory);
    if (!await dir.exists()) return [];

    final paths = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        paths.add(entity.path);
      } else if (entity is File) {
        paths.add(entity.path);
      }
    }
    return paths;
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }
}
