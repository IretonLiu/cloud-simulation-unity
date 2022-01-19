using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WeatherMapGenerator : MonoBehaviour
{
    // Start is called before the first frame update

    const int textureResolution = 512;
    const int computeThreadGroupSize = 8;

    public int worleyNoiseFrequency = 4;
    public float perlinScale = 2.0f;
    public float lacunarity = 2.0f;
    public float persistence = Mathf.Pow(2, -0.85f);
    public int octaves = 5;

    public RenderTexture WMRenderTexture;
    public ComputeShader computeShader;
    public Material material;

    [HideInInspector]
    public bool shouldUpdateNoise = true;
    public void updateNoise()
    {
        createTexture(ref WMRenderTexture);
        int kernelHandle = computeShader.FindKernel("CSMain");

        computeShader.SetInt("resolution", textureResolution);
        computeShader.SetFloat("worleyFreq", (float)worleyNoiseFrequency);
        computeShader.SetFloat("fbmScale", perlinScale);
        computeShader.SetFloat("fbmLacunarity", lacunarity);
        computeShader.SetFloat("fbmPersistence", persistence);
        computeShader.SetInt("fbmOctaves", octaves);

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
        material.SetTexture("_MainTex", WMRenderTexture);

    }

    void Start()
    {
        updateNoise();

        material.SetTexture("_MainTex", WMRenderTexture);
    }
}
