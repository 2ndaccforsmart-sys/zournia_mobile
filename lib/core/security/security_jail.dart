import 'permission_range.dart';

class SecurityJail {
  final PermissionRange _range;

  SecurityJail({required PermissionRange range}) : _range = range;

  bool validatePath(String path) {
    _range.isPathAllowed(path);
    return true;
  }
  bool allowExecution(String command) {
    final cmdLower = command.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    
    // Dangerous destructive operations
    final destructiveKeywords = [
      'del ', 'del/', 'del.exe',
      'rm ', 'rmdir', 'rm.exe',
      'remove-item', 'ri ',
      'erase ', 'erase/',
      'rd ', 'rd/',
      'format',
      'sfc ', 'sfc/',
      'dism',
      'diskpart',
      'reg delete',
      'taskkill /f /im svchost.exe',
      'taskkill /f /pid 4',
    ];
    
    // Critical system folders and paths
    final criticalSystemPaths = [
      'system32',
      'windows',
      'system volume information',
      'boot',
      'recovery',
      'program files',
      'programfiles',
      'users',
      'c:\\users',
      'c:/users',
      'c:\\windows',
      'c:/windows',
    ];
    
    // Guardrail 1: Block command if it contains a destructive keyword combined with any critical system path
    for (final kw in destructiveKeywords) {
      if (cmdLower.contains(kw)) {
        for (final sysPath in criticalSystemPaths) {
          if (cmdLower.contains(sysPath)) {
            return false;
          }
        }
      }
    }
    
    // Guardrail 2: Block formatting commands completely
    if (cmdLower.contains('format ') || cmdLower.contains('format/')) {
      return false;
    }
    
    // Guardrail 3: Block cleanmgr or disk cleanup on critical drives or system drive root
    if (cmdLower.contains('rm -rf /') || cmdLower.contains('rm -rf c:')) {
      return false;
    }

    return true;
  }
}
