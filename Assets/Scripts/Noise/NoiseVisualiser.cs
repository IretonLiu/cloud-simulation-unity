using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseVisualiser : MonoBehaviour
{

    public enum NoiseChannel : int // your custom enumeration
    {
        R = 0, G = 1, B = 2, A = 3
    };

    public enum NoiseType
    {
        BASE, DETAIL
    }


    [Header("Noise Settings")]

    [Header("Visualiser Settings")]

    [Range(0.0f, 1.0f)]
    public float depth;
    public NoiseChannel noiseChannel;
    public NoiseType noiseType;


    public Material material;
    public Shader shader;
    NoiseGenerator noiseGenerator;


    bool shouldUpdateMaterial = true;
    // Start is called before the first frame update
    void Start()
    {

        noiseGenerator = FindObjectOfType<NoiseGenerator>();
        if (noiseGenerator.shouldUpdateNoise)
        {
            noiseGenerator.updateNoise();
            noiseGenerator.shouldUpdateNoise = false;
        }

        if (material == null)
        {
            material = new Material(shader);
        }
        if (shouldUpdateMaterial)
        {
            updateMaterial();
        }
    }


    void OnValidate()
    {
        shouldUpdateMaterial = true;
    }



    // Update is called once per frame
    void Update()
    {
        if (noiseGenerator.shouldUpdateNoise)
        {
            noiseGenerator.updateNoise();
            noiseGenerator.shouldUpdateNoise = false;
        }

        if (shouldUpdateMaterial || noiseGenerator.shouldUpdateNoise)
        {
            updateMaterial();
            shouldUpdateMaterial = false;
        }


        shouldUpdateMaterial = false;
        noiseGenerator.shouldUpdateNoise = false;

    }

    void updateMaterial()
    {
        if (noiseType == NoiseType.BASE)
            material.SetTexture("_MainTex", noiseGenerator.baseRenderTexture);
        else if (noiseType == NoiseType.DETAIL)
            material.SetTexture("_MainTex", noiseGenerator.detailRenderTexture);
        material.SetFloat("_Depth", depth);
        material.SetInteger("_Channel", (int)noiseChannel);
    }

}
