import 'package:flutter/material.dart';

import '../game/game_state.dart';

class MessageLogWidget extends StatelessWidget {
  const MessageLogWidget({
    super.key,
    required this.messages,
    required this.fontSize,
  });

  final List<GameMessage> messages;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final GameMessage? latest = messages.isEmpty ? null : messages.last;
    final Color messageColor = _channelToColor(latest?.channel ?? 0);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => _showLogSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              latest?.text ?? 'No messages yet.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: messageColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    final List<GameMessage> recent =
        messages.length <= 100 ? messages : messages.sublist(messages.length - 100);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: recent.length,
              itemBuilder: (BuildContext context, int index) {
                final GameMessage msg = recent[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: _channelToColor(msg.channel),
                      fontSize: fontSize,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _channelToColor(int channel) {
    switch (channel) {
      case 1:
        return Colors.grey.shade300;
      case 4:
        return Colors.yellow.shade300;
      case 7:
        return Colors.red.shade300;
      case 9:
        return Colors.lightBlue.shade200;
      case 0:
      default:
        return Colors.white;
    }
  }
}
