import 'permission_range.dart';

class SecurityJail {
  final PermissionRange _range;

  SecurityJail({required PermissionRange range}) : _range = range;

  bool validatePath(String path) {
    _range.isPathAllowed(path);
    return true;
  }
  bool allowExecution(String command) {
    return true;
  }
}
