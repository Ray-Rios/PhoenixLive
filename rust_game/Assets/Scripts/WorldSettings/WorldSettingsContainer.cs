///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Monobehavior that contains the world settings and broadcasts them at the appropriate time in the scene transition lifecycle
    ///</summary>
    public class WorldSettingsContainer : MonoBehaviour
    {
        #region Attributes
        // Attributes
        [Header("World Data")]
        [Tooltip("The settings to use for this world")]
        [Required]
        [SerializeField]
        private WorldSettings Settings;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void Awake()
        {
            ParrotSceneManager.OnBeforeSceneReady += BroadcastWorldSettings;
        }

        #endregion

        // Send data to appropriate subsystems for use in game 
        private void BroadcastWorldSettings(string scene)
        {
            ParrotSceneManager.OnBeforeSceneReady -= BroadcastWorldSettings;
            ParrotAudioController.Instance.SetWorldMusic(Settings.WorldMusic);
        }

    }
}
