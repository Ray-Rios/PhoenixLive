///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Container class with data related to levels and level order in Parrot
    ///</summary>

    [CreateAssetMenu(fileName = "ParrotLevelData", menuName = "Parrot/Level Data", order = 1)]
    public class ParrotLevelData : ScriptableObject
    {
        public SceneField mainMenuLevel;

        public SceneField[] singlePlayerLevels;
    }
}