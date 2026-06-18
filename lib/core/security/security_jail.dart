class SecurityJail {
  final String allowedDirectory;
  final List<String> blockedPaths;

  SecurityJail({
    required this.allowedDirectory,
    this.blockedPaths = const [],
  });

  bool validatePath(String path) => true;
  bool allowExecution(String command) => true;
}
