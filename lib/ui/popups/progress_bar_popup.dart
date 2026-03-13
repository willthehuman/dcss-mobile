import 'package:flutter/material.dart';

import 'popup_scaffold.dart';
import 'popup_theme.dart';

/// Popup for `progress-bar` ui-push messages.
///
/// Shows a label and progress percentage with a progress bar widget.
class ProgressBarPopup extends StatelessWidget {
  const ProgressBarPopup({
    super.key,
    required this.payload,
    required this.onKeycode,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;

  @override
  Widget build(BuildContext context) {
    final String title =
        (payload['title'] ?? payload['prompt'] ?? 'Loading...').toString();
    final double progress = _extractProgress();

    return PopupScaffold(
      title: title,
      onKeycode: onKeycode,
      showCloseHint: false,
      maxHeightFraction: 0.3,
      child: Padding(
        padding: PopupTheme.popupPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress >= 0 ? progress : null,
                backgroundColor: PopupTheme.divider,
                color: PopupTheme.accentColor,
                minHeight: 12,
              ),
            ),
            if (progress >= 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).round()}%',
                style: PopupTheme.bodyStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _extractProgress() {
    final dynamic pct = payload['percent'] ?? payload['progress'];
    if (pct == null) return -1;
    if (pct is num) {
      if (pct > 1) return pct / 100.0;
      return pct.toDouble();
    }
    final double? parsed = double.tryParse(pct.toString());
    if (parsed == null) return -1;
    if (parsed > 1) return parsed / 100.0;
    return parsed;
  }
}
