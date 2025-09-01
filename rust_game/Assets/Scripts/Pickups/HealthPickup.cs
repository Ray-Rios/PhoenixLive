///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Adds a heart to the player's health on pickup
    ///</summary>
    public class HealthPickup : BasePickup
    {
        [Header("Powerup Effect")]
        [Tooltip("The number of hitpoints to add when the player picks up this health pickup")]
        [SerializeField]
        [Range(0, 10)]
        int HitPointsToAdd = 1;

        protected override void OnPickedUp(ParrotPlayerCharacter player)
        {
            base.OnPickedUp(player);
            player.AddHitpoints(HitPointsToAdd);
        }
    }
}
