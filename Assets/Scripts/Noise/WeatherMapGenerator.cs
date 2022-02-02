using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode, ImageEffectAllowedInSceneView]

public class WeatherMapGenerator : MonoBehaviour
{
    // Start is called before the first frame update

    const int textureResolution = 512;
    const int computeThreadGroupSize = 8;

    public int worleyNoiseFrequency = 4;
    public int octaves = 6;
    public float lacunarity = 2.0f;
    public float persistence = Mathf.Pow(2, -0.85f);
    public float amplitude = 1.0f;
    // public float frequency = 4.0f;

    [Header("Base Noise Settings")]
    public float baseFrequency = 3;
    public Vector2 baseNoiseOffset;
    public float coverageFrequency = 5;

    [Header("First Noise Settings")]
    public Vector2 noiseOffset1;

    [Header("Second Noise Settings")]
    public Vector2 noiseOffset2;

    [Header("Third Noise Settings")]
    public float frequency3 = 2.0f;
    public Vector2 noiseOffset3;

    public RenderTexture WMRenderTexture;
    public ComputeShader computeShader;

    // public Material material;

    [HideInInspector]
    public bool shouldUpdateNoise = true;


    public void updateNoise()
    {
        createTexture(ref WMRenderTexture);
        int kernelHandle = computeShader.FindKernel("CSMain");

        computeShader.SetInt("resolution", textureResolution);
        computeShader.SetFloat("worleyFreq", (float)worleyNoiseFrequency);
        computeShader.SetFloat("fbmLacunarity", lacunarity);
        computeShader.SetFloat("fbmPersistence", persistence);
        computeShader.SetFloat("fbmAmplitude", amplitude);
        computeShader.SetInt("fbmOctaves", octaves);

        computeShader.SetFloat("baseFrequency", baseFrequency);
        computeShader.SetFloat("coverageFreq", coverageFrequency);
        computeShader.SetVector("baseNoiseOffset", baseNoiseOffset);
        computeShader.SetVector("noiseOffset1", new Vector4(noiseOffset1.x, noiseOffset1.y, 0.0f, 0.0f));
        computeShader.SetVector("noiseOffset2", new Vector4(noiseOffset2.x, noiseOffset2.y, 0.0f, 0.0f));
        computeShader.SetFloat("frequency3", frequency3);
        computeShader.SetVector("noiseOffset3", new Vector4(noiseOffset3.x, noiseOffset3.y, 0.0f, 0.0f));



        computeShader.SetTexture(kernelHandle, "Result", WMRenderTexture);
        int numThreadGroups = textureResolution / computeThreadGroupSize;
        computeShader.Dispatch(kernelHandle, numThreadGroups, numThreadGroups, 1);
        shouldUpdateNoise = false;
    }

    // Update is called once per frame
    void createTexture(ref RenderTexture renderTexture)
    {
        renderTexture = new RenderTexture(textureResolution, textureResolution, 0, RenderTextureFormat.ARGB32);
        renderTexture.enableRandomWrite = true;
        renderTexture.wrapMode = TextureWrapMode.Repeat;
        renderTexture.filterMode = FilterMode.Bilinear;
        renderTexture.Create();
    }

    void OnValidate()
    {
        updateNoise();
    }


    //         material.SetTexture("_MainTex", WMRenderTexture);

    //     }

    //     void update()
    //     {
    //         updateNoise();

    //         material.SetTexture("_MainTex", WMRenderTexture);
    //     }
    //     void Start()
    //     {
    //         updateNoise();

    //         material.SetTexture("_MainTex", WMRenderTexture);
    //     }
}
