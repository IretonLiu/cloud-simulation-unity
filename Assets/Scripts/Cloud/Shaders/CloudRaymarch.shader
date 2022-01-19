Shader "Unlit/CloudRaymarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            float remap(float value, float ol, float oh, float nl, float nh) {
                return nl + (value - ol) * (nh - nl) / (oh - ol);
            }


            float3 boundsMin;
            float3 boundsMax;

            float cloudScale;
            float3 cloudOffset;
            float densityThreshold;
            float densityMultiplier;

            Texture3D<float4> BaseNoise;
            SamplerState samplerBaseNoise;

            float sampleDensity(float3 position) {
                float3 uvw = position * cloudScale * 0.001 +
                            cloudOffset * 0.01;

                uvw = uvw % (boundsMax - boundsMin);
                // float3 uvw = position * 0.001;
                float4 shape = BaseNoise.SampleLevel(samplerBaseNoise, uvw, 0);

                // float stratocumulusDensity =
                //     remap(position.y, 0.0, 0.2, 0.0, 1.0) * remap(position.y, .2, .6, 1., 0.);

                float density = max(0, shape.a - densityThreshold) * -densityMultiplier;
                // float density = shape.a;
                return density;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                float3 ro = _WorldSpaceCameraPos;
                float3 rd = i.viewDir;

                float2 boxInfo = rayBoxDst(boundsMin, boundsMax, ro, 1/rd);

                float dstToBox = boxInfo.x;
                float dstInsideBox = boxInfo.y;

                // if(dstInsideBox > 0){
                //     col = 0;
                // }
                int numSteps = 20;

                float dstTravelled = 0;
                float stepSize = dstInsideBox / numSteps;
                

                float totalDensity = 0;

                // sample march through volume
                [loop]while (dstTravelled < dstInsideBox) {
                    float3 p = ro + rd * (dstToBox + dstTravelled);
                    totalDensity += sampleDensity(p) * stepSize;
                    dstTravelled += stepSize;
                }

                float transmittance = exp(-totalDensity);

                return col * transmittance;
            }
            ENDCG
        }
    }
}
