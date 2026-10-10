import 'dart:ffi';
import 'dart:io' as io;

/// Low-level POSIX terminal polling for Linux and macOS.
class PosixConsole {
  static bool _initialized = false;
  static bool _available = false;
  static DynamicLibrary? _libc;
  static late final int Function(Pointer<Uint8> fds, int nfds, int timeout) _poll;
  static late final Pointer Function(int size) _malloc;
  static late final void Function(Pointer ptr) _free;

  static void _init() {
    if (_initialized) return;
    _initialized = true;

    if (!io.Platform.isLinux && !io.Platform.isMacOS) {
      _available = false;
      return;
    }

    try {
      _libc = DynamicLibrary.process();
      _poll = _libc!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Uint32, Int32),
          int Function(Pointer<Uint8>, int, int)>('poll');
      _malloc = _libc!.lookupFunction<Pointer Function(IntPtr), Pointer Function(int)>('malloc');
      _free = _libc!.lookupFunction<Void Function(Pointer), void Function(Pointer)>('free');
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  /// Whether POSIX polling is available.
  static bool get isAvailable {
    _init();
    return _available;
  }

  /// Checks if stdin (fd 0) has bytes available to read within [timeout].
  static bool isInputAvailable({Duration timeout = Duration.zero}) {
    if (!isAvailable) return false;

    // struct pollfd: int fd (4 bytes), short events (2 bytes), short revents (2 bytes) = 8 bytes
    final fds = _malloc(8).cast<Uint8>();
    try {
      fds.cast<Int32>().value = 0; // stdin = fd 0
      (fds + 4).cast<Int16>().value = 1; // POLLIN = 0x0001
      (fds + 6).cast<Int16>().value = 0; // revents = 0

      final ret = _poll(fds, 1, timeout.inMilliseconds);
      if (ret > 0) {
        final revents = (fds + 6).cast<Int16>().value;
        return (revents & 1) != 0;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _free(fds);
    }
  }
}
