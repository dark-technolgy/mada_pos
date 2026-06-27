import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Captures USB barcode scanner input (rapid keystrokes + Enter/Tab).
///
/// Scanners emulate a keyboard. When keys arrive faster than manual typing,
/// characters are buffered and delivered as one scan on Enter/Tab.
class BarcodeScannerScope extends StatefulWidget {
  const BarcodeScannerScope({
    super.key,
    required this.child,
    required this.onScan,
  });

  final Widget child;
  final ValueChanged<String> onScan;

  @override
  State<BarcodeScannerScope> createState() => _BarcodeScannerScopeState();
}

class _BarcodeScannerScopeState extends State<BarcodeScannerScope> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastCharAt;
  bool _scanMode = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  void _reset() {
    _buffer.clear();
    _lastCharAt = null;
    _scanMode = false;
  }

  bool _isTerminator(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (_isTerminator(event.logicalKey)) {
      final code = _buffer.toString().trim();
      final wasScan = _scanMode && code.isNotEmpty;
      _reset();
      if (wasScan) {
        widget.onScan(code);
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char == null || char.isEmpty) return _scanMode;

    final now = DateTime.now();
    final gapMs = _lastCharAt == null
        ? 999
        : now.difference(_lastCharAt!).inMilliseconds;

    if (gapMs > 100) {
      _buffer.clear();
      _scanMode = false;
    }

    _buffer.write(char);
    _lastCharAt = now;

    if (gapMs < 50 || _buffer.length >= 4) {
      _scanMode = true;
    }

    return _scanMode;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
