import 'package:flutter/material.dart';

class PlayerListItem extends StatelessWidget {
  final String playerName;
  final String playerId;
  final String currentPlayerId;
  final bool isHost;

  const PlayerListItem({
    super.key,
    required this.playerName,
    required this.playerId,
    required this.currentPlayerId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            playerName.isNotEmpty ? playerName[0].toUpperCase() : 'P',
          ),
        ),
        title: Text(playerName + (playerId == currentPlayerId ? ' (You)' : '')),
        trailing: isHost ? const Chip(label: Text('Host')) : null,
      ),
    );
  }
}
