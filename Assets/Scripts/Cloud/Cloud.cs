using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class Cloud : MonoBehaviour
{
    // Start is called before the first frame update

    // Transform boxTransform;

    [Header("Cloud Settings")]
    public Texture2D blueNoise; // used to randomly off set the ray origin to reduce layered artifact
    public int raymarchStepCount = 30;

    [Header("Base Noise")]
    public Vector3 baseNoiseOffset;
    public float baseNoiseScale = 1;

    [Header("Detail Noise")]
    public Vector3 detailNoiseOffset;
    public float detailNoiseScale = 1;

    [Header("Density Modifiers")]
    // [Range(0, 1)]
    // public float densityThreshold = 1;
    public float densityMultiplier = 1;
    [Range(0, 1)]
    public float globalCoverageMultiplier;
    // public float anvilBias = 1;



    [Header("Lighting")]

    [Range(0, 1)]
    public float darknessThreshold = 0;
    public float lightAbsorption = 1;
    public float lightStepSize = 100;

    [Range(-1, 1)]
    public float g = 0.5f;

    [Header("Other")]
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
        material.SetInt("raymarchStepCount", raymarchStepCount);
        material.SetTexture("BlueNoise", blueNoise);

        NoiseGenerator noiseGenerator = FindObjectOfType<NoiseGenerator>();
        if (noiseGenerator.shouldUpdateNoise) noiseGenerator.updateNoise();

        WeatherMapGenerator WMGenerator = FindObjectOfType<WeatherMapGenerator>();
        if (WMGenerator.shouldUpdateNoise) WMGenerator.updateNoise();



        // values related to shaping the cloud
        material.SetFloat("time", Time.time);

        material.SetTexture("BaseNoise", noiseGenerator.baseRenderTexture);
        material.SetVector("baseNoiseOffset", baseNoiseOffset);
        material.SetFloat("baseNoiseScale", baseNoiseScale);

        material.SetTexture("DetailNoise", noiseGenerator.detailRenderTexture);
        material.SetVector("detailNoiseOffset", detailNoiseOffset);
        material.SetFloat("detailNoiseScale", detailNoiseScale);
        // material.SetFloat("densityThreshold", densityThreshold);
        material.SetFloat("densityMultiplier", densityMultiplier);
        material.SetFloat("globalCoverage", globalCoverageMultiplier);
        // material.SetFloat("anvilBias", anvilBias);

        material.SetTexture("WeatherMap", WMGenerator.WMRenderTexture);

        // values related to lighting the cloud
        material.SetFloat("darknessThreshold", darknessThreshold);
        material.SetFloat("lightAbsorption", lightAbsorption);
        material.SetFloat("g", g);

        Graphics.Blit(source, destination, material);
    }
    // Update is called once per frame
    void Update()
    {

    }
}
