import 'package:flutter/material.dart';

import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `seed-selection` ui-push messages.
///
/// Custom seed input for new games. Shows a text input field
/// and confirmation button. Sends the entered seed to the server.
class SeedSelectionPopup extends StatefulWidget {
  const SeedSelectionPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
    required this.onTextInput,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;
  final ValueChanged<String> onTextInput;

  @override
  State<SeedSelectionPopup> createState() => _SeedSelectionPopupState();
}

class _SeedSelectionPopupState extends State<SeedSelectionPopup> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final String prefill =
        (widget.payload['prefill'] ?? widget.payload['seed'] ?? '').toString();
    _controller = TextEditingController(text: prefill);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onTextInput('${_controller.text}\r');
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        (widget.payload['title'] ?? 'Enter Game Seed').toString();
    final String prompt = (widget.payload['prompt'] ?? '').toString();

    return PopupScaffold(
      title: title,
      onKeycode: widget.onKeycode,
      showCloseHint: false,
      maxHeightFraction: 0.4,
      child: Padding(
        padding: PopupTheme.popupPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (prompt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(prompt, style: PopupTheme.bodyStyle),
              ),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: PopupTheme.fontFamily,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Seed value',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade900,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: PopupTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => widget.onKeycode(27), // ESC
                  child: const Text('Cancel',
                      style: TextStyle(color: PopupTheme.mutedColor)),
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
    );
  }
}
