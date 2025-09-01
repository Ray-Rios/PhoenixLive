///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using System.Collections.Generic;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Structures lookup table data for author-time
    ///</summary>
    [Serializable]
    public struct GamepadIconData
    {
        public string inputControl;
        public string spritePath;
    }

    ///<summary>
    /// Stores struct data for author time and provides and runtime dictionary for lookup. 
    ///</summary>
    [CreateAssetMenu(fileName = "ParrotSpriteData", menuName = "Parrot/Input/Key Glyph Data", order = 1)]
    public class KeyGlyphData : ScriptableObject
    {
        public string SpriteSheet;
        public string DisplayFormatString = "<sprite=\"{0}\" name=\"{1}\">";
        public GamepadIconData[] IconData;

        public Dictionary<string, string> GetDictionary()
        {
            Dictionary<string, string> result = new Dictionary<string, string>();

            foreach (var data in IconData)
            {
                // Interpolate string
                string value = DisplayFormatString;
                value = value.Replace("{0}", SpriteSheet);
                value = value.Replace("{1}", data.spritePath);

                if (result.ContainsKey(data.inputControl))
                {
                    Debug.LogError("Duplicate key in glyph data SO. Check configuration: " + this.name);
                }
                else
                {
                    // Map control to sprite
                    result.Add(data.inputControl, value);
                }
            }

            return result;
        }
    }
}
