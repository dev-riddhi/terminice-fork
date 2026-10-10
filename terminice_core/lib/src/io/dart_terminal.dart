import 'dart:io' as io;

import 'posix_console.dart';
import 'terminal.dart';
import 'windows_console.dart';

/// Default Terminal implementation using dart:io stdin/stdout.
///
/// This is the standard implementation used when running in a real terminal.
/// It delegates directly to dart:io's `stdin` and `stdout` objects.
///
/// **Usage:**
/// ```dart
/// // This is the default - you typically don't need to create it manually
/// final terminal = DartTerminal();
///
/// // Access input/output
/// terminal.output.writeln('Hello');
/// final byte = terminal.input.readByteSync();
/// ```
class DartTerminal implements Terminal, TerminalEnvironment {
  late final DartTerminalInput _input;
  late final DartTerminalOutput _output;

  /// Creates a new DartTerminal using dart:io stdin/stdout.
  DartTerminal() {
    _input = DartTerminalInput();
    _output = DartTerminalOutput();
  }

  @override
  TerminalInput get input => _input;

  @override
  TerminalOutput get output => _output;

  @override
  String? get terminalType {
    try {
      return io.Platform.environment['TERM'];
    } catch (_) {
      return null;
    }
  }
}

/// Default TerminalInput implementation using dart:io stdin.
class DartTerminalInput implements TerminalInput {
  int _coninHandle = WindowsConsole.invalidHandleValue;

  int _getOrOpenConin() {
    if (!WindowsConsole.isAvailable) return WindowsConsole.invalidHandleValue;
    if (_coninHandle != WindowsConsole.invalidHandleValue) return _coninHandle;
    final stdIn = WindowsConsole.getStdInputHandle();
    if (stdIn != 0 && stdIn != WindowsConsole.invalidHandleValue && WindowsConsole.getConsoleMode(stdIn) != null) {
      _coninHandle = stdIn;
      return _coninHandle;
    }
    _coninHandle = WindowsConsole.openConin();
    return _coninHandle;
  }

  @override
  bool get hasTerminal {
    try {
      if (io.stdin.hasTerminal) return true;
    } catch (_) {}
    if (io.Platform.isWindows && WindowsConsole.isAvailable) {
      final h = _getOrOpenConin();
      return h != WindowsConsole.invalidHandleValue && WindowsConsole.getConsoleMode(h) != null;
    }
    return false;
  }

  @override
  bool get echoMode {
    try {
      return io.stdin.echoMode;
    } catch (_) {
      return true;
    }
  }

  @override
  set echoMode(bool value) {
    try {
      io.stdin.echoMode = value;
    } catch (_) {
      // Ignore if terminal is unavailable
    }
  }

  @override
  bool get lineMode {
    try {
      return io.stdin.lineMode;
    } catch (_) {
      return true;
    }
  }

  @override
  set lineMode(bool value) {
    try {
      io.stdin.lineMode = value;
    } catch (_) {
      // Ignore if terminal is unavailable
    }
  }

  @override
  int readByteSync() {
    if (io.Platform.isWindows && WindowsConsole.isAvailable) {
      final h = _getOrOpenConin();
      if (h != WindowsConsole.invalidHandleValue) {
        final byte = WindowsConsole.readByte(h);
        if (byte != null) return byte;
      }
    }
    return io.stdin.readByteSync();
  }

  @override
  int? tryReadByteSync({Duration timeout = Duration.zero}) {
    if (io.Platform.isWindows && WindowsConsole.isAvailable) {
      final h = _getOrOpenConin();
      if (h != WindowsConsole.invalidHandleValue) {
        if (WindowsConsole.isInputAvailable(h, timeout: timeout)) {
          return WindowsConsole.readByte(h);
        }
        return null;
      }
    } else if (io.Platform.isLinux || io.Platform.isMacOS) {
      if (PosixConsole.isAvailable) {
        if (PosixConsole.isInputAvailable(timeout: timeout)) {
          try {
            return io.stdin.readByteSync();
          } catch (_) {
            return null;
          }
        }
        return null;
      }
    }

    return null;
  }

  @override
  String? readLineSync() {
    return io.stdin.readLineSync();
  }
}

/// Default TerminalOutput implementation using dart:io stdout.
class DartTerminalOutput implements TerminalOutput {
  /// Default fallback width when terminal is unavailable.
  static const int defaultColumns = 80;

  /// Default fallback height when terminal is unavailable.
  static const int defaultLines = 24;

  @override
  bool get hasTerminal {
    try {
      return io.stdout.hasTerminal;
    } catch (_) {
      return false;
    }
  }

  @override
  int get terminalColumns {
    try {
      if (io.stdout.hasTerminal) {
        return io.stdout.terminalColumns;
      }
    } catch (_) {}
    return defaultColumns;
  }

  @override
  int get terminalLines {
    try {
      if (io.stdout.hasTerminal) {
        return io.stdout.terminalLines;
      }
    } catch (_) {}
    return defaultLines;
  }

  @override
  void write(Object? object) {
    io.stdout.write(object);
  }

  @override
  void writeln([Object? object = '']) {
    io.stdout.writeln(object);
  }
}
