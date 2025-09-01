///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;

namespace SecretDimension
{
    public enum RequiredPropertyWarningType { InspectorWarning, Error }

    ///<summary>
    /// Defines a custom attribute to require property fields to be set. When unset, will propagate an error in editor and block play mode 
    ///</summary>

    [AttributeUsage(AttributeTargets.Field, AllowMultiple = false, Inherited = true)]
    public class Required : PropertyAttribute
    {
        public RequiredPropertyWarningType WarningType = RequiredPropertyWarningType.Error;

        // Can optionally pass warning type
        public Required(RequiredPropertyWarningType warningType = RequiredPropertyWarningType.Error)
        {
            WarningType = warningType;
        }
    }
}
