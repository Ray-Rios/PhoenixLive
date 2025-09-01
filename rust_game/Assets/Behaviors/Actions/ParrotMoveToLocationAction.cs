using System;
using Unity.Behavior;
using UnityEngine;
using Action = Unity.Behavior.Action;
using Unity.Properties;

namespace SecretDimension
{
    ///<summary>
    /// This custom parrot action follows the patrol path of an enemy agent and queues the updates
    /// on the enemy character so they can be applied in FixedUpdate for proper physics management.
    ///</summary>
    [Serializable, GeneratePropertyBag]
    [NodeDescription(name: "ParrotMoveToLocation", story: "[Agent] moves to [location]", category: "Action", id: "7260d5b4ada1be71ce42fa3f05e2d6ba")]
    public partial class ParrotMoveToLocationAction : Action
    {
        [SerializeReference] public BlackboardVariable<ParrotEnemyCharacterBase> Agent;
        [SerializeReference] public BlackboardVariable<Vector3> Location;
        [SerializeReference] public BlackboardVariable<float> Speed = new BlackboardVariable<float>(1.0f);
        [SerializeReference] public BlackboardVariable<bool> IsFast = new BlackboardVariable<bool>(false);
        [SerializeReference] public BlackboardVariable<float> DistanceThreshold = new BlackboardVariable<float>(0.2f);
        [SerializeReference] public BlackboardVariable<float> MaxSpeed = new BlackboardVariable<float>(6.0f);

        private Animator m_Animator;

        protected override Status OnStart()
        {
            m_Animator = Agent.Value.GetComponentInChildren<Animator>();

            if (m_Animator != null)
            {
                m_Animator.SetBool(AnimatorStrings.IsMoving, true);
            }

            return Status.Running;
        }

        protected override Status OnUpdate()
        {
            if (m_Animator != null)
            {
                // Calculate play rate
                float movementSpeed = Agent.Value.GetCurrentSpeed() / MaxSpeed.Value;
                movementSpeed = Mathf.Clamp01(movementSpeed);

                m_Animator.SetFloat(AnimatorStrings.MovementSpeed, movementSpeed);

                // Adjust the animation speed based on if we're going fast
                m_Animator.SetFloat(AnimatorStrings.MovementAnimationSpeed, IsFast ? 1.5f : 1.0f);
            }

            float distance = GetDistanceToLocation();

            bool reachedTarget = false;
            // Are we close enough to consider us at the target?
            if (distance <= DistanceThreshold)
            {
                reachedTarget = true;
            }

            // If we've reached the target, get the next one
            if (reachedTarget)
            {
                // Get our new target
                Location.Value = Agent.Value.GetNextPatrolPoint();
            }

            Agent.Value.UpdateSpeedAndRotation(Speed.Value, GetNormalizedDirection());

            return Status.Running;
        }

        protected override void OnEnd()
        {
            if (m_Animator != null)
            {
                m_Animator.SetBool(AnimatorStrings.IsMoving, false);
            }

            // Zero out our speed when we're done
            Agent.Value.UpdateSpeedAndRotation(0.0f, GetNormalizedDirection());
        }

        private float GetDistanceToLocation()
        {
            Vector3 agentPosition = Agent.Value.GetPosition();
            Vector3 locationPosition = Location.Value;
            return Vector3.Distance(new Vector3(agentPosition.x, locationPosition.y, agentPosition.z), locationPosition);
        }
        private Vector3 GetNormalizedDirection()
        {
            Vector3 toDestination = Location.Value - Agent.Value.GetPosition();
            toDestination.y = 0.0f;
            toDestination.Normalize();
            return toDestination;
        }
    }
}
