///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;

namespace SecretDimension
{
    ///<summary>
    /// Static delegates for Main Menu UI changes  
    ///</summary>
    public class MainMenuUIEvents
    {
        //Show the Main Screen to play the game
        public static Action MainScreenShown;

        // Show the Settings Screen to change game settings 
        public static Action SettingsScreenShown;

        // When the current view has changed 
        public static Action<string> CurrentViewChanged;

        // When the 'play' button has been pressed 
        public static Action PlayGamePressed;

        // When the 'Exit' button has been pressed
        public static Action QuitPressed;
    }
}
