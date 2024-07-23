#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#define MAX_SHADOW_CASCADES 4

TEXTURE2D_SHADOW(_MainLightShadowmapTexture);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

float4x4 _MainLightWorldToShadow[MAX_SHADOW_CASCADES + 1];
float4      _CascadeShadowSplitSpheres0;
float4      _CascadeShadowSplitSpheres1;
float4      _CascadeShadowSplitSpheres2;
float4      _CascadeShadowSplitSpheres3;
float4      _CascadeShadowSplitSphereRadii;

#define DIRECTIONAL_FILTER_SAMPLES 16
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7

float4      _MainLightShadowmapSize;  // (xy: 1/width and 1/height, zw: width and height)

#define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z <= 0.0 || shadowCoord.z >= 1.0

//计算级联序号
half ComputeCascadeIndex(float3 positionWS)
{
    float3 fromCenter0 = positionWS - _CascadeShadowSplitSpheres0.xyz;
    float3 fromCenter1 = positionWS - _CascadeShadowSplitSpheres1.xyz;
    float3 fromCenter2 = positionWS - _CascadeShadowSplitSpheres2.xyz;
    float3 fromCenter3 = positionWS - _CascadeShadowSplitSpheres3.xyz;
    float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

    half4 weights = half4(distances2 < _CascadeShadowSplitSphereRadii);
    weights.yzw = saturate(weights.yzw - weights.xyz);

    return half(4.0) - dot(weights, half4(4, 3, 2, 1));
}

//采样方向光阴影贴图集获得阴影衰减因子
float SampleDirectionalShadowAtlas(float3 positionSTS)
{
	return SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, SHADOW_SAMPLER, positionSTS);
}

//方向光阴影过滤器
float FilterDirectionalShadow(float3 positionSTS)
{
	#if defined(DIRECTIONAL_FILTER_SETUP)
		real weights[DIRECTIONAL_FILTER_SAMPLES];
		real2 positions[DIRECTIONAL_FILTER_SAMPLES];
		float4 size = _MainLightShadowmapSize;
		DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
		float attenuation = 0;
		for(int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++)
		{
			attenuation += weights[i] * SampleDirectionalShadowAtlas(float3(positions[i].xy, positionSTS.z));
		}
		return attenuation;
	#else
		return SampleDirectionalShadowAtlas(positionSTS);
	#endif
}

//获得方向光实时级联阴影
float GetCascadedShadow(float3 positionWS)
{
	#ifdef _MAIN_LIGHT_SHADOWS_CASCADE
		half cascadeIndex = ComputeCascadeIndex(positionWS);
	#else
		half cascadeIndex = half(0.0);
	#endif
	float3 positionSTS = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0)).xyz; //世界空间转阴影贴图空间
	float attenuation = BEYOND_SHADOW_FAR(positionSTS) ? 1.0 : FilterDirectionalShadow(positionSTS); //通过方向光阴影过滤器获得阴影衰减因子
	return attenuation;
}

//获取方向光阴影衰减
float GetDirectionalShadowAttenuation(float3 positionWS)
{
	float attenuation = GetCascadedShadow(positionWS);
	return attenuation;
}

#endif