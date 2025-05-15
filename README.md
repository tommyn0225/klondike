Klondike Solitaire - CMPM121 Spr25- Tommy Nguyen

Programming Patterns:
- Update Method. Continuously updates game state and frames. Used for input handling
- State Pattern. States allow for easy input handling (dragging variable)
- Prototype. Card and Pile objects. This pattern provides easy way to group objects with similar properties.
- Observer. The game

Feedback From:
- Andy: said the game plays well with all features working. The suggestions he had for me included to consider separating files instead
        of having everything in one file. He also pointed out that the feature for drawing 3 cards could be improved on. He pointed out that
        when you draw 3 cards and then draw 3 more cards, the cards sit on top of eachother, so when you play one of the cards, you can see the cards
        on the bottom. This makes it unclear what is available to play.

- Sean: said that the game works well and also suggested the same things as Andy. He also reccomended creating a system to keep track of the game state
        for when I try to implement an undo button. To fix the issues found in Andy and Sean's feedback, I created a more modular file system. I also
        made it so that the previously drawn cards "dissappear" and the newly drawn 3 cards are placed on that spot. This makes it so it's very clear
        what cards are available for you to play.



- Jason: enjoyed playtesting my game and said everything works well. His only complaint was the draw 3 cards. He pointed out that when you draw too many cards,
        they can leak onto the 4 tableus on the top right. This makes it impossible to play the game at some points. I fixed this by making it so that the newly
        drawn cards sit on top of each other.

Postmortem:
 I think I did well on mimicking the features present in Google's Solitaire hard mode.
 I struggled a lot on figuring out how to get the cards to only be placed down on valid play spots.
 If I were to do this again, I'd make a nicer UI.

CREDITS
Code: Tommy Nguyen

Sprites: https://cazwolf.itch.io/pixel-fantasy-cards?download
SFX: N/A
Music: N/A
Font: N/A
