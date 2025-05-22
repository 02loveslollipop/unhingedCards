```mermaid
graph TD;

    END[End game]

    %%Loop to check state of game. This is done by the host and the control of the cards, black deck, white deck and cards per player should be represented in the real time database document
    Loop1{Does 1 player have equal or more than the winning points?}
    Loop1 -->|Yes| END
    Loop1 -->|No| Loop2{Does players have at least 1 card?}
    Loop2 -->|Yes| LoopA2{Does the black card deck have at least 1 card?}
    Loop3[Push new state to the firebase database]
    LoopA2 -->|No| END
    Loop2 -->|Yes| LoopB2[Shuffle the white deck]
    LoopB2 --> LoopB3{Does the white deck have at least 4*players cards?}
    LoopB3 -->|No| END
    LoopB3 --> LoopB4[Draw 4 white cards for each player]
    LoopB4 --> Loop3


    %%Czar selection
    Selection
    Loop3 --> Selection[Select the czar]

    Selection --> Gen3{is the czar}; 

    %% Czar part: This is executed by the czar, this is the part where the czar draws a black card and selects the winner
    Gen3 -->|yes| Czar1[Draw a black card Note: add an animation with a stack of black cards where the player press in the stack and a 3d animation of the card being drawn it could be a rotation or a flip, also there is a time limit of 5 seconds, if the czar doesn't draw a card the game will draw a card for him];
    Czar1 --> Czar2[Show the card to the czar for 2 seconds];
    Czar2 --> Czar3[Push new state to the firebase database];
    Czar3 --> Czar4[Wait for the players to select their white card/s, await for the state of each player in the firebase database to be updated, while showing a loading animation and a message while still showing the czar the black card];
    Czar4 --> Czar5[Show the czar the white cards submitted by each player];
    Czar5 --> Czar6[Czar selects the winner];
    Czar6 --> Czar7[Push new state to the firebase database];

    %% Player part: This is executed by the players, this is the part where the players select their white cards and the czar selects the winner
    Gen3 -->|no| Player1[Wait for czar to draw a black card];
    Player1 --> Player2[Await for the change in the state of the game in the firebase database];
    Player2 --> Player3[Show the black card to all players];
    Player3 --> Player4[Wait for 2 seconds];
    Player4 --> Player5[Show each player their hand];
    Player5 --> Player6[Wait for each player to select their white card/s, there should be a 20 second timer for each player to select their card/s, if the player doesn't select a card/s the game will select a random card/s for him];
    Player6 --> Player7[Push new state to the firebase database when the player selects a card/s];
    Player7 --> Player8[Push to a new state in the UI with a loading animation and a message saying Waiting for the other players to select their cards];
    Player8 --> Player9[Wait for all players to select their card/s];
    Player9 --> Player10[Push new state in UI with a loading animation and a message saying Waiting for the czar to select the winner];
    %%This part is executed by the player the czar selected as the winner
    Player10 --> Player11{did the player won the round?};
    Player11 -->|yes| Player12[Show winning animation];
    %%This part is executed by the player the czar selected as the loser
    Player11 -->|no| Player13[Show losing animation];

    %% Player part: This is executed by the players and the czar, this is the part where the result of the round is shown after the czar selects the winner
    Czar7 --> GenEnd1[Show in a new state of the UI the leaderboard with all the players, czar included, and use an animation if a player overtakes another player, this screen should be shown for 5 seconds];
    Player13 --> GenEnd1;
    Player12 --> GenEnd1;

    %%Loop to check state of game. This is done by the host and the control of the cards, black deck, white deck and cards per player should be represented in the real time database document'
    GenEnd1 --> Loop2;
    
    



    %%the game will have a number of rounds, it should be set in the lobby, by default it will be 12 rounds