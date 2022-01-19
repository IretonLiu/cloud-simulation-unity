using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseGenerator : MonoBehaviour
{

    const int baseTextureResolution = 128;
    const int detailTextureResolution = 32;
    const int computeThreadGroupSize = 8;

    public ComputeShader computeShader;

    [Header("Base Noise Settings")]
    public int frequency = 4;

    public int perlinFbmOctaves;
    



    public RenderTexture baseRenderTexture;
    public RenderTexture detailRenderTexture;

    [HideInInspector]
    public bool shouldUpdateNoise = true;
    public void updateNoise()
    {

        createTexture(ref baseRenderTexture, baseTextureResolution);
        createTexture(ref detailRenderTexture, detailTextureResolution);

        // get the handle for the compute shader kernel
        int kernelHandle = computeShader.FindKernel("CSMain");

        // set the values in the compute shader
        computeShader.SetInt("resolution", baseTextureResolution);
        computeShader.SetFloat("freq", (float)frequency);

        // set the texture to be used as result
        computeShader.SetTexture(kernelHandle, "Result", baseRenderTexture);

        // dispatch the compute shader
        int numThreadGroups = baseTextureResolution / computeThreadGroupSize;
        computeShader.Dispatch(kernelHandle, numThreadGroups, numThreadGroups, numThreadGroups);



        computeShader.SetInt("resolution", detailTextureResolution);
        computeShader.SetFloat("freq", (float)frequency);

        computeShader.SetTexture(kernelHandle, "Result", detailRenderTexture);
        numThreadGroups = detailTextureResolution / computeThreadGroupSize;
        computeShader.Dispatch(kernelHandle, numThreadGroups, numThreadGroups, numThreadGroups);

        shouldUpdateNoise = false;
    }
    // Update is called once per frame

    void createTexture(ref RenderTexture renderTexture, int resolution)
    {
        renderTexture = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32);
        renderTexture.enableRandomWrite = true;
        renderTexture.volumeDepth = resolution;
        renderTexture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        renderTexture.wrapMode = TextureWrapMode.Mirror;
        renderTexture.filterMode = FilterMode.Bilinear;
        renderTexture.Create();
    }



    void OnValidate()
    {
        shouldUpdateNoise = true;
    }


}
