///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;

namespace SecretDimension
{
    ///<summary>
    /// Static delegates for application level events 
    ///</summary>
    public class ApplicationEvents
    {
        // When the current input device has changed
        public static Action<InputType> InputDeviceChanged;
    }
}
