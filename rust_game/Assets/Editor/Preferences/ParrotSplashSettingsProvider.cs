///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEditor;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Provides an editor prefence for whether or not to show the splash screen when launching the game from the init scene
    ///</summary>
    public class ParrotSplashSettingsProvider : SettingsProvider
    {
        const string k_ShowBootSplash = "ShowBootSplash";

        public static bool ShowBootSplashEnabled
        {
            get { return EditorPrefs.GetBool(k_ShowBootSplash, true); } // Defaults to true 
            set { EditorPrefs.SetBool(k_ShowBootSplash, value); }
        }

        public ParrotSplashSettingsProvider(string path, SettingsScope scope)
            : base(path, scope)
        { }

        public override void OnGUI(string searchContext)
        {
            base.OnGUI(searchContext);

            GUILayout.Space(20.0f);

            bool enabled = ShowBootSplashEnabled;
            bool value = EditorGUILayout.Toggle("Show boot splash from init scene", enabled, GUILayout.Width(350.0f));

            if (enabled != value)
            {
                ShowBootSplashEnabled = value;
            }
        }

        [SettingsProvider]
        public static SettingsProvider CreateSettingsProvider()
        {
            return new ParrotSplashSettingsProvider("Parrot/Editor/Settings", SettingsScope.User);
        }
    }
}
