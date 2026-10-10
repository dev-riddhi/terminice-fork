import 'dart:ffi';
import 'dart:io' as io;

/// Low-level Windows Console API interop using `dart:ffi`.
///
/// Enables Virtual Terminal Input (`ENABLE_VIRTUAL_TERMINAL_INPUT`) and Output
/// (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`) on Windows console handles, and provides
/// non-blocking input availability detection using `WaitForSingleObject`.
class WindowsConsole {
  static DynamicLibrary? _kernel32;
  static DynamicLibrary? _msvcrt;
  static bool _initialized = false;
  static bool _available = false;

  // Function pointers
  static late final int Function(int nStdHandle) _getStdHandle;
  static late final int Function(int hConsoleHandle, Pointer<Uint32> lpMode) _getConsoleMode;
  static late final int Function(int hConsoleHandle, int dwMode) _setConsoleMode;
  static late final int Function(
    Pointer<Uint16> lpFileName,
    int dwDesiredAccess,
    int dwShareMode,
    int lpSecurityAttributes,
    int dwCreationDisposition,
    int dwFlagsAndAttributes,
    int hTemplateFile,
  ) _createFileW;
  static late final int Function(int hHandle, int dwMilliseconds) _waitForSingleObject;
  static late final int Function(
    int hFile,
    Pointer<Uint8> lpBuffer,
    int nNumberOfBytesToRead,
    Pointer<Uint32> lpNumberOfBytesRead,
    int lpOverlapped,
  ) _readFile;
  static late final int Function(int hHandle) _closeHandle;
  static late final Pointer Function(int size) _malloc;
  static late final void Function(Pointer ptr) _free;

  // Handle IDs
  static const int stdInputHandle = -10;
  static const int stdOutputHandle = -11;

  // Console input modes
  static const int enableProcessedInput = 0x0001;
  static const int enableLineInput = 0x0002;
  static const int enableEchoInput = 0x0004;
  static const int enableWindowInput = 0x0008;
  static const int enableMouseInput = 0x0010;
  static const int enableInsertMode = 0x0020;
  static const int enableQuickEditMode = 0x0040;
  static const int enableExtendedFlags = 0x0080;
  static const int enableAutoPosition = 0x0100;
  static const int enableVirtualTerminalInput = 0x0200;

  // Console output modes
  static const int enableProcessedOutput = 0x0001;
  static const int enableWrapAtEolOutput = 0x0002;
  static const int enableVirtualTerminalProcessing = 0x0004;

  // File access flags
  static const int genericRead = 0x80000000;
  static const int genericWrite = 0x40000000;
  static const int fileShareRead = 0x00000001;
  static const int fileShareWrite = 0x00000002;
  static const int openExisting = 3;
  static const int invalidHandleValue = -1;

  static void _init() {
    if (_initialized) return;
    _initialized = true;

    if (!io.Platform.isWindows) {
      _available = false;
      return;
    }

    try {
      _kernel32 = DynamicLibrary.open('kernel32.dll');
      _msvcrt = DynamicLibrary.open('msvcrt.dll');

      _getStdHandle = _kernel32!.lookupFunction<IntPtr Function(Int32), int Function(int)>('GetStdHandle');
      _getConsoleMode = _kernel32!.lookupFunction<Int32 Function(IntPtr, Pointer<Uint32>), int Function(int, Pointer<Uint32>)>('GetConsoleMode');
      _setConsoleMode = _kernel32!.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>('SetConsoleMode');
      _createFileW = _kernel32!.lookupFunction<
          IntPtr Function(Pointer<Uint16>, Uint32, Uint32, IntPtr, Uint32, Uint32, IntPtr),
          int Function(Pointer<Uint16>, int, int, int, int, int, int)>('CreateFileW');
      _waitForSingleObject = _kernel32!.lookupFunction<Uint32 Function(IntPtr, Uint32), int Function(int, int)>('WaitForSingleObject');
      _readFile = _kernel32!.lookupFunction<
          Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>, IntPtr),
          int Function(int, Pointer<Uint8>, int, Pointer<Uint32>, int)>('ReadFile');
      _closeHandle = _kernel32!.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
      _malloc = _msvcrt!.lookupFunction<Pointer Function(IntPtr), Pointer Function(int)>('malloc');
      _free = _msvcrt!.lookupFunction<Void Function(Pointer), void Function(Pointer)>('free');

      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  /// Whether Windows console interop is available.
  static bool get isAvailable {
    _init();
    return _available;
  }

  static Pointer<Uint16>? _toUtf16(String s) {
    if (!_available) return null;
    final units = s.codeUnits;
    final ptr = _malloc((units.length + 1) * 2).cast<Uint16>();
    for (var i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;
    return ptr;
  }

  /// Opens `CONIN$` to access the console input buffer directly.
  static int openConin() {
    if (!isAvailable) return invalidHandleValue;
    final namePtr = _toUtf16('CONIN\$');
    if (namePtr == null) return invalidHandleValue;
    try {
      return _createFileW(
        namePtr,
        genericRead | genericWrite,
        fileShareRead | fileShareWrite,
        0,
        openExisting,
        0,
        0,
      );
    } catch (_) {
      return invalidHandleValue;
    } finally {
      _free(namePtr);
    }
  }

  /// Opens `CONOUT$` to access the console screen buffer directly.
  static int openConout() {
    if (!isAvailable) return invalidHandleValue;
    final namePtr = _toUtf16('CONOUT\$');
    if (namePtr == null) return invalidHandleValue;
    try {
      return _createFileW(
        namePtr,
        genericRead | genericWrite,
        fileShareRead | fileShareWrite,
        0,
        openExisting,
        0,
        0,
      );
    } catch (_) {
      return invalidHandleValue;
    } finally {
      _free(namePtr);
    }
  }

  /// Gets the current console mode for [handle].
  static int? getConsoleMode(int handle) {
    if (!isAvailable || handle == 0 || handle == invalidHandleValue) return null;
    final pMode = _malloc(sizeOf<Uint32>()).cast<Uint32>();
    try {
      if (_getConsoleMode(handle, pMode) != 0) {
        return pMode.value;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _free(pMode);
    }
  }

  /// Sets the console mode for [handle].
  static bool setConsoleMode(int handle, int mode) {
    if (!isAvailable || handle == 0 || handle == invalidHandleValue) return false;
    try {
      return _setConsoleMode(handle, mode) != 0;
    } catch (_) {
      return false;
    }
  }

  /// Closes an open Win32 handle.
  static bool closeHandle(int handle) {
    if (!isAvailable || handle == 0 || handle == invalidHandleValue) return false;
    try {
      return _closeHandle(handle) != 0;
    } catch (_) {
      return false;
    }
  }

  /// Checks if console input is available to read within [timeout].
  static bool isInputAvailable(int handle, {Duration timeout = Duration.zero}) {
    if (!isAvailable || handle == 0 || handle == invalidHandleValue) return false;
    try {
      return _waitForSingleObject(handle, timeout.inMilliseconds) == 0;
    } catch (_) {
      return false;
    }
  }

  /// Synchronously reads a single byte from [handle].
  static int? readByte(int handle) {
    if (!isAvailable || handle == 0 || handle == invalidHandleValue) return null;
    final pBuf = _malloc(1).cast<Uint8>();
    final pRead = _malloc(sizeOf<Uint32>()).cast<Uint32>();
    try {
      pRead.value = 0;
      if (_readFile(handle, pBuf, 1, pRead, 0) != 0 && pRead.value > 0) {
        return pBuf[0];
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _free(pBuf);
      _free(pRead);
    }
  }

  /// Retrieves the standard input handle.
  static int getStdInputHandle() {
    if (!isAvailable) return invalidHandleValue;
    try {
      return _getStdHandle(stdInputHandle);
    } catch (_) {
      return invalidHandleValue;
    }
  }

  /// Retrieves the standard output handle.
  static int getStdOutputHandle() {
    if (!isAvailable) return invalidHandleValue;
    try {
      return _getStdHandle(stdOutputHandle);
    } catch (_) {
      return invalidHandleValue;
    }
  }
}

/// Stores Windows console modes for restoring later.
class WindowsConsoleState {
  final int inHandle;
  final int? origInMode;
  final int coninHandle;
  final int? origConinMode;
  final int outHandle;
  final int? origOutMode;
  final int conoutHandle;
  final int? origConoutMode;

  WindowsConsoleState({
    required this.inHandle,
    required this.origInMode,
    required this.coninHandle,
    required this.origConinMode,
    required this.outHandle,
    required this.origOutMode,
    required this.conoutHandle,
    required this.origConoutMode,
  });

  /// Restores the console modes to their original state and closes temporary handles.
  void restore() {
    if (origInMode != null && inHandle != WindowsConsole.invalidHandleValue) {
      WindowsConsole.setConsoleMode(inHandle, origInMode!);
    }
    if (origConinMode != null && coninHandle != WindowsConsole.invalidHandleValue) {
      WindowsConsole.setConsoleMode(coninHandle, origConinMode!);
    }
    if (coninHandle != WindowsConsole.invalidHandleValue && coninHandle != inHandle) {
      WindowsConsole.closeHandle(coninHandle);
    }

    if (origOutMode != null && outHandle != WindowsConsole.invalidHandleValue) {
      WindowsConsole.setConsoleMode(outHandle, origOutMode!);
    }
    if (origConoutMode != null && conoutHandle != WindowsConsole.invalidHandleValue) {
      WindowsConsole.setConsoleMode(conoutHandle, origConoutMode!);
    }
    if (conoutHandle != WindowsConsole.invalidHandleValue && conoutHandle != outHandle) {
      WindowsConsole.closeHandle(conoutHandle);
    }
  }

  /// Configures the Windows console into raw mode with Virtual Terminal Input/Output enabled.
  static WindowsConsoleState? enterRaw() {
    if (!WindowsConsole.isAvailable) return null;

    final inHandle = WindowsConsole.getStdInputHandle();
    final origInMode = WindowsConsole.getConsoleMode(inHandle);

    final coninHandle = WindowsConsole.openConin();
    final origConinMode = WindowsConsole.getConsoleMode(coninHandle);

    final outHandle = WindowsConsole.getStdOutputHandle();
    final origOutMode = WindowsConsole.getConsoleMode(outHandle);

    final conoutHandle = WindowsConsole.openConout();
    final origConoutMode = WindowsConsole.getConsoleMode(conoutHandle);

    void applyRawInput(int handle, int? mode) {
      if (mode != null && handle != WindowsConsole.invalidHandleValue) {
        int newMode = mode |
            WindowsConsole.enableVirtualTerminalInput |
            WindowsConsole.enableProcessedInput;
        newMode &= ~(WindowsConsole.enableLineInput |
            WindowsConsole.enableEchoInput |
            WindowsConsole.enableWindowInput);
        WindowsConsole.setConsoleMode(handle, newMode);
      }
    }

    void applyVtOutput(int handle, int? mode) {
      if (mode != null && handle != WindowsConsole.invalidHandleValue) {
        int newMode = mode |
            WindowsConsole.enableVirtualTerminalProcessing |
            WindowsConsole.enableProcessedOutput;
        WindowsConsole.setConsoleMode(handle, newMode);
      }
    }

    applyRawInput(inHandle, origInMode);
    applyRawInput(coninHandle, origConinMode);
    applyVtOutput(outHandle, origOutMode);
    applyVtOutput(conoutHandle, origConoutMode);

    return WindowsConsoleState(
      inHandle: inHandle,
      origInMode: origInMode,
      coninHandle: coninHandle,
      origConinMode: origConinMode,
      outHandle: outHandle,
      origOutMode: origOutMode,
      conoutHandle: conoutHandle,
      origConoutMode: origConoutMode,
    );
  }
}
