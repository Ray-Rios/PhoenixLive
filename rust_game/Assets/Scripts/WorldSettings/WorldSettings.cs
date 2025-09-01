///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using Unity.AppUI.UI;
using UnityEngine;
using UnityEngine.AddressableAssets;

namespace SecretDimension
{
    ///<summary>
    /// Data object for settings on a given world
    ///</summary>

    [CreateAssetMenu(fileName = "ParrotWorldSettings", menuName = "Parrot/World Data", order = 1)]
    public class WorldSettings : ScriptableObject
    {
        [Header("Audio")]
        [Tooltip("The music asset to play once a world is loaded")]
        public AssetReference WorldMusic;
    }
}
