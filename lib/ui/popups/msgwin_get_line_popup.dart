import 'package:flutter/material.dart';

import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `msgwin-get-line` ui-push messages.
///
/// Prompt for a line of text in the message window area.
/// Used for various in-game prompts (chat, annotations, etc.).
class MsgwinGetLinePopup extends StatefulWidget {
  const MsgwinGetLinePopup({
    super.key,
    required this.payload,
    required this.onKeycode,
    required this.onTextInput,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;
  final ValueChanged<String> onTextInput;

  @override
  State<MsgwinGetLinePopup> createState() => _MsgwinGetLinePopupState();
}

class _MsgwinGetLinePopupState extends State<MsgwinGetLinePopup> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final String prefill =
        (widget.payload['prefill'] ?? '').toString();
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
    final String prompt =
        (widget.payload['prompt'] ?? widget.payload['title'] ?? 'Enter text:')
            .toString();

    return PopupScaffold(
      title: null,
      onKeycode: widget.onKeycode,
      showCloseHint: false,
      maxHeightFraction: 0.35,
      child: Padding(
        padding: PopupTheme.popupPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(prompt, style: PopupTheme.bodyStyle),
            const SizedBox(height: 8),
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
                  onPressed: () => widget.onKeycode(27),
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
