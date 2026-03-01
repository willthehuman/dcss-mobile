import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/tile_loader.dart';
import 'dcss_text_util.dart';
import 'tile_sprite_widget.dart';

class MenuOverlay extends StatelessWidget {
  const MenuOverlay({
    super.key,
    required this.menu,
    required this.onHotkey,
    required this.onDismiss,
    this.tileAssets,
  });

  final MenuState menu;
  final ValueChanged<int> onHotkey;
  final VoidCallback onDismiss;
  final TileAssets? tileAssets;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.62,
              minChildSize: 0.35,
              maxChildSize: 0.95,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Material(
                  color: colors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                menu.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => onHotkey(13),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('OK'),
                            ),
                            IconButton(
                              onPressed: onDismiss,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: menu.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final MenuItemState item = menu.items[index];
                            final String hotkey = item.hotkey <= 0
                                ? ''
                                : String.fromCharCode(item.hotkey);

                            final bool hasSprite =
                                item.tiles.isNotEmpty && tileAssets != null;

                            return ListTile(
                              dense: true,
                              onTap: () => onHotkey(item.hotkey),
                              leading: hasSprite
                                  ? TileSpriteWidget(
                                      tileIndex: item.tiles.first,
                                      resolver: tileAssets!.tileIndexResolver,
                                      sheetPaths: tileAssets!.sheetPaths,
                                      size: 32,
                                    )
                                  : null,
                              title: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      hotkey,
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: DcssTextUtil.parseColoredText(
                                          item.text,
                                          Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: List.generate(26 + 7, (int index) {
                              int code;
                              String char;
                              double width = 34;

                              if (index == 0) {
                                code = 13;
                                char = 'Enter';
                                width = 60;
                              } else if (index == 1) {
                                code = 32;
                                char = 'Space';
                                width = 60;
                              } else if (index == 2) {
                                code = 42;
                                char = '*';
                              } else if (index == 3) {
                                code = 43;
                                char = '+';
                              } else if (index == 4) {
                                code = 45;
                                char = '-';
                              } else if (index == 5) {
                                code = 63;
                                char = '?';
                              } else if (index == 6) {
                                code = 33;
                                char = '!';
                              } else {
                                code = 97 + (index - 7);
                                char = String.fromCharCode(code);
                              }

                              return OutlinedButton(
                                onPressed: () => onHotkey(code),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(width, 32),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(char),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
