Shader "Custom/NoiseVis"
{
    Properties
    {
        _MainTex ("Noise", 3D) = "" {}
        _Depth ("Depth", Range(0,1)) = 0.0
        _Channel ("Channel", Integer) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler3D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Depth;
        int _Channel;
        // fixed4 _Color;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex3D (_MainTex, float3(IN.uv_MainTex, _Depth));
            if (_Channel == 0) o.Albedo = c.rrr;
            else if (_Channel == 1) o.Albedo = c.ggg;
            else if (_Channel == 2) o.Albedo = c.bbb;
            else if (_Channel == 3) o.Albedo = c.aaa;
            // // Metallic and smoothness come from slider variables
            // o.Metallic = _Metallic;
            // o.Smoothness = _Glossiness;
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
