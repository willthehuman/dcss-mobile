import 'package:flutter/material.dart';

import 'describe_cards_popup.dart';
import 'describe_feature_popup.dart';
import 'describe_generic_popup.dart';
import 'describe_god_popup.dart';
import 'describe_item_popup.dart';
import 'describe_monster_popup.dart';
import 'describe_spell_popup.dart';
import 'formatted_scroller_popup.dart';
import 'msgwin_get_line_popup.dart';
import 'newgame_random_combo_popup.dart';
import 'progress_bar_popup.dart';
import 'seed_selection_popup.dart';

/// Dispatcher widget that reads the `type` field from a ui-push payload
/// and renders the appropriate popup widget.
class UiPopupOverlay extends StatelessWidget {
  const UiPopupOverlay({
    super.key,
    required this.uiType,
    required this.payload,
    required this.onKeycode,
    required this.onTextInput,
  });

  final String uiType;
  final Map<String, dynamic> payload;
  final ValueChanged<int> onKeycode;
  final ValueChanged<String> onTextInput;

  @override
  Widget build(BuildContext context) {
    switch (uiType) {
      case 'describe-item':
        return DescribeItemPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'describe-monster':
        return DescribeMonsterPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'describe-spell':
        return DescribeSpellPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'describe-god':
        return DescribeGodPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'describe-feature-wide':
        return DescribeFeaturePopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'describe-generic':
        return DescribeGenericPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'describe-cards':
        return DescribeCardsPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'formatted-scroller':
        return FormattedScrollerPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'progress-bar':
        return ProgressBarPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      case 'seed-selection':
        return SeedSelectionPopup(
          payload: payload,
          onKeycode: onKeycode,
          onTextInput: onTextInput,
        );
      case 'msgwin-get-line':
        return MsgwinGetLinePopup(
          payload: payload,
          onKeycode: onKeycode,
          onTextInput: onTextInput,
        );
      case 'newgame-random-combo':
        return NewgameRandomComboPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
      default:
        // Fallback for unrecognized types: use generic
        return DescribeGenericPopup(
          payload: payload,
          onKeycode: onKeycode,
        );
    }
  }
}
