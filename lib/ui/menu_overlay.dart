import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/tile_loader.dart';
import 'dcss_text_util.dart';
import 'tile_sprite_widget.dart';

class MenuOverlay extends StatefulWidget {
  const MenuOverlay({
    super.key,
    required this.menu,
    required this.onHotkey,
    required this.onDismiss,
    this.tileAssets,
    this.titlePrompt,
  });

  final MenuState menu;
  final ValueChanged<int> onHotkey;
  final VoidCallback onDismiss;
  final TileAssets? tileAssets;
  final TitlePromptState? titlePrompt;

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.titlePrompt != null &&
        widget.titlePrompt!.prefill.isNotEmpty) {
      _searchController.text = widget.titlePrompt!.prefill;
    }
  }

  @override
  void didUpdateWidget(MenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If title prompt was just activated, focus the search field
    if (widget.titlePrompt != null && oldWidget.titlePrompt == null) {
      _searchController.clear();
      if (widget.titlePrompt!.prefill.isNotEmpty) {
        _searchController.text = widget.titlePrompt!.prefill;
      }
      _searchFocusNode.requestFocus();
    }
    // If title prompt was removed, clear the search
    if (widget.titlePrompt == null && oldWidget.titlePrompt != null) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Send each character as a key press to the server for filtering.
    // The server handles the actual filtering of menu items.
    // We send the full text by first clearing (Ctrl+U = keycode 21) then
    // sending each character. However, DCSS expects incremental input:
    // just send the last typed character.
    if (value.isNotEmpty) {
      widget.onHotkey(value.codeUnitAt(value.length - 1));
    }
  }

  void _onSearchClear() {
    _searchController.clear();
    // Send ESC to close the search/filter on the server side
    widget.onHotkey(27);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TitlePromptState? prompt = widget.titlePrompt;

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
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
                                widget.menu.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => widget.onHotkey(13),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('OK'),
                            ),
                            IconButton(
                              onPressed: widget.onDismiss,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      // Search/filter bar when title_prompt is active
                      if (prompt != null)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: prompt.prompt.isNotEmpty
                                  ? prompt.prompt
                                  : 'Search...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: _onSearchClear,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: widget.menu.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final MenuItemState item =
                                widget.menu.items[index];
                            final String hotkey = item.hotkey <= 0
                                ? ''
                                : String.fromCharCode(item.hotkey);

                            final bool hasSprite = item.tiles.isNotEmpty &&
                                widget.tileAssets != null;

                            return ListTile(
                              dense: true,
                              onTap: () => widget.onHotkey(item.hotkey),
                              leading: hasSprite
                                  ? TileSpriteWidget(
                                      tileIndex: item.tiles.first,
                                      resolver: widget
                                          .tileAssets!.tileIndexResolver,
                                      sheetPaths:
                                          widget.tileAssets!.sheetPaths,
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
                                        children:
                                            DcssTextUtil.parseColoredText(
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
                                onPressed: () => widget.onHotkey(code),
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
