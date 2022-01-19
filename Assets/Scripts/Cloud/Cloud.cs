using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class Cloud : MonoBehaviour
{
    // Start is called before the first frame update

    // Transform boxTransform;

    [Header("Cloud Settings")]
    public Vector3 offset;
    public float scale = 1;

    [Range(0, 1)]
    public float densityThreshold = 1;
    public float densityMultiplier = 1;

    public Shader shader;
    public GameObject boundingBox;
    public Material material;


    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (material == null)
            material = new Material(shader);
        material.SetTexture("_MainTex", source);

        Transform transform = boundingBox.transform;
        material.SetVector("boundsMin", transform.position - transform.localScale / 2);
        material.SetVector("boundsMax", transform.position + transform.localScale / 2);

        NoiseGenerator noiseGenerator = FindObjectOfType<NoiseGenerator>();
        if (noiseGenerator.shouldUpdateNoise) noiseGenerator.updateNoise();

        material.SetTexture("BaseNoise", noiseGenerator.baseRenderTexture);
        material.SetVector("cloudOffset", offset);
        material.SetFloat("cloudScale", scale);
        material.SetFloat("densityThreshold", densityThreshold);
        material.SetFloat("densityMultiplier", densityMultiplier);

        Graphics.Blit(source, destination, material);
    }
    // Update is called once per frame
    void Update()
    {

    }
}
