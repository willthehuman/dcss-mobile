import 'package:flutter/material.dart';

import 'keyboard_layer.dart';

class LayerTabBar extends StatelessWidget {
  const LayerTabBar({
    super.key,
    required this.activeLayer,
    required this.onLayerSelected,
  });

  final KeyboardLayer activeLayer;
  final ValueChanged<KeyboardLayer> onLayerSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: KeyboardLayer.values.map((KeyboardLayer layer) {
          final bool isActive = layer == activeLayer;
          return Expanded(
            child: InkWell(
              onTap: () => onLayerSelected(layer),
              child: Container(
                alignment: Alignment.center,
                color: isActive
                    ? colors.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                child: Text(
                  layer.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? colors.primary : colors.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
