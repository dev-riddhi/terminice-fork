# Changes and Fix Documentation

> [!NOTE]
> **Notice**: This entire diagnosis, root cause analysis, architecture design, native implementation, and verification was performed end-to-end by **AI (Antigravity AI Assistant)**.

---

## 1. Problem Statement

When running terminal applications built with `terminice` on Windows, **only character keys (letters, numbers, Enter) produced input**. 

Non-character keys:
- **Arrow keys** (Up, Down, Left, Right) were completely ignored. Users could not navigate lists, selectors, menus, checkboxes, or move the text cursor.
- **Escape key** caused prompts to freeze or hang until subsequent keys were typed, swallowing input.
- **Delete key** and other navigation keys did not function.

Unit tests in `terminice_core` were passing because they utilized `MockTerminal` (which manually pushed simulated ANSI byte arrays into an in-memory queue), masking the real-world Windows console runtime failure.

---

## 2. Technical Root Cause Analysis

The failure was caused by a combination of Windows Console subsystem behavior, Dart runtime I/O design, and blocking escape sequence peeking in `terminice_core`:

### A. Windows Console Input Filtering ([Dart SDK Issue #48329](https://github.com/dart-lang/sdk/issues/48329))
- In Dart, `stdin.readByteSync()` on Windows delegates to the Win32 `ReadFile(GetStdHandle(STD_INPUT_HANDLE))` API.
- By default, Windows Console handles keypresses in "cooked" mode. Non-character keys (Arrow keys, Home, End, PageUp, PageDown, Delete, Function keys) are handled as internal Win32 `KEY_EVENT_RECORD` events.
- Because `ReadFile` is a character-oriented API, Windows Console **filters out non-character key events completely**. They return **zero bytes**.
- Only when `ENABLE_VIRTUAL_TERMINAL_INPUT` (`0x0200`) is enabled on the console input handle does the Windows Console host translate arrow and navigation keys into standard ANSI/VT escape sequences (e.g., `ESC [ A` for Up Arrow).

### B. Incomplete Raw Mode Configuration in `TerminalControl.enterRaw()`
- `terminice_core` entered raw mode by setting:
  ```dart
  stdin.echoMode = false;
  stdin.lineMode = false;
  ```
- In Dart's C++ runtime on Windows (`stdio_win.cc`), clearing `echoMode` and `lineMode` only clears `ENABLE_LINE_INPUT` and `ENABLE_ECHO_INPUT`. Dart **never** sets `ENABLE_VIRTUAL_TERMINAL_INPUT` or `ENABLE_VIRTUAL_TERMINAL_PROCESSING`.
- Consequently, Windows Console continued to suppress all arrow and navigation keys.

### C. Indefinite Blocking in `TerminalControl.tryReadNextByte()`
- To check if a byte is part of an escape sequence, `tryReadNextByte()` was written as:
  ```dart
  static int? tryReadNextByte({Duration delay = const Duration(milliseconds: 2)}) {
    try {
      sleep(delay);
      if (TerminalContext.input.hasTerminal) {
        return TerminalContext.input.readByteSync();
      }
    } catch (_) {}
    return null;
  }
  ```
- In Dart, `io.stdin.readByteSync()` is a **blocking synchronous call** with no timeout. If no byte is waiting, it does not return `null`—it freezes the thread until the user presses another key.
- When a user pressed `Esc` (`byte == 27`), `tryReadNextByte()` called `readByteSync()`, causing the application to hang waiting for the user to press another key, swallowing whatever key was typed next.

### D. Missing Key Sequence Mappings in `KeyEventReader`
- The parser only recognized `\x1b[A`..`\x1b[D`.
- It did not recognize:
  - Windows console extended scan codes (`0` or `224` prefix followed by scan codes 72, 80, 75, 77, 83).
  - SS3 keypad cursor sequences (`\x1bOA`..`\x1bOD`).
  - CSI Delete sequences (`\x1b[3~`).

---

## 3. How the Fix Was Implemented

### 1. Native Windows Console Interop via `dart:ffi`
Created [`terminice_core/lib/src/io/windows_console.dart`](terminice_core/lib/src/io/windows_console.dart):
- Zero external dependencies; uses the built-in Dart standard library `dart:ffi` to access `kernel32.dll` and `msvcrt.dll`.
- **Input Mode Configuration**:
  - Automatically enables `ENABLE_VIRTUAL_TERMINAL_INPUT (0x0200)` and `ENABLE_PROCESSED_INPUT (0x0001)`.
  - Disables `ENABLE_LINE_INPUT (0x0002)`, `ENABLE_ECHO_INPUT (0x0004)`, and `ENABLE_WINDOW_INPUT (0x0008)`.
  - Configures both `STD_INPUT_HANDLE` and `CONIN$` (ensuring compatibility even if standard input was redirected or piped).
- **Output Mode Configuration**:
  - Enables `ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004)` and `ENABLE_PROCESSED_OUTPUT (0x0001)` on `STD_OUTPUT_HANDLE` and `CONOUT$`.
  - Guarantees ANSI color and cursor positioning sequences render properly on classic `cmd.exe`, PowerShell, and Windows Terminal.
- **State Restoration**:
  - Implemented `WindowsConsoleState` to capture the original console modes and cleanly restore them upon prompt completion or cancellation.

### 2. Non-Blocking Input Availability Detection
Added `tryReadByteSync({Duration timeout = Duration.zero})` to [`TerminalInput`](terminice_core/lib/src/io/terminal.dart):
- **Windows**: Uses Win32 `WaitForSingleObject` on the console input handle with millisecond precision. If no key is queued, it returns `null` immediately without blocking.
- **Linux & macOS**: Created [`terminice_core/lib/src/io/posix_console.dart`](terminice_core/lib/src/io/posix_console.dart) using `poll(2)` on standard input (file descriptor 0) with millisecond precision.
- **Testing (`MockTerminalInput`)**: Returns `null` if the mock byte queue is empty, preventing test hangs.

### 3. Updated `DartTerminalInput` & `TerminalControl`
- [`DartTerminalInput`](terminice_core/lib/src/io/dart_terminal.dart):
  - Resolves the active Windows console handle (`STD_INPUT_HANDLE` or `CONIN$`).
  - Implements `tryReadByteSync` using native console availability checks.
- [`TerminalControl`](terminice_core/lib/src/io/terminal_control.dart):
  - `enterRaw()` automatically invokes `WindowsConsoleState.enterRaw()` on Windows.
  - `TerminalModeState.restore()` automatically restores the original Windows console modes.
  - `tryReadNextByte()` delegates to `input.tryReadByteSync(timeout: delay)` without blocking.

### 4. Comprehensive Key Sequence Decoding in `KeyEventReader`
Updated [`KeyEventReader.read()`](terminice_core/lib/src/io/key_events.dart):
- **Windows extended scan codes**: Decodes `0` or `224` (`0xE0`) prefixes followed by scan codes `72` (Up), `80` (Down), `75` (Left), `77` (Right), and `83` (Delete).
- **CSI cursor sequences**: Decodes `\x1b[A`, `\x1b[B`, `\x1b[C`, `\x1b[D`.
- **SS3 cursor sequences**: Decodes `\x1bOA`, `\x1bOB`, `\x1bOC`, `\x1bOD`.
- **CSI Delete sequence**: Decodes `\x1b[3~` as `KeyEventType.backspace`.
- **Safe Escape key handling**: Lone `Esc` key times out quickly and cleanly emits `KeyEventType.esc`. If a non-escape sequence character arrives after `Esc`, the byte is safely replayed so no user keystroke is lost.

---

## 4. Summary of Files Modified & Added

| File | Status | Description |
|---|---|---|
| [`terminice_core/lib/src/io/windows_console.dart`](terminice_core/lib/src/io/windows_console.dart) | **Added** | Win32 console API interop via `dart:ffi` for VT input/output modes and non-blocking input checking. |
| [`terminice_core/lib/src/io/posix_console.dart`](terminice_core/lib/src/io/posix_console.dart) | **Added** | POSIX `poll(2)` interop via `dart:ffi` for non-blocking stdin polling on Linux and macOS. |
| [`terminice_core/lib/src/io/terminal.dart`](terminice_core/lib/src/io/terminal.dart) | **Modified** | Added `tryReadByteSync({Duration timeout})` to `TerminalInput`. |
| [`terminice_core/lib/src/io/dart_terminal.dart`](terminice_core/lib/src/io/dart_terminal.dart) | **Modified** | Added Windows console handle resolution, reading, and `tryReadByteSync` implementation. |
| [`terminice_core/lib/src/io/terminal_control.dart`](terminice_core/lib/src/io/terminal_control.dart) | **Modified** | Added Windows raw mode setup/teardown in `enterRaw()` and `restore()`; updated `tryReadNextByte()` to use non-blocking reads. |
| [`terminice_core/lib/src/io/key_events.dart`](terminice_core/lib/src/io/key_events.dart) | **Modified** | Added decoding for Windows scan codes, SS3 sequences, Delete sequences, and non-blocking Esc handling with byte replay. |
| [`terminice_core/lib/src/testing/mock_terminal.dart`](terminice_core/lib/src/testing/mock_terminal.dart) | **Modified** | Implemented `tryReadByteSync` on `MockTerminalInput`, `SpyTerminalInput`, and `ErrorTerminalInput`. |
| [`terminice_core/lib/src/src.dart`](terminice_core/lib/src/src.dart) | **Modified** | Exported `windows_console.dart` and `posix_console.dart`. |
| [`terminice_core/test/terminal_test.dart`](terminice_core/test/terminal_test.dart) | **Modified** | Added unit tests for Windows scan codes, SS3 sequences, Delete sequences, Esc byte replay, and `tryReadByteSync`. |
| [`terminice/test/indicator_execution_modes_test.dart`](terminice/test/indicator_execution_modes_test.dart) | **Modified** | Implemented `tryReadByteSync` on test input delegate `_ProbeInput`. |

---

## 5. Verification & Test Results

1. **Static Analysis**:
   - `dart analyze` on `terminice_core`: **0 issues**.
   - `dart analyze` on `terminice`: **0 issues**.
   - `dart analyze` on `termistyle`: **0 issues**.

2. **Automated Unit Tests**:
   - `terminice_core`: **174 / 174 passed**.
   - `terminice`: **319 / 319 passed**.
   - Total: **493 / 493 tests passed**.

3. **Live Interactive Testing**:
   - Tested interactive execution on Windows (`dart .\example.dart` in `terminice/example`):
     - Arrow keys successfully navigated single-select and multi-select prompts (selected "Python" and "Dark mode").
     - Confirm dialog, text input, and password masks functioned as expected.
