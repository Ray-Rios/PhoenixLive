///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Kills a player when they enter this game object's trigger bounds 
    ///</summary>
    [RequireComponent(typeof(Collider))]
    public class OutOfBoundsTrigger : MonoBehaviour
    {
        #region Unity Methods
        // Unity Methods

        private void OnTriggerEnter(Collider other)
        {
            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();
            if (player != null)
            {
                player.KillCharacter();
            }
        }
        #endregion
    }
}
