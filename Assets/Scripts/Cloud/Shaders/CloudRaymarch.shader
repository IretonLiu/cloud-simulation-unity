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

            bool raymarchByCount; // determines weather to raymarch by step count or step size
            int raymarchStepCount;
            float raymarchStepSize;
            Texture2D<float4> BlueNoise;
            SamplerState samplerBlueNoise;


            float time;
            float baseNoiseScale;
            float3 baseNoiseOffset;
            // float densityThreshold;
            float densityMultiplier;

            float detailNoiseScale;
            float3 detailNoiseOffset;

            float globalCoverage;
            float anvilBias;

            float darknessThreshold;
            float lightAbsorptionThroughCloud;
            float lightAbsorptionTowardSun;
            float4 phaseParams;

            Texture3D<float4> BaseNoise;
            SamplerState samplerBaseNoise;

            Texture3D<float4> DetailNoise;
            SamplerState samplerDetailNoise;

            Texture2D<float4> WeatherMap;
            SamplerState samplerWeatherMap;


            // shaping
            float shapeAltering(float heightPercent, float4 weatherMapSample){
                // float heightDensityGradient = saturate(remap(heightPercent, 0., .2, 0., 1.)) * saturate(remap(heightPercent, 1., .7,  0., 1.));
                float wh= weatherMapSample.b; // max height from the weathermaps' blue channel
                
                float shapeAlter = saturate(remap(heightPercent, 0., 0.07, 0., 1.));
                shapeAlter*= saturate(remap(heightPercent, wh * 0.2, wh, 1., 0.));

                // float heightDensityGradient = 1;
                // float stratus =  saturate(remap(heightPercent, 0.01, 0.03, 0., 1.)) * saturate(remap(heightPercent, 0.03, 0.15, 1., 0.));
                // float stratocumulus = saturate(remap(heightPercent, 0, .1, 0, 1)) * saturate(remap(heightPercent, .2, .3, 1, 0));
                // float cumulus = remap(heightPercent, 0, .1, 0, 1) * remap(heightPercent, 0.1, 0.8, 1, 0); 

                // float type = weatherMapSample.b;
                // if(type <= 0){ //stratus
                //     heightDensityGradient *= stratus;
                // } else if(type > 0  && type < 0.5){
                //     heightDensityGradient *= lerp(stratus, stratocumulus, type * 2); //stratocumulus
                // } else if(type == 0.5){
                //     heightDensityGradient *= stratocumulus;
                // } else if(type > 0.5 && type < 1){
                //     heightDensityGradient *= lerp(stratocumulus, cumulus,  type * 2 - 1); //stratocumulus
                // }else if( type >= 1){
                //     heightDensityGradient *= cumulus;
                // }

                return shapeAlter;
            }

            float densityAltering(float heightPercent, float4 weatherMapSample){
                float densityAlter = heightPercent * saturate(remap(heightPercent, 0., 0.15, 0. ,1.));
                densityAlter *= densityMultiplier * saturate(remap(heightPercent, .9, 1., 1., 0.));

                return densityAlter;

            }
                

            float sampleDensity(float3 rayPosition) {
                

                float3 boxSize = abs(boundsMax - boundsMin);
                float3 boxCentre = (boundsMax + boundsMin) /2;
                float3 heightPercent = saturate(abs(rayPosition.y - boundsMin.y) / boxSize.y);


                float3 baseShapeSamplePosition = (boxSize * 0.5 + rayPosition) * baseNoiseScale * 0.0001  +
                            baseNoiseOffset* 0.0001;

                // wind settings
                float3 windDirection = float3(1.0, 0.0, 0.0);
                float cloudSpeed = 10.0;
                // cloud_top offset - push the tops of the clouds along this wind direction by this many units.
                float cloudTopOffset = .5;

                baseShapeSamplePosition += heightPercent * windDirection * cloudTopOffset;
                baseShapeSamplePosition += (windDirection + float3(0., 1., 0.)) * time  * 0.001 * cloudSpeed;

                float4 baseNoiseValue = BaseNoise.SampleLevel(samplerBaseNoise, baseShapeSamplePosition, 0);


                // weather map is 10km x 10km, assume that each unit is 1km
                float2 wmSamplePosition = (rayPosition.xz - boundsMin.xz)  * 0.00005 ;
                float4 weatherMapSample = WeatherMap.SampleLevel(samplerWeatherMap, wmSamplePosition, 0);


                // create fbm from the base noise
                float lowFreqFBM = (baseNoiseValue.r * 0.625) + (baseNoiseValue.g * 0.25) + (baseNoiseValue.b * 0.125);
                // get the base cloud shape with the base noise
                float baseCloud = remap(baseNoiseValue.a, - (1.0 - lowFreqFBM), 1.0, 0.0, 1.0);

                float SA = shapeAltering(heightPercent, weatherMapSample); 
                float DA = densityAltering(heightPercent, weatherMapSample);
                // baseCloud = max(0, baseCloud - densityThreshold) * densityMultiplier;
                // baseCloud *= heightGradient;

                float coverage = weatherMapSample.g;
                // coverage = pow(coverage, remap(heightPercent, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvilBias)));
                float baseCloudWithCoverage = saturate(remap(baseCloud * SA, 1 - globalCoverage * coverage, 1.0, 0.0, 1.0));
                
                baseCloudWithCoverage *= coverage;

                // float density = shape.a;
                // return  baseCloudWithCoverage ;
                float finalCloud = baseCloudWithCoverage;
                // add detailed noise
                if(baseCloudWithCoverage > 0){
                    float3 detailNoiseSamplePos = rayPosition * detailNoiseScale * 0.001 + detailNoiseOffset;
                    float3 detailNoise = DetailNoise.SampleLevel(samplerDetailNoise, detailNoiseSamplePos, 0).rgb;

                    float highFreqFbm = (detailNoise.r * 0.625) + (detailNoise.g * 0.25) + (detailNoise.b * 0.125);

                    float detailNoiseModifier = 0.35 * exp(-globalCoverage * 0.75) * lerp(highFreqFbm, 1. - highFreqFbm, saturate(heightPercent * 5.0));

                    finalCloud = saturate(remap(baseCloudWithCoverage, detailNoiseModifier, 1.0, 0.0, 1.0));

                } 

                return finalCloud * DA;
            }


            // lighting
            
            float beer(float d, float b) {
                float beer = exp(-d * b);
                return beer;
            }

            float henyeyGreenstein(float cosAngle, float g){
                
                // g is the eccentricity

                float g2 = g * g;
                float pi = 3.14159265358979;
                float hg = (1.0 - g2)/(4 * pi *pow(1 + g2 - 2 * g * cosAngle, 1.5)) ;
                // TODO: pow 1.5 could be expensive, consider replacing with schlick phase function

                return hg;
            };

            // credits to sebastian lague
            float phaseFunction(float a){
                float blend = .5;
                // blend between forward and backward scattering
                float hgBlend = henyeyGreenstein(a,phaseParams.x) * (1-blend) + henyeyGreenstein(a,-phaseParams.y) * blend;
                return phaseParams.z + hgBlend * phaseParams.w;
            };

            // march from sample point to light source
            float lightMarch(float3 samplePos){
                
                // uses raymarch to sample accumulative density from light to source sample;
                float3 dirToLight = _WorldSpaceLightPos0.xyz;

                // get distance to box from inside;
                float2 rayBoxInfo = rayBoxDst(boundsMin, boundsMax, samplePos, 1/dirToLight);
                float dstInsideBox = rayBoxInfo.y;

                float stepSize = dstInsideBox / 6.0;
                float dstTravelled = stepSize;

                float totalDensity = 0;
                
                for(int i = 0; i < 6; i++){
                    samplePos += dirToLight * stepSize; 
                    totalDensity += max(0, sampleDensity(samplePos ) *stepSize);
                    // dstTravelled += stepSize;
                }

                float transmittance = max(beer(totalDensity, lightAbsorptionTowardSun), beer(totalDensity * 0.25, lightAbsorptionTowardSun) * 0.7);

                return  darknessThreshold + transmittance * (1-darknessThreshold);

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
                float stepSize;

                if(raymarchByCount){
                    int numSteps = raymarchStepCount;
                    stepSize = dstInsideBox / numSteps;
                }else{
                    stepSize = dstInsideBox == 0 ? 0 : raymarchStepSize;
                }

                // random offset on the starting position to remove the layering artifact
                float randomOffset = BlueNoise.SampleLevel(samplerBlueNoise, i.uv * 1000, 0);
                float dstTravelled = (randomOffset - 0.5) * 2 * stepSize*2;
                // float dstTravelled = 0;
                
                float cosAngle = dot(normalize(rd), normalize(_WorldSpaceLightPos0.xyz));
                float phaseVal = phaseFunction(cosAngle);
                float transmittance = 1; // extinction
                float3 lightEnergy = 0; // the amount of light reaches the eye  
                float totalDensity = 0;

                // sample march through volume
                while (dstTravelled < dstInsideBox) {
                    float3 p = ro + rd * (dstToBox + dstTravelled);
                    float density  = sampleDensity(p);
                    if(density > 0){
                        // totalDensity += density;
                        float lightTransmittance = lightMarch(p);
                        
                        lightEnergy += density * stepSize * transmittance * lightTransmittance * phaseVal;

                        transmittance *= beer(density * stepSize, lightAbsorptionThroughCloud);// as the ray marches further in, the more the light will be lost
                        // Exit early if T is close to zero as further samples won't affect the result much
                        if (transmittance < 0.01) {
                            break;
                        }
                    }
                    
                    dstTravelled += stepSize;
                }


                // float transmittance = exp(totalDensity);
                // float3 col = tex2D(_MainTex, i.uv) * transmittance;
                // return float4(col, 0);
                
                float3 cloudCol = lightEnergy;
                float3 col = tex2D(_MainTex, i.uv) * transmittance + cloudCol;
                // col = cosAngle;
                return float4(col, 0);
            }
            ENDCG
        }
    }
}
