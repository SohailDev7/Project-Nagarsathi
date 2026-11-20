// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';

/// Modes that must have **zero** contrast violations.
///
/// The baseline is recorded with this set empty so the suite stays green while
/// screens are migrated. To turn the gate on for dark mode, change this to:
///
/// ```dart
/// const Set<Brightness> auditFailingModes = <Brightness>{Brightness.dark};
/// ```
///
/// Every mode in the set makes [auditScreen] fail with the violation count and
/// a list of the offending strings.
const Set<Brightness> auditFailingModes = <Brightness>{};

/// Phone-sized audit viewport. The captured image is 1082 x 2402 px.
const Size auditLogicalSize = Size(412, 915);
const double auditPixelRatio = 2.625;

/// PNG captures and the full text report are written here.
const String auditOutputDir = 'build/theme_audit';

/// Normal text needs 4.5:1; large text (>= 24 px or >= 18.66 px bold) 3:1.
const double auditNormalTextRatio = 4.5;
const double auditLargeTextRatio = 3.0;

/// One measured Text/EditableText run.
class ThemeAuditEntry {
  ThemeAuditEntry({
    required this.text,
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.requiredRatio,
    required this.fontSize,
    required this.fontWeight,
    required this.textOpacity,
  });

  final String text;

  /// The colour the user actually sees (text colour composited over the
  /// sampled background using the effective opacity).
  final Color foreground;

  /// Most common pixel colour behind the text rect, text pixels ignored.
  final Color background;

  final double ratio;
  final double requiredRatio;
  final double fontSize;
  final FontWeight fontWeight;

  /// Product of the text colour alpha and all ancestor opacities.
  final double textOpacity;

  bool get passes => ratio + 0.005 >= requiredRatio;
  bool get large => requiredRatio == auditLargeTextRatio;
}

/// Everything captured for one screen in one mode.
class ThemeAuditResult {
  ThemeAuditResult({
    required this.screen,
    required this.brightness,
    required this.imagePath,
    required this.entries,
    required this.skipped,
    this.note,
  });

  final String screen;
  final Brightness brightness;
  final String imagePath;
  final List<ThemeAuditEntry> entries;
  final int skipped;
  final String? note;

  int get violations => entries.where((entry) => !entry.passes).length;

  bool get passed => violations == 0;
}

/// Every audit call appends here so the end-of-run report can group by screen.
final List<ThemeAuditResult> themeAuditResults = <ThemeAuditResult>[];

/// Loads Nunito and MaterialIcons once for the whole file.
///
/// Without this the test font is Ahem, which changes text metrics and makes the
/// captured PNGs unreadable. `FLUTTER_ROOT` must point at a Flutter SDK that
/// contains `bin/cache/artifacts/material_fonts`.
Future<void> loadAuditFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nunito = FontLoader('Nunito');
  for (final weight in <int>[400, 600, 700, 800, 900]) {
    final file = File('assets/fonts/Nunito-$weight.ttf');
    if (!file.existsSync()) continue;
    nunito.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await nunito.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  final iconFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/'
    'materialicons-regular.otf',
  );
  if (iconFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(iconFile.readAsBytesSync())),
      );
    await icons.load();
  }
}

/// Pumps [home] inside the real [buildAppTheme] theme, waits for it to settle,
/// captures a PNG, measures every visible Text/EditableText and records the
/// outcome.
///
/// This is the one-line entry point for later migration batches:
///
/// ```dart
/// await auditScreen(
///   tester,
///   screen: 'SettingsScreen',
///   brightness: Brightness.dark,
///   home: const SettingsScreen(),
/// );
/// ```
///
/// [interact] opens dialogs/sheets or fills fields before the capture. Set
/// [settleAfterInteract] to false for transient UI such as a snackbar.
Future<ThemeAuditResult> auditScreen(
  WidgetTester tester, {
  required String screen,
  required Brightness brightness,
  required Widget home,
  Future<void> Function(WidgetTester tester)? interact,
  bool settleAfterInteract = true,
  bool precacheAssets = true,
  String? note,
}) async {
  _prepareAuditView(tester);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: brightness),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (interact != null) {
    await interact(tester);
    if (settleAfterInteract) {
      await tester.pumpAndSettle();
    } else {
      // Long enough for the snackbar/sheet entrance but shorter than its life.
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  if (precacheAssets) {
    await _precacheAuditAssets(tester);
    await tester.pump();
  }

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final imagePath =
      '$auditOutputDir/${_slug(screen)}_${brightness.name}.png';
  final captured = await _captureBoundary(tester, boundary, imagePath);

  final entries = _measureVisibleText(
    tester,
    boundary,
    captured,
  )..sort((a, b) => a.ratio.compareTo(b.ratio));

  final result = ThemeAuditResult(
    screen: screen,
    brightness: brightness,
    imagePath: imagePath,
    entries: entries,
    skipped: _lastSkippedCount,
    note: note,
  );
  themeAuditResults.add(result);

  if (auditFailingModes.contains(brightness) && result.violations > 0) {
    final worst = entries.take(5).map((entry) {
      return '"${entry.text}" ${entry.ratio.toStringAsFixed(2)}:1';
    }).join('; ');
    expect(
      result.violations,
      0,
      reason:
          '$screen (${brightness.name}) has ${result.violations} contrast '
          'violation(s). Worst: $worst',
    );
  }

  return result;
}

/// Prints and writes the grouped report for every [auditScreen] call so far.
///
/// Call this from `tearDownAll` in the audit test file.
void writeThemeAuditReport() {
  final buffer = StringBuffer();
  buffer.writeln('=' * 78);
  buffer.writeln('NagarSathi theme contrast audit');
  buffer.writeln('=' * 78);
  buffer.writeln(
    'Viewport: ${auditLogicalSize.width.toStringAsFixed(0)} x '
    '${auditLogicalSize.height.toStringAsFixed(0)} logical @ '
    '${auditPixelRatio}x',
  );
  buffer.writeln(
    'Thresholds: ${auditNormalTextRatio.toStringAsFixed(1)}:1 normal, '
    '${auditLargeTextRatio.toStringAsFixed(1)}:1 large '
    '(>= 24 px or >= 18.66 px bold)',
  );
  buffer.writeln(
    'Fail modes: ${auditFailingModes.isEmpty ? 'none (baseline only)' : auditFailingModes.map((mode) => mode.name).join(', ')}',
  );
  buffer.writeln();

  // Preserve first-seen screen order; group light and dark together.
  final groups = <String, List<ThemeAuditResult>>{};
  for (final result in themeAuditResults) {
    groups.putIfAbsent(result.screen, () => <ThemeAuditResult>[]).add(result);
  }

  var totalEntries = 0;
  var totalViolations = 0;

  for (final group in groups.entries) {
    final screenResults = group.value;
    final note = screenResults
        .map((result) => result.note)
        .firstWhere((value) => value != null, orElse: () => null);

    buffer.writeln('-' * 78);
    buffer.writeln(group.key);
    buffer.writeln('-' * 78);
    if (note != null) buffer.writeln('NOTE: $note');

    for (final result in screenResults) {
      totalEntries += result.entries.length;
      totalViolations += result.violations;

      buffer.writeln(
        '  [${result.brightness.name}] '
        '${result.entries.length} text runs, '
        '${result.violations} violation(s), '
        '${result.skipped} skipped (transparent/empty)',
      );
      buffer.writeln('  PNG: ${result.imagePath}');
      buffer.writeln(
        '  ${'ratio'.padLeft(6)}  ${'need'.padLeft(4)}  '
        '${'text'.padRight(46)}  foreground  background  size',
      );

      for (final entry in result.entries) {
        final verdict = entry.passes ? 'pass' : 'FAIL';
        buffer.writeln(
          '  ${entry.ratio.toStringAsFixed(2).padLeft(6)}  '
          '${entry.requiredRatio.toStringAsFixed(1).padLeft(4)}  '
          '${_clip(entry.text).padRight(46)}  '
          '${_hex(entry.foreground)}${_alphaSuffix(entry.textOpacity)}  '
          '${_hex(entry.background)}  '
          '${entry.fontSize.toStringAsFixed(1)}px '
          '${_weightLabel(entry.fontWeight)} $verdict',
        );
      }
      buffer.writeln();
    }
  }

  buffer.writeln('=' * 78);
  buffer.writeln(
    'Baseline: ${themeAuditResults.length} captures, '
    '$totalEntries text runs, $totalViolations violation(s).',
  );
  if (totalViolations > 0) {
    buffer.writeln('Violations (worst first per screen):');
    for (final result in themeAuditResults) {
      final failures = result.entries.where((entry) => !entry.passes);
      if (failures.isEmpty) continue;
      buffer.writeln(
        '  ${result.screen} [${result.brightness.name}] '
        '(${failures.length})',
      );
      for (final entry in failures) {
        buffer.writeln(
          '    ${entry.ratio.toStringAsFixed(2)}:1 '
          '(need ${entry.requiredRatio.toStringAsFixed(1)}) '
          '"${_clip(entry.text)}" '
          '${_hex(entry.foreground)} on ${_hex(entry.background)}',
        );
      }
    }
  }
  buffer.writeln('=' * 78);

  Directory(auditOutputDir).createSync(recursive: true);
  final reportPath = '$auditOutputDir/report.txt';
  File(reportPath).writeAsStringSync(buffer.toString());
  print(buffer.toString());
  print('Theme audit report written to $reportPath');
}

// ---------------------------------------------------------------------------
// View setup
// ---------------------------------------------------------------------------

void _prepareAuditView(WidgetTester tester) {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );

  tester.view.devicePixelRatio = auditPixelRatio;
  tester.view.physicalSize = Size(
    auditLogicalSize.width * auditPixelRatio,
    auditLogicalSize.height * auditPixelRatio,
  );
  addTearDown(tester.view.reset);
}

Future<void> _precacheAuditAssets(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.binding.rootElement;
    if (context == null) return;
    for (final asset in <String>[
      'assets/icon/icon.png',
      'assets/icon/google_g.png',
    ]) {
      try {
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (error, stack) {},
        );
      } catch (_) {
        // Missing optional artwork must not abort the audit.
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Capture
// ---------------------------------------------------------------------------

class _CapturedImage {
  _CapturedImage({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

Future<_CapturedImage> _captureBoundary(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  String path,
) async {
  late _CapturedImage captured;
  late Uint8List pngBytes;

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: auditPixelRatio);
    try {
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      captured = _CapturedImage(
        rgba: raw!.buffer.asUint8List(
          raw.offsetInBytes,
          raw.lengthInBytes,
        ),
        width: image.width,
        height: image.height,
      );
      pngBytes = png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  });

  Directory(auditOutputDir).createSync(recursive: true);
  File(path).writeAsBytesSync(pngBytes, flush: true);
  return captured;
}

// ---------------------------------------------------------------------------
// Render-tree extraction
// ---------------------------------------------------------------------------

class _TextTarget {
  _TextTarget({
    required this.text,
    required this.element,
    required this.box,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
  });

  final String text;
  final Element element;
  final RenderBox box;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
}

int _lastSkippedCount = 0;

List<ThemeAuditEntry> _measureVisibleText(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  _CapturedImage image,
) {
  final targets = _collectTargets(tester);
  final entries = <ThemeAuditEntry>[];
  var skipped = 0;

  final scaleX = image.width / boundary.size.width;
  final scaleY = image.height / boundary.size.height;
  final bounds = Offset.zero & boundary.size;

  for (final target in targets) {
    // Text on a page covered by a dialog or bottom sheet is dimmed by the
    // barrier and cannot be interacted with; audit only the top-most route.
    final route = ModalRoute.of(target.element);
    if (route != null && !route.isCurrent) {
      skipped += 1;
      continue;
    }

    final opacity = _ancestorOpacity(target.element) * target.color.a;
    if (opacity <= 0.01) {
      skipped += 1; // Fully transparent text is not visible.
      continue;
    }

    final rect = _globalRect(target.box, boundary);
    if (rect == null) {
      skipped += 1;
      continue;
    }
    final visible = rect.intersect(bounds);
    if (visible.width < 1 || visible.height < 1) {
      skipped += 1; // Scrolled/clipped out of view.
      continue;
    }

    // Text behind an opaque overlay (a snackbar, for example) is not actually
    // readable. Hit-testing the rect centre catches that: the paragraph is
    // missing from the hit path when something is painted above it.
    if (!_reachesTarget(tester, target.box, visible.center)) {
      skipped += 1;
      continue;
    }

    final pixelRect = Rect.fromLTRB(
      visible.left * scaleX,
      visible.top * scaleY,
      visible.right * scaleX,
      visible.bottom * scaleY,
    );
    final background = _sampleBackground(image, pixelRect, target.color);
    if (background == null) {
      skipped += 1;
      continue;
    }

    final foreground = Color.alphaBlend(
      target.color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      background,
    );
    final ratio = _contrastRatio(foreground, background);
    final large = _isLargeText(target.fontSize, target.fontWeight);

    entries.add(
      ThemeAuditEntry(
        text: target.text,
        foreground: foreground,
        background: background,
        ratio: ratio,
        requiredRatio: large ? auditLargeTextRatio : auditNormalTextRatio,
        fontSize: target.fontSize,
        fontWeight: target.fontWeight,
        textOpacity: opacity.clamp(0.0, 1.0),
      ),
    );
  }

  _lastSkippedCount = skipped;
  return entries;
}

List<_TextTarget> _collectTargets(WidgetTester tester) {
  final targets = <_TextTarget>[];
  final root = tester.binding.rootElement;
  if (root == null) return targets;

  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      _addTextTarget(targets, element, widget);
    } else if (widget is EditableText) {
      _addEditableTarget(targets, element, widget);
    }
    element.visitChildren(visit);
  }

  visit(root);
  return targets;
}

void _addTextTarget(
  List<_TextTarget> targets,
  Element element,
  Text widget,
) {
  final paragraph = _paragraphOf(element);
  if (paragraph == null ||
      !paragraph.attached ||
      !paragraph.hasSize ||
      paragraph.size.isEmpty) {
    return;
  }

  final defaultStyle = DefaultTextStyle.of(element).style;
  final spans = <({String text, TextStyle style})>[];
  _collectLeafStyles(paragraph.text, defaultStyle, spans);
  if (spans.isEmpty) {
    final plain = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (plain.trim().isEmpty) return;
    spans.add((text: plain, style: _paragraphStyle(paragraph, defaultStyle)));
  }

  // Group leaves that share a visual style, so a multi-colour Text.rich is
  // measured once per colour instead of only for its first span.
  final grouped = <String, ({Color color, double size, FontWeight weight, String text})>{};
  for (final span in spans) {
    final text = span.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final style = span.style;
    final color =
        style.color ??
        defaultStyle.color ??
        Theme.of(element).colorScheme.onSurface;
    final size = style.fontSize ?? defaultStyle.fontSize ?? 14;
    final weight =
        style.fontWeight ?? defaultStyle.fontWeight ?? FontWeight.w400;
    final key = '${color.toARGB32()}|$size|${weight.value}';
    final existing = grouped[key];
    grouped[key] = (
      color: color,
      size: size,
      weight: weight,
      text: existing == null ? text : '${existing.text} $text',
    );
  }

  for (final group in grouped.values) {
    targets.add(
      _TextTarget(
        text: group.text,
        element: element,
        box: paragraph,
        color: group.color,
        fontSize: group.size,
        fontWeight: group.weight,
      ),
    );
  }
}

void _addEditableTarget(
  List<_TextTarget> targets,
  Element element,
  EditableText widget,
) {
  final text = widget.controller.text;
  if (text.isEmpty) return;

  final state = (element as StatefulElement).state;
  if (state is! EditableTextState) return;

  final editable = state.renderEditable;
  if (!editable.attached || !editable.hasSize || editable.size.isEmpty) {
    return;
  }

  final defaultStyle = DefaultTextStyle.of(element).style;
  final style = widget.style;
  targets.add(
    _TextTarget(
      text: widget.obscureText ? '*' * text.length : text,
      element: element,
      box: editable,
      color:
          style.color ??
          defaultStyle.color ??
          Theme.of(element).colorScheme.onSurface,
      fontSize: style.fontSize ?? defaultStyle.fontSize ?? 14,
      fontWeight:
          style.fontWeight ?? defaultStyle.fontWeight ?? FontWeight.w400,
    ),
  );
}

RenderParagraph? _paragraphOf(Element element) {
  final root = element.findRenderObject();
  if (root == null) return null;
  RenderParagraph? found;
  void visit(RenderObject node) {
    if (found != null) return;
    if (node is RenderParagraph) {
      found = node;
      return;
    }
    node.visitChildren(visit);
  }

  visit(root);
  return found;
}

void _collectLeafStyles(
  InlineSpan span,
  TextStyle inherited,
  List<({String text, TextStyle style})> out,
) {
  if (span is! TextSpan) return;
  final style = inherited.merge(span.style);
  final text = span.text;
  if (text != null && text.trim().isNotEmpty) {
    out.add((text: text, style: style));
  }
  final children = span.children;
  if (children != null) {
    for (final child in children) {
      _collectLeafStyles(child, style, out);
    }
  }
}

TextStyle _paragraphStyle(RenderParagraph paragraph, TextStyle defaultStyle) {
  return defaultStyle.merge(paragraph.text.style);
}

Rect? _globalRect(RenderBox box, RenderRepaintBoundary boundary) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return null;
  final transform = box.getTransformTo(boundary);
  return MatrixUtils.transformRect(transform, Offset.zero & box.size);
}

/// True when [box] is in the hit-test path at [globalPoint].
///
/// Both RenderParagraph and RenderEditable return true from `hitTestSelf`, so
/// a visible run is always in the path. A snackbar or other opaque overlay
/// above the text stops the hit test first and hides it from the path.
bool _reachesTarget(WidgetTester tester, RenderBox box, Offset globalPoint) {
  final result = tester.hitTestOnBinding(globalPoint);
  return result.path.any((entry) => identical(entry.target, box));
}

double _ancestorOpacity(Element element) {
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Opacity) {
      opacity *= widget.opacity;
    } else if (widget is AnimatedOpacity) {
      opacity *= widget.opacity;
    } else if (widget is FadeTransition) {
      opacity *= widget.opacity.value;
    }
    return true;
  });
  return opacity.clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Pixel sampling
// ---------------------------------------------------------------------------

/// Most common colour inside [rect], ignoring pixels that match the glyph core.
Color? _sampleBackground(
  _CapturedImage image,
  Rect rect,
  Color textColor,
) {
  final left = rect.left.floor().clamp(0, image.width - 1);
  final top = rect.top.floor().clamp(0, image.height - 1);
  final right = rect.right.ceil().clamp(left + 1, image.width);
  final bottom = rect.bottom.ceil().clamp(top + 1, image.height);

  final textR = (textColor.r * 255).round();
  final textG = (textColor.g * 255).round();
  final textB = (textColor.b * 255).round();

  final counts = <int, int>{};
  void tally({required bool ignoreText}) {
    counts.clear();
    for (var y = top; y < bottom; y++) {
      final row = y * image.width;
      for (var x = left; x < right; x++) {
        final index = (row + x) * 4;
        final r = image.rgba[index];
        final g = image.rgba[index + 1];
        final b = image.rgba[index + 2];
        if (ignoreText) {
          final dr = r - textR;
          final dg = g - textG;
          final db = b - textB;
          // Glyph cores only (12/255). Anti-aliased fringes stay, but the
          // background still dominates the histogram.
          if (dr * dr + dg * dg + db * db <= 12 * 12) continue;
        }
        final key = (r << 16) | (g << 8) | b;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }

  tally(ignoreText: true);
  if (counts.isEmpty) tally(ignoreText: false);
  if (counts.isEmpty) return null;

  var best = -1;
  var bestCount = -1;
  for (final entry in counts.entries) {
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return Color(0xFF000000 | best);
}

// ---------------------------------------------------------------------------
// WCAG helpers
// ---------------------------------------------------------------------------

double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrastRatio(Color a, Color b) {
  final first = _relativeLuminance(a);
  final second = _relativeLuminance(b);
  final high = math.max(first, second);
  final low = math.min(first, second);
  return (high + 0.05) / (low + 0.05);
}

bool _isLargeText(double fontSize, FontWeight fontWeight) {
  if (fontSize >= 24) return true;
  return fontSize >= 18.66 && fontWeight.value >= FontWeight.w700.value;
}

// ---------------------------------------------------------------------------
// Report formatting
// ---------------------------------------------------------------------------

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? 'screen' : slug;
}

String _hex(Color color) {
  final r = (color.r * 255).round().clamp(0, 255);
  final g = (color.g * 255).round().clamp(0, 255);
  final b = (color.b * 255).round().clamp(0, 255);
  final value = (r << 16) | (g << 8) | b;
  return '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

String _alphaSuffix(double opacity) {
  if (opacity >= 0.999) return '';
  return '@${opacity.toStringAsFixed(2)}';
}

String _weightLabel(FontWeight weight) {
  return switch (weight) {
    FontWeight.w100 => 'w100',
    FontWeight.w200 => 'w200',
    FontWeight.w300 => 'w300',
    FontWeight.w400 => 'w400',
    FontWeight.w500 => 'w500',
    FontWeight.w600 => 'w600',
    FontWeight.w700 => 'w700',
    FontWeight.w800 => 'w800',
    FontWeight.w900 => 'w900',
    _ => 'w400',
  };
}

String _clip(String value) {
  final flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= 46) return flat;
  return '${flat.substring(0, 43)}...';
}
