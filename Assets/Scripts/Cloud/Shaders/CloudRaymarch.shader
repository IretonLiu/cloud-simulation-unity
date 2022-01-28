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

            int raymarchStepCount;

            float cloudScale;
            float3 cloudOffset;
            float densityThreshold;
            float densityMultiplier;
            float anvilBias;

            float darknessThreshold;
            float lightAbsorption;
            float g;        

            Texture3D<float4> BaseNoise;
            SamplerState samplerBaseNoise;

            Texture2D<float4> WeatherMap;
            SamplerState samplerWeatherMap;


            // shaping
            float heightDensityGradient(float heightPercent, float4 weatherMapSample){
                float heightDensityGradient = saturate(remap(heightPercent, 0., .2, 0., 1.)) * saturate(remap(heightPercent, .7, 1.,  1., 0.));
                
                // float heightDensityGradient = 1;
                float stratus =  saturate(remap(heightPercent, 0.01, 0.03, 0., 1.)) * saturate(remap(heightPercent, 0.03, 0.15, 1., 0.));
                float stratocumulus = saturate(remap(heightPercent, 0, .1, 0, 1)) * saturate(remap(heightPercent, .2, .3, 1, 0));
                float cumulus = saturate(remap(heightPercent, 0, .1, 0, 1)) * saturate(remap(heightPercent, 0.1, 0.8, 1, 0)); 

                float type = weatherMapSample.b;
                if(type <= 0){ //stratus
                    heightDensityGradient *= stratus;
                } else if(type > 0  && type < 0.5){
                    heightDensityGradient *= lerp(stratus, stratocumulus, type * 2); //stratocumulus
                } else if(type == 0.5){
                    heightDensityGradient *= stratocumulus;
                } else if(type > 0.5 && type < 1){
                    heightDensityGradient *= lerp(stratocumulus, cumulus,  type * 2 - 1); //stratocumulus
                }else if( type >= 1){
                    heightDensityGradient *= cumulus;
                }

                return heightDensityGradient;
            }

            // float densityAlter(float heightPercent, float4 weatherMapSample){
            //     float retVal = 1;

                

            //     if(weatherMapSample.b < 0.2){ //stratus
            //         retVal *= saturate(remap(heightPercent, 0.01, 0.03, 0., 1.)) * saturate(remap(heightPercent, 0.03, 0.15, 1., 0.));
            //     } else if(weatherMapSample.b >= 0.2 && weatherMapSample.b < 0.6){
            //         retVal *= saturate(remap(heightPercent, 0, .1, 0, 1)) * saturate(remap(heightPercent, .2, .3, 1, 0)); //stratocumulus
            //     } else{
            //         retVal *= saturate(remap(heightPercent, 0, .1, 0, 1)) * saturate(remap(heightPercent, 0.1, 0.8, 1, 0)); //cumulus
            //     } 

            //     return retVal;
                
            // }


            float sampleDensity(float3 rayPosition) {
                float3 boxSize = abs(boundsMax - boundsMin);
                float3 boxCentre = (boundsMax + boundsMin) /2;


                // float3 baseShapeSamplePosition = (boxSize * 0.5 + rayPosition) * cloudScale * 0.0001 +
                //             cloudOffset * 0.01;

                float3 baseShapeSamplePosition = (rayPosition - boundsMin) / boxSize;

                float4 baseNoiseValue = BaseNoise.SampleLevel(samplerBaseNoise, baseShapeSamplePosition, 0);


                // weather map is 10km x 10km, assume that each unit is 1km
                // float2 wmSamplePosition = saturate((rayPosition.xz - boundsMin.xz) / max(boxSize.x, boxSize.z));
                float2 wmSamplePosition = (rayPosition.xz - boundsMin.xz)  * 0.0001 ;
                float4 weatherMapSample = WeatherMap.SampleLevel(samplerWeatherMap, wmSamplePosition, 0);

                float3 heightPercent = saturate(abs(rayPosition.y - boundsMin.y) / boxSize.y);
                float3 heightGradient = heightDensityGradient(heightPercent, weatherMapSample);
                // float stratocumulusDensity =
                //     remap(position.y, 0.0, 0.2, 0.0, 1.0) * remap(position.y, .2, .6, 1., 0.);
                float lowFreqFBM = (baseNoiseValue.r * 0.625) + (baseNoiseValue.g * 0.25) + (baseNoiseValue.b * 0.125);
                float baseCloud = remap(baseNoiseValue.a, - (1.0 - lowFreqFBM), 1.0, 0.0, 1.0);
                baseCloud *= heightGradient;
                //  max(0, baseCloud - densityThreshold) * densityMultiplier;

                float coverage = weatherMapSample.r;
                // coverage = pow(coverage, remap(heightPercent, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvilBias)));
                float baseCloudWithCoverage = remap(baseCloud, coverage, 1.0, 0.0, 1.0);
                baseCloud *= coverage;

                // float density = shape.a;
                return baseCloud;
            }


            // lighting
            
            float beer(float d) {
                float beer = exp(-d * lightAbsorption);
                return beer;
            }

            float henyeyGreenstein(float cosAngle, float g){
                
                // g is the eccentricity

                float g2 = g * g;
                float pi = 3.14159265358979;
                float hg = ((1.0 - g2)/pow(1 + g2 - 2 * g * cos(cosAngle), 1.5)) * (0.25 * pi);
                // TODO: pow 1.5 could be expensive, consider replacing with schlick phase function

                return hg;
            };

            // march from sample point to light source
            float lightMarch(float3 samplePos){
                
                // uses raymarch to sample accumulative density from light to source sample;
                float3 dirToLight = _WorldSpaceLightPos0.xyz;


                // get distance to box from inside;
                float2 rayBoxInfo = rayBoxDst(boundsMin, boundsMax, samplePos, 1/dirToLight);

                float dstInsideBox = rayBoxInfo.y;



                float stepSize = dstInsideBox / 5;
                float dstTravelled = stepSize;

                float totalDensity = 0;
                
                [loop]for(int i = 0; i < 5; i++){
                    samplePos += dirToLight * dstTravelled; 
                    totalDensity += sampleDensity(samplePos) * stepSize;
                    dstTravelled = i * stepSize;
                }

                return beer(totalDensity) + darknessThreshold;

            }
            fixed4 frag (v2f i) : SV_Target
            {


                float3 ro = _WorldSpaceCameraPos;
                float3 rd = i.viewDir;

                float2 boxInfo = rayBoxDst(boundsMin, boundsMax, ro, 1/rd);

                float dstToBox = boxInfo.x;
                float dstInsideBox = boxInfo.y;

                // if(dstInsideBox > 0){
                //     col = 0;
                // }
                int numSteps = raymarchStepCount;

                float dstTravelled = 0;
                float stepSize = dstInsideBox / numSteps;
                

                float transmittance = 1; // extinction
                float3 lightEnergy = 0; // scattering  
                float totalDensity = 0;

                // sample march through volume
                [loop] while (dstTravelled < dstInsideBox) {
                    float3 p = ro + rd * (dstToBox + dstTravelled);
                    float density  = sampleDensity(p);
                    if(density > 0){
                        // totalDensity += density;
                        transmittance *= beer(density * stepSize);
                        float lightTransmittance = lightMarch(p);

                        lightEnergy += density * stepSize* transmittance * lightTransmittance;
                        // lightEnergy += density * stepSize * lightTransmittance;
                        // // lightEnergy += density * stepSize * transmittance * lightTransmittance;

                    }
                    
                    dstTravelled += stepSize;
                }


                // float transmittance = exp(-totalDensity);
                float3 cloudCol = lightEnergy;
                float3 col = tex2D(_MainTex, i.uv) * transmittance + cloudCol;
                return float4(col, 0);
            }
            ENDCG
        }
    }
}
