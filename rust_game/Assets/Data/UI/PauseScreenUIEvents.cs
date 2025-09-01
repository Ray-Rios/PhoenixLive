///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;

namespace SecretDimension
{
    ///<summary>
    /// Static delegates for Pause Screen UI changes
    ///</summary>
    public class PauseScreenUIEvents
    {
        // When the 'Resume' button has been pressed
        public static Action ResumeGame;

        // Show the Settings Screen to change game settings 
        public static Action SettingsScreenShown;

        // When the 'Exit' button has been pressed
        public static Action QuitPressed;
    }
}
