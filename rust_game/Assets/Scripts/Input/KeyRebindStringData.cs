///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.Localization;

namespace SecretDimension
{
    ///<summary>
    /// Stores localized string data for rebinding modal
    ///</summary>
    [CreateAssetMenu(fileName = "ParrotKeyRebindStringData", menuName = "Parrot/Input/Key Rebinding Data", order = 1)]
    public class KeyRebindStringData : ScriptableObject
    {
        public LocalizedString MKBPressKeyString;

        public LocalizedString MKBCancelKeyString;

        public LocalizedString GamepadPressKeyString;

        public LocalizedString GamepadCancelKeyString;
    }
}
