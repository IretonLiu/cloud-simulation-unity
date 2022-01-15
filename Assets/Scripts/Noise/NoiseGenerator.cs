using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseGenerator : MonoBehaviour
{

    const int textureResolution = 128;
    const int computeThreadGroupSize = 8;

    public ComputeShader computeShader;

    [Header("Base Noise Settings")]
    public int frequency = 4;


    public RenderTexture renderTexture;

    [HideInInspector]
    public bool shouldUpdateNoise = true;
    public void updateNoise()
    {

        if (renderTexture == null) createTexture(ref renderTexture);

        // get the handle for the compute shader kernel
        int kernelHandle = computeShader.FindKernel("CSMain");

        // set the values in the compute shader
        computeShader.SetInt("resolution", textureResolution);
        computeShader.SetFloat("freq", (float)frequency);

        // set the texture to be used as result
        computeShader.SetTexture(kernelHandle, "Result", renderTexture);

        // dispatch the compute shader
        int numThreadGroups = textureResolution / computeThreadGroupSize;
        computeShader.Dispatch(kernelHandle, numThreadGroups, numThreadGroups, numThreadGroups);

    }
    // Update is called once per frame

    void createTexture(ref RenderTexture renderTexture)
    {
        renderTexture = new RenderTexture(textureResolution, textureResolution, 0, RenderTextureFormat.ARGB32);
        renderTexture.enableRandomWrite = true;
        renderTexture.volumeDepth = textureResolution;
        renderTexture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        renderTexture.Create();
    }



    void OnValidate()
    {
        shouldUpdateNoise = true;
    }


}
