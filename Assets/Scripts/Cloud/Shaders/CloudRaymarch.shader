Shader "Unlit/CloudRaymarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Divider ("Divider", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 viewDir : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                // Camera space matches OpenGL convention where cam forward is -z. In unity forward is positive z.
                // normal view direction would not work because unity's camera uses +z as the forward camera direction
                float3 viewDir = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1)); // convert the uv to -z facing camera coordinate;
                o.viewDir = mul(unity_CameraToWorld, float4(viewDir,0)); // convert the camera coordinate to world coordinate;
                return o;
            }

            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir) {
                // Adapted from: http://jcgt.org/published/0007/03/04/
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));

                // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
                // dstA is dst to nearest intersection, dstB dst to far intersection

                // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
                // dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

                // CASE 3: ray misses box (dstA > dstB)

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float3 boundsMin;
            float3 boundsMax;
            float _Divider;
            Texture3D<float4> baseNoise;

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                float3 ro = _WorldSpaceCameraPos;
                float3 rd = i.viewDir;

                float2 boxInfo = rayBoxDst(boundsMin, boundsMax, ro, 1/rd);

                float dstToBox = boxInfo.x;
                float dstInsideBox = boxInfo.y;

                bool rayHitBox = dstInsideBox > 0;
                if (rayHitBox){
                     return  0;
                }
   
                return col;
                // return float4(ro, 1.0);
                // return float4(i.viewDir, 1.0);
                // dstToBox /= _di;
                // return float4(dstToBox, dstToBox, dstToBox, 1);
            }
            ENDCG
        }
    }
}
