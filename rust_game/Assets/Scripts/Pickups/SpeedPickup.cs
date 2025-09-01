///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Applies a speed up effect to the player on pickup 
    ///</summary>
    public class SpeedPickup : BasePickup
    {
        #region Attributes

        // Attributes
        [Tooltip("How long the powerup effect of this pickup will last")]
        [SerializeField]
        private float PowerupDuration = 5.0f;

        [Tooltip("The speed multiplier to apply to the player on pickup")]
        [SerializeField]
        private float SpeedMultiplier = 1.25f;

        [Tooltip("The color to apply to the character outline when this pickup is activated")]
        [SerializeField]
        private Color TargetColor = Color.green;

        #endregion

        protected override void OnPickedUp(ParrotPlayerCharacter player)
        {
            base.OnPickedUp(player);
            player.ActivateSpeedPowerup(PowerupDuration, SpeedMultiplier, TargetColor);
        }
    }
}
