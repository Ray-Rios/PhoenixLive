using System;
using Unity.Behavior;
using UnityEngine;
using Action = Unity.Behavior.Action;
using Unity.Properties;

namespace SecretDimension
{
    [Serializable, GeneratePropertyBag]
    [NodeDescription(name: "Enemy Agent attacks", story: "[EnemyAgent] attacks", category: "Action", id: "28d31ed9064e7a39acb4b836cc372065")]
    public partial class ParrotAttackAction : Action
    {
        [SerializeReference] public BlackboardVariable<ParrotEnemyCharacterBase> EnemyAgent;

        protected override Status OnStart()
        {
            ParrotCombatEnemyCharacterBase combatEnemy = EnemyAgent.Value as ParrotCombatEnemyCharacterBase;
            if (combatEnemy == null)
            {
                Debug.Log("Enemy Agent is not Combat Enemy type!");
                return Status.Failure;
            }
            combatEnemy.BeginAttack();
            return Status.Running;
        }

        protected override Status OnUpdate()
        {
            return Status.Running;
        }

        protected override void OnEnd()
        {
            ParrotCombatEnemyCharacterBase combatEnemy = EnemyAgent.Value as ParrotCombatEnemyCharacterBase;
            if (combatEnemy == null)
            {
                Debug.Log("Enemy Agent is not Combat Enemy type!");
                return;
            }
            combatEnemy.EndAttack();
        }
    }
}
