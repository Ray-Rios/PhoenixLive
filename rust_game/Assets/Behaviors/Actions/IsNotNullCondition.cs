using System;
using Unity.Behavior;
using UnityEngine;

namespace SecretDimension
{
    [Serializable, Unity.Properties.GeneratePropertyBag]
    [Condition(name: "Is not null", story: "[Reference] is not null", category: "Conditions", id: "ef49e8dbbb510dd5a9dab4252c7bde76")]
    public partial class IsNotNullCondition : Condition
    {
        [SerializeReference] public BlackboardVariable<GameObject> Reference;

        public override bool IsTrue()
        {
            return Reference.Value != null;
        }
    }
}
