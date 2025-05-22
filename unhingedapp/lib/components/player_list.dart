import 'package:flutter/material.dart';
import '../components/player_list_item.dart'; // Import the new component

class PlayerList extends StatelessWidget {
  final Map<dynamic, dynamic> players;
  final String currentPlayerId;

  const PlayerList({
    super.key,
    required this.players,
    required this.currentPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(child: Text('No players yet.'));
    }
    return ListView(
      children:
          players.entries.map((entry) {
            final playerId = entry.key as String;
            final playerData = entry.value as Map<dynamic, dynamic>;
            final playerName =
                playerData['name'] as String? ?? 'Player $playerId';
            final isHost = playerData['isHost'] as bool? ?? false;
            return PlayerListItem(
              playerName: playerName,
              playerId: playerId,
              currentPlayerId: currentPlayerId,
              isHost: isHost,
            );
          }).toList(),
    );
  }
}
