///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Listens for the Victory gameplay event to trigger level complete effects
    ///</summary>
    public class LevelCompleteHandler : MonoBehaviour
    {
        #region Attributes
        // Attributes
        [Tooltip("The mesh game object to add effects to on victory")]
        [Required]
        [SerializeField]
        private MeshFilter WorldChest;

        [Tooltip("The mesh to swap the world chest to on victory")]
        [Required]
        [SerializeField]
        private Mesh VictoryChest;

        [Tooltip("The sound to play when the trigger is activated")]
        [SerializeField]
        private AudioClip VictorySound;

        [SerializeField]
        [Required]
        [Tooltip("The coin burst VFX.")]
        private ParrotVFXWrapper CoinBurstEffect;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void Awake()
        {
            GameplayEvents.Victory += OnVictory;
        }

        private void OnDestroy()
        {
            GameplayEvents.Victory -= OnVictory;
        }

        #endregion

        private void OnVictory()
        {
            WorldChest.mesh = VictoryChest;
            CoinBurstEffect.Play();

            if (VictorySound != null && ParrotAudioController.Instance)
            {
                ParrotAudioController.Instance.PlayGameplaySFX(VictorySound);
            }
        }
    }
}
