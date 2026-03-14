import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_state.dart';

class TextInputOverlay extends StatefulWidget {
  const TextInputOverlay({
    super.key,
    required this.inputState,
    required this.onSubmit,
    required this.onDismiss,
  });

  final TextInputState inputState;
  final ValueChanged<String> onSubmit;
  final VoidCallback onDismiss;

  @override
  State<TextInputOverlay> createState() => _TextInputOverlayState();
}

class _TextInputOverlayState extends State<TextInputOverlay> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.inputState.prefill ?? '');
    // Auto-focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(TextInputOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the server pushes an update_input with new prefill, update the field
    if (widget.inputState.prefill != oldWidget.inputState.prefill &&
        widget.inputState.prefill != null) {
      _controller.text = widget.inputState.prefill!;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text;
    widget.onSubmit('$text\r');
  }

  TextInputType _keyboardType() {
    switch (widget.inputState.inputType) {
      case 'number':
        return TextInputType.number;
      case 'seed':
      case 'seed-selection':
        // Seed input uses alphanumeric characters
        return TextInputType.text;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _inputFormatters() {
    if (widget.inputState.inputType == 'number') {
      return <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String promptText =
        widget.inputState.prompt ?? 'Input (ESC to cancel):';
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Re-focus the input if user taps the backdrop
          _focusNode.requestFocus();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: bottomInset + 8,
              ),
              child: Material(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(8),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        promptText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (KeyEvent event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.escape) {
                            widget.onDismiss();
                          }
                        },
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLength: widget.inputState.maxlen,
                          keyboardType: _keyboardType(),
                          inputFormatters: _inputFormatters(),
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade900,
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide:
                                  const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide:
                                  const BorderSide(color: Colors.white),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: widget.onDismiss,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade700,
                            ),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
