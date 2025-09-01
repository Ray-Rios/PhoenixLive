///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Completes the level when a player enters this game object's trigger bounds
    ///</summary>
    public class LevelCompleteTrigger : MonoBehaviour
    {
        #region Unity Methods
        // Unity Methods

        private void OnTriggerEnter(Collider other)
        {
            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();
            if (player != null)
            {
                player.TriggerVictory();
            }
        }

        #endregion
    }
}
