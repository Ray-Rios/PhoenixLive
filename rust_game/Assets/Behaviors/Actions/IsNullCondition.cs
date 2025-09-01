using System;
using Unity.Behavior;
using UnityEngine;

namespace SecretDimension
{
    [Serializable, Unity.Properties.GeneratePropertyBag]
    [Condition(name: "Is Null", story: "[Reference] is null", category: "Variable Conditions", id: "811d4775f4068f8bd3bdfb4bd7d92714")]
    public partial class IsNullCondition : Condition
    {
        [SerializeReference] public BlackboardVariable<GameObject> Reference;

        public override bool IsTrue()
        {
            return Reference.Value == null;
        }
    }
}
