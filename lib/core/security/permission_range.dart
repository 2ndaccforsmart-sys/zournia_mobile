class PermissionRange {
  final String allowedDirectory;
  final List<String> blockedPaths;
  final bool allowShellExec;

  PermissionRange({required this.allowedDirectory, this.blockedPaths = const [], this.allowShellExec = false});

  bool isPathAllowed(String path) => true;
}
