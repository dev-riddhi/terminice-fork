import 'dart:io';

import 'package:terminice/terminice.dart';
import 'package:terminice_core/terminice_core.dart' show FormFieldConfig;

void main() async {
  while (true) {
    terminice.newline();
    terminice.info('=== TERMINICE SHOWCASE CLI ===');
    terminice.detail('Explore 30+ terminal UI components with interactive examples');
    terminice.newline();

    final category = terminice.searchSelector(
      prompt: 'Select Showcase Category (Esc to Exit)',
      options: [
        '🌟 1. Full Interactive Tour (All Components)',
        '📝 2. Text & Input Prompts (text, password, multiline, confirm, form)',
        '🔢 3. Numeric & Range Prompts (slider, range, rating, date)',
        '🎯 4. Selectors & Menus (choice, search, checkbox, grid, tag, toggle, command)',
        '🎨 5. Pickers (color, date, file, path)',
        '⏳ 6. Progress & Spinners (spinner, dots, progress bar, async task)',
        '💬 7. Message Primitives (info, success, warn, error, detail, log)',
        '🧙 8. Multi-Step Flow Wizard (terminice.flow)',
        '⚙️ 9. Interactive Config Editor (terminice.configEditor)',
        '📖 10. Guides & Reference (hotkeys, help center, cheat sheet)',
        '🌈 11. Theme Gallery & Showcase (9 themes + display modes)',
        '🚪 12. Exit',
      ],
      showSearch: true,
      maxVisible: 12,
    );

    if (category.isEmpty || category.first.contains('Exit')) {
      terminice.newline();
      terminice.success('Thank you for exploring Terminice! 👋');
      break;
    }

    final selected = category.first;

    if (selected.contains('Full Interactive Tour')) {
      await runFullTour();
    } else if (selected.contains('Text & Input Prompts')) {
      runTextInputShowcase();
    } else if (selected.contains('Numeric & Range Prompts')) {
      runNumericRangeShowcase();
    } else if (selected.contains('Selectors & Menus')) {
      runSelectorsShowcase();
    } else if (selected.contains('Pickers')) {
      runPickersShowcase();
    } else if (selected.contains('Progress & Spinners')) {
      await runProgressShowcase();
    } else if (selected.contains('Message Primitives')) {
      runMessagesShowcase();
    } else if (selected.contains('Multi-Step Flow Wizard')) {
      runFlowShowcase();
    } else if (selected.contains('Interactive Config Editor')) {
      runConfigEditorShowcase();
    } else if (selected.contains('Guides & Reference')) {
      runGuidesShowcase();
    } else if (selected.contains('Theme Gallery')) {
      runThemesShowcase();
    }
  }
}

// ============================================================================
// 1. TEXT & INPUT PROMPTS
// ============================================================================
void runTextInputShowcase() {
  terminice.newline();
  terminice.info('Category: Text & Input Prompts');

  // 1. text()
  final username = terminice.text(
    'Service Display Name',
    placeholder: 'my-service (e.g. auth-api)',
    validator: (val) {
      if (val.trim().isEmpty) return 'Name cannot be empty';
      if (val.contains(' ')) return 'No spaces allowed in service name';
      return null;
    },
  );
  terminice.success('Selected Name: $username');

  // 2. password()
  final apiKey = terminice.password(
    'Secret API Key',
    maskChar: '*',
    allowReveal: true,
    required: false,
  );
  terminice.success('API Key length: ${apiKey?.length ?? 0} characters');

  // 3. multiline()
  final notes = terminice.multiline(
    'Release Notes (Ctrl+D / Enter on empty line to finish)',
    visibleLines: 4,
  );
  terminice.success('Notes captured: ${notes?.isNotEmpty == true ? notes!.replaceAll('\n', ' ') : "(empty)"}');

  // 4. confirm()
  final confirmDeploy = terminice.confirm(
    prompt: 'Deploy Confirmation',
    message: 'Deploy changes to production immediately?',
    defaultYes: false,
  );
  terminice.success('Confirmed: $confirmDeploy');

  // 5. form()
  terminice.newline();
  terminice.detail('Multi-field Form with validation:');
  final formResult = terminice.form(
    'Server Connection Form',
    fields: [
      FormFieldConfig(label: 'Host', placeholder: 'api.example.com', required: true),
      FormFieldConfig(label: 'Port', placeholder: '8080', initialValue: '8080', required: true),
      FormFieldConfig(label: 'Auth Token', masked: true, placeholder: 'token_xyz'),
    ],
  );
  if (formResult != null) {
    terminice.success('Form submitted: Host=${formResult[0]}, Port=${formResult[1]}, Token=${formResult[2]}');
  } else {
    terminice.warn('Form was cancelled.');
  }
}

// ============================================================================
// 2. NUMERIC & RANGE PROMPTS
// ============================================================================
void runNumericRangeShowcase() {
  terminice.newline();
  terminice.info('Category: Numeric & Range Prompts');

  // 1. slider()
  final memory = terminice.slider(
    'Memory Limit Allocation',
    min: 128,
    max: 2048,
    initial: 512,
    step: 128,
    unit: 'MB',
  );
  terminice.success('Selected Memory: ${memory}MB');

  // 2. range()
  final portRange = terminice.range(
    'Firewall Port Range',
    min: 1000,
    max: 9000,
    startInitial: 3000,
    endInitial: 8000,
    step: 100,
    unit: 'port',
  );
  terminice.success('Port Range: ${portRange.start} - ${portRange.end}');

  // 3. rating()
  final stars = terminice.rating(
    'Developer Experience Rating',
    maxStars: 5,
    initial: 5,
    labels: ['Poor', 'Fair', 'Good', 'Very Good', 'Exceptional!'],
  );
  terminice.success('Rating given: $stars / 5 stars');

  // 4. date()
  final launchDate = terminice.date(
    'Target Launch Date',
    initial: DateTime.now().add(const Duration(days: 7)),
  );
  terminice.success('Target date: ${launchDate?.toIso8601String().split('T').first ?? "none"}');
}

// ============================================================================
// 3. SELECTORS & MENUS
// ============================================================================
void runSelectorsShowcase() {
  terminice.newline();
  terminice.info('Category: Selectors & Menus');

  // 1. choiceSelector() - Card Dashboard
  terminice.detail('Choice Selector (Cards):');
  final architecture = terminice.choiceSelector(
    'Target Architecture',
    items: const [
      ChoiceItem('x86_64', subtitle: 'Standard 64-bit Intel/AMD PC & Server'),
      ChoiceItem('arm64', subtitle: 'Apple Silicon & ARMv8 64-bit systems'),
      ChoiceItem('riscv64', subtitle: 'Modern open RISC-V 64-bit architecture'),
    ],
  );
  terminice.success('Architecture selected: ${architecture.join(", ")}');

  // 2. searchSelector() - Searchable List
  terminice.detail('Search Selector (Fuzzy list):');
  final toolchain = terminice.searchSelector(
    prompt: 'Compiler Toolchain',
    options: ['Dart Native AOT', 'Rust LLVM', 'Go GC', 'Clang/LLVM C++', 'Swift', 'Kotlin Native', 'GCC'],
    showSearch: true,
    maxVisible: 4,
  );
  terminice.success('Toolchain: ${toolchain.isNotEmpty ? toolchain.first : "none"}');

  // 3. checkboxSelector() - Multi-Select Checkboxes
  terminice.detail('Checkbox Selector:');
  final features = terminice.checkboxSelector(
    'Select Enabled Modules',
    options: ['REST API Server', 'GraphQL Endpoint', 'WebSockets', 'Telemetry Metrics', 'Prometheus Exporter'],
    initialSelected: {0, 3},
  );
  terminice.success('Enabled Modules: ${features.join(", ")}');

  // 4. gridSelector() - 2D Grid
  terminice.detail('Grid Selector:');
  final icon = terminice.gridSelector(
    prompt: 'Select Avatar Icon',
    options: ['🚀 Rocket', '⚡ Lightning', '🔥 Fire', '💎 Diamond', '🛡️ Shield', '🌟 Star', '🍀 Clover', '⚓ Anchor'],
    columns: 4,
  );
  terminice.success('Chosen Icon: ${icon.join(", ")}');

  // 5. tagSelector() - Interactive Chips
  terminice.detail('Tag Selector:');
  final tags = terminice.tagSelector(
    prompt: 'Select Issue Labels',
    tags: ['bug', 'enhancement', 'documentation', 'good-first-issue', 'performance', 'security'],
  );
  terminice.success('Labels: ${tags.join(", ")}');

  // 6. toggleGroup() - On/Off switches
  terminice.detail('Toggle Group:');
  final toggles = terminice.toggleGroup(
    'Daemon Settings',
    items: const [
      ToggleItem('Auto-restart on crash', initialOn: true),
      ToggleItem('Verbose syslog logging', initialOn: false),
      ToggleItem('Notify on deploy hook', initialOn: true),
    ],
  );
  terminice.success('Toggles: $toggles');

  // 7. commandPalette() - VS Code style command launcher
  terminice.detail('Command Palette:');
  final cmd = terminice.commandPalette(
    'Quick Action Palette',
    commands: [
      CommandEntry(id: 'build', title: 'Build Release Binary', subtitle: 'dart compile exe'),
      CommandEntry(id: 'test', title: 'Run Test Suite', subtitle: 'dart test --coverage'),
      CommandEntry(id: 'format', title: 'Format Codebase', subtitle: 'dart format .'),
      CommandEntry(id: 'analyze', title: 'Lint Code Analyzer', subtitle: 'dart analyze'),
    ],
  );
  if (cmd != null) {
    terminice.success('Executed Command: ${cmd.title} (${cmd.subtitle})');
  }
}

// ============================================================================
// 4. PICKERS
// ============================================================================
void runPickersShowcase() {
  terminice.newline();
  terminice.info('Category: Pickers');

  // 1. colorPicker()
  terminice.detail('Color Picker (ANSI Swatches & Hex):');
  final color = terminice.colorPicker(
    'Terminal Accent Color',
    initialHex: '#00E5FF',
    cols: 20,
    rows: 6,
  );
  terminice.success('Color chosen: ${color ?? "cancelled"}');

  // 2. datePicker()
  terminice.detail('Date Picker (Interactive Calendar):');
  final pickedDate = terminice.datePicker(
    'Select Appointment Date',
    initialDate: DateTime.now(),
  );
  terminice.success('Date chosen: ${pickedDate?.toIso8601String().split('T').first ?? "cancelled"}');

  // 3. filePicker()
  terminice.detail('File Picker (Filesystem Explorer):');
  final file = terminice.filePicker(
    'Select File from Workspace',
    startDirectory: Directory.current,
  );
  terminice.success('File chosen: ${file ?? "cancelled"}');

  // 4. pathPicker()
  terminice.detail('Path Picker (Folder Selection):');
  final folder = terminice.pathPicker(
    'Select Directory Target',
    startDirectory: Directory.current,
  );
  terminice.success('Directory chosen: ${folder ?? "cancelled"}');
}

// ============================================================================
// 5. PROGRESS & SPINNERS
// ============================================================================
Future<void> runProgressShowcase() async {
  terminice.newline();
  terminice.info('Category: Progress Indicators & Tasks');

  // 1. loadingSpinner()
  final spinner = terminice.loadingSpinner('Analyzing dependencies...');
  for (int i = 0; i < 15; i++) {
    spinner.show(i);
    await Future.delayed(const Duration(milliseconds: 60));
  }
  spinner.clear();
  terminice.success('Dependencies verified.');

  // 2. progressDots()
  final dots = terminice.progressDots('Connecting to cluster');
  for (int i = 0; i < 10; i++) {
    dots.show(phase: i);
    await Future.delayed(const Duration(milliseconds: 100));
  }
  dots.clear();
  terminice.success('Cluster connected.');

  // 3. progressBar()
  final pbar = terminice.progressBar('Downloading packages');
  for (int i = 0; i <= 100; i += 10) {
    pbar.show(current: i, total: 100, shimmerPhase: i);
    await Future.delayed(const Duration(milliseconds: 60));
  }
  pbar.clear();
  terminice.success('All packages downloaded.');

  // 4. async task()
  await terminice.task<String>(
    'Compiling native executable',
    run: () async {
      await Future.delayed(const Duration(milliseconds: 800));
      return 'bin/app.exe';
    },
    success: 'Compiled native executable successfully',
  );

  // 5. progressTask()
  await terminice.progressTask<void>(
    'Optimizing byte code assets',
    total: 10,
    run: (progress) async {
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 70));
        progress.update(current: i, message: 'Processing chunk $i/10');
      }
    },
    success: 'All assets optimized and compressed',
  );
}

// ============================================================================
// 6. MESSAGE PRIMITIVES
// ============================================================================
void runMessagesShowcase() {
  terminice.newline();
  terminice.info('Category: Formatted Status Messages');

  terminice.info('info(): Normal informative progress line');
  terminice.success('success(): Completed operation with checkmark');
  terminice.warn('warn(): Warning indicator for non-fatal concerns');
  terminice.error('error(): Critical failure or validation error');
  terminice.detail('detail(): Secondary context information line');
  terminice.log('log(): Standard unformatted terminal log line');
}

// ============================================================================
// 7. MULTI-STEP FLOW WIZARD
// ============================================================================
void runFlowShowcase() {
  terminice.newline();
  terminice.info('Category: Multi-Step Flow Wizard (terminice.flow)');

  final result = terminice
      .flow('Cloud Microservice Deployment Wizard')
      .progress()
      .text(
        'serviceName',
        'Service Name',
        placeholder: 'auth-service',
        reviewLabel: 'Service Name',
      )
      .select<String>(
        'environment',
        'Target Cloud Environment',
        options: ['Development (k8s-dev)', 'Staging (k8s-stage)', 'Production (k8s-prod)'],
        reviewLabel: 'Environment',
      )
      .checkboxes<String>(
        'addons',
        'Service Add-ons',
        options: ['Redis Cache', 'PostgreSQL DB', 'Kafka Message Bus', 'Jaeger Tracing'],
        reviewLabel: 'Add-ons',
        summarize: (items, _) => items.isEmpty ? 'None' : items.join(', '),
      )
      .confirm(
        'autoScale',
        prompt: 'Auto-Scaling',
        message: 'Enable Horizontal Pod Autoscaler (HPA)?',
        reviewLabel: 'Auto-Scaling',
        summarize: (val, _) => val ? 'Enabled' : 'Disabled',
      )
      .review(title: 'Review Deployment Plan')
      .run();

  if (result.cancelled) {
    terminice.warn('Deployment flow was cancelled.');
    return;
  }

  terminice.success('Deployment queued!');
  terminice.detail('Service: ${result.string("serviceName")}');
  terminice.detail('Env:     ${result.string("environment")}');
  terminice.detail('Addons:  ${result.list<String>("addons").join(", ")}');
  terminice.detail('HPA:     ${result.flag("autoScale")}');
}

// ============================================================================
// 8. INTERACTIVE CONFIG EDITOR
// ============================================================================
void runConfigEditorShowcase() {
  terminice.newline();
  terminice.info('Category: Interactive Config Editor');

  final config = terminice.configEditor(
    'Microservice Configuration',
    fields: [
      ThemeConfigurable(
        key: 'editorTheme',
        label: 'Editor Theme',
        value: 'ocean',
        description: 'Live-updating color theme for the configuration editor',
      ),
      StringConfigurable(
        key: 'serverName',
        label: 'Server Name',
        value: 'api-gateway',
        required: true,
        description: 'Hostname identifier for the service',
      ),
      NumberConfigurable(
        key: 'httpPort',
        label: 'HTTP Port',
        value: 8080,
        min: 1024,
        max: 65535,
        integerOnly: true,
        description: 'Incoming TCP port',
      ),
      EnumConfigurable(
        key: 'logLevel',
        label: 'Log Level',
        value: 'info',
        options: ['debug', 'info', 'warn', 'error'],
        description: 'Application log verbosity',
      ),
      BoolConfigurable(
        key: 'enableTls',
        label: 'Enable TLS/SSL',
        value: true,
        description: 'Serve traffic encrypted using HTTPS',
      ),
      PasswordConfigurable(
        key: 'jwtSecret',
        label: 'JWT Signature Secret',
        value: 'super-secret-key-123',
        description: 'HMAC key used to sign authorization tokens',
      ),
    ],
  );

  if (config != null) {
    terminice.success('Configuration saved successfully!');
    for (final entry in config.toMap().entries) {
      terminice.detail('${entry.key}: ${entry.value}');
    }
  } else {
    terminice.warn('Configuration editor was cancelled.');
  }
}

// ============================================================================
// 9. GUIDES & REFERENCE
// ============================================================================
void runGuidesShowcase() {
  terminice.newline();
  terminice.info('Category: Guides & Reference Displays');

  // 1. hotkeyGuide()
  terminice.hotkeyGuide(
    title: 'Keyboard Shortcuts Reference',
    shortcuts: [
      ['↑ / ↓', 'Navigate items in menus and lists'],
      ['Space', 'Toggle checkboxes and switches'],
      ['Enter', 'Confirm selection or advance form'],
      ['Esc', 'Cancel prompt and return default/null'],
      ['Tab / Shift+Tab', 'Cycle through form fields and controls'],
      ['Ctrl+C', 'Exit or abort interactive CLI app'],
    ],
  );

  // 2. cheatSheet()
  terminice.cheatSheet(
    'Git Workflow Cheat Sheet',
    columns: const ['Action', 'Command', 'Explanation'],
    entries: const [
      ['Branch', 'git switch -c <name>', 'Create and switch to new branch'],
      ['Commit', 'git commit -am "msg"', 'Stage modified files and commit'],
      ['Rebase', 'git pull --rebase', 'Fetch remote and rebase local commits'],
      ['Stash', 'git stash -u', 'Save working state including untracked'],
    ],
  );

  // 3. helpCenter()
  terminice.helpCenter(
    title: 'Terminice Documentation & Help',
    docs: [
      HelpDoc(
        id: '1',
        title: 'Universal Theming',
        content: 'Terminice components automatically adapt to themes. Use terminice.ocean, terminice.neon, terminice.matrix, etc.',
      ),
      HelpDoc(
        id: '2',
        title: 'Cross-Platform Windows Support',
        content: 'Native Win32 console integration ensures full arrow key navigation, VT escape codes, and non-blocking key reads on Windows.',
      ),
      HelpDoc(
        id: '3',
        title: 'Zero Boilerplate',
        content: 'Call any component directly from the global terminice instance without managing state trees or widget lifecycles.',
      ),
    ],
  );
}

// ============================================================================
// 10. THEME SWITCHER DEMO
// ============================================================================
void runThemesShowcase() {
  terminice.newline();
  terminice.info('Category: Theme Gallery & Showcase');

  final selection = terminice.searchSelector(
    prompt: 'Select Theme Action (or choose a theme to preview)',
    options: [
      '🎨 Launch Built-in Interactive Theme Demo (terminice.themeDemo)',
      'ocean (Cool cyan/blue)',
      'neon (Synthwave cyberpunk)',
      'pastel (Soft gentle palette)',
      'fire (High energy red & orange)',
      'matrix (Hacker green phosphor)',
      'arcane (Mystical ancient tome)',
      'phantom (Ghostly apparition)',
      'dark (Crisp high-contrast default)',
      'monochrome (Minimalist ASCII)',
      'minimal (Display mode: no borders)',
      'compact (Display mode: borders, no hints)',
      'verbose (Display mode: full borders with grid hints)',
    ],
  );

  if (selection.isEmpty) return;

  final choice = selection.first;
  if (choice.contains('themeDemo')) {
    terminice.themeDemo();
    return;
  }

  final themeName = choice.split(' ').first;
  terminice.newline();
  terminice.success('Previewing theme: $themeName');

  switch (themeName) {
    case 'ocean':
      terminice.ocean.confirm(message: 'This is the Ocean theme. Cool and refreshing blue tones.');
    case 'neon':
      terminice.neon.confirm(message: 'This is the Neon theme. High-contrast electric vibrancy.');
    case 'pastel':
      terminice.pastel.confirm(message: 'This is the Pastel theme. Soft, gentle aesthetic palette.');
    case 'fire':
      terminice.fire.confirm(message: 'This is the Fire theme. Energetic red and orange flames.');
    case 'matrix':
      terminice.matrix.confirm(message: 'This is the Matrix theme. Hacker green phosphor glow.');
    case 'arcane':
      terminice.arcane.confirm(message: 'This is the Arcane theme. Mystical ancient tome styling.');
    case 'phantom':
      terminice.phantom.confirm(message: 'This is the Phantom theme. Ghostly apparition palette.');
    case 'dark':
      terminice.dark.confirm(message: 'This is the Dark theme. Crisp high-contrast default.');
    case 'minimal':
      terminice.minimal.confirm(message: 'This is the Minimal display mode. Clean and unadorned.');
    case 'compact':
      terminice.compact.confirm(message: 'This is the Compact display mode. Boxed without hints.');
    case 'verbose':
      terminice.verbose.confirm(message: 'This is the Verbose display mode. Full framed with grid hints.');
    default:
      terminice.monochrome.confirm(message: 'This is the Monochrome theme. Pure retro ASCII.');
  }
}

// ============================================================================
// FULL INTERACTIVE TOUR
// ============================================================================
Future<void> runFullTour() async {
  terminice.newline();
  terminice.success('Starting the Full Interactive Tour of Terminice! 🚀');

  runTextInputShowcase();
  runNumericRangeShowcase();
  runSelectorsShowcase();
  runPickersShowcase();
  await runProgressShowcase();
  runMessagesShowcase();
  runFlowShowcase();
  runConfigEditorShowcase();
  runGuidesShowcase();
  runThemesShowcase();

  terminice.newline();
  terminice.success('Full tour completed successfully! 🎉');
}
