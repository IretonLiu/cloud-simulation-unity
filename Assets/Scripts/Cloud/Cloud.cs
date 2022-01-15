using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Cloud : MonoBehaviour
{
    // Start is called before the first frame update

    // Transform boxTransform;

    public Shader shader;
    public GameObject boundingBox;
    Material material;


    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (material == null)
            material = new Material(shader);
        Transform transform = boundingBox.transform;
        material.SetVector("BoundsMin", transform.position - transform.localScale / 2);
        material.SetVector("BoundsMax", transform.position + transform.localScale / 2);

        // NoiseGenerator noiseGenerator = FindObjectOfType<NoiseGenerator>();
        // material.SetTexture("BaseNoise", noiseGenerator. )
        // material.SetTexture("_MainTex", source);

        Graphics.Blit(source, destination, material);
    }
    // Update is called once per frame
    void Update()
    {

    }
}
