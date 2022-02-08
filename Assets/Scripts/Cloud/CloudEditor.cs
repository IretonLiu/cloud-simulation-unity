using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;


// [CustomEditor(typeof(Cloud))]
// public class CloudEditor : Editor
// {

//     public override void OnInspectorGUI()
//     {
//         var cloudScript = target as Cloud;

//         cloudScript.raymarchByStepCount = GUILayout.Toggle(cloudScript.raymarchByStepCount, "Flag");

//         if (cloudScript.raymarchByStepCount)
//             cloudScript.raymarchStepCount = EditorGUILayout.IntSlider("Raymarch Step Count", cloudScript.raymarchStepCount, 1, 200);
//         else
//             cloudScript.raymarchStepSize = EditorGUILayout.Slider("Raymarch Step Size", cloudScript.raymarchStepSize, 1, 10);

//     }
// }