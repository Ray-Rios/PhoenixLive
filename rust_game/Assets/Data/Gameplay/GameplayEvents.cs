///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Static delegates for gameplay events
    ///</summary>
    public class GameplayEvents
    {
        // When the game state has initialized
        public static Action<ParrotGameState> GameStateInitialized;

        // When the game state has transitioned, passes the new state
        public static Action<ELevelState> LevelStateChanged;

        // When the player has paused the game 
        public static Action PauseGame;

        // When the player has resumed the game 
        public static Action ResumeGame;

        // When the game state has entered a game over state
        public static Action GameOver;

        // When the game state has entered the victory state
        public static Action Victory;
    }
}
