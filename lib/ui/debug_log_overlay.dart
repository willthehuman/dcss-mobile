import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/socket_log.dart';

/// Floating debug panel — shows in-app socket log.
/// Tap the ℹ button (bottom-right) to open/close.
class DebugLogOverlay extends ConsumerStatefulWidget {
  const DebugLogOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends ConsumerState<DebugLogOverlay> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = ref.watch(socketLogProvider);

    return Stack(
      children: <Widget>[
        widget.child,
        // Open/close button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'debug_log_fab',
            backgroundColor: Colors.black87,
            onPressed: () => setState(() => _open = !_open),
            child: Icon(
              _open ? Icons.close : Icons.bug_report,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),
        ),
        if (_open)
          Positioned(
            bottom: 64,
            left: 8,
            right: 8,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Material(
              color: Colors.black.withOpacity(0.92),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: <Widget>[
                  // Toolbar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: <Widget>[
                        const Text(
                          'Socket debug log',
                          style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            final String text = lines.reversed.join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                          },
                          child: const Text('Copy',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(socketLogProvider.notifier).clear(),
                          child: const Text('Clear',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  Expanded(
                    child: lines.isEmpty
                        ? const Center(
                            child: Text('No events yet.',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          )
                        : ListView.builder(
                            reverse: false,
                            padding: const EdgeInsets.all(6),
                            itemCount: lines.length,
                            itemBuilder: (BuildContext ctx, int i) {
                              final String line = lines[i];
                              Color color = Colors.white70;
                              if (line.contains('ERROR') ||
                                  line.contains('parse_error') ||
                                  line.contains('THROW')) {
                                color = Colors.redAccent;
                              } else if (line.contains('lobby_complete') ||
                                  line.contains('login_success')) {
                                color = Colors.greenAccent;
                              } else if (line.contains('FRAME')) {
                                color = Colors.cyanAccent;
                              }
                              return Text(
                                line,
                                style:
                                    TextStyle(color: color, fontSize: 10.5),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
