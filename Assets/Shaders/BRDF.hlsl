#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#include "Shadows.hlsl"

//1减于反射率（0-0.96）
float OneMinusReflectivity(float metallic)
{
	float range = 1.0 - MIN_REFLECTIVITY;
	return range - metallic*range;
}

//漫反射双向反射分布函数
float3 DiffuseBRDF(float3 color)
{
	float metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
	float oneMinusReflectivity = OneMinusReflectivity(metallic);
	return color * oneMinusReflectivity;
}

//镜面反射双向反射分布函数
float3 SeqcularBRDF(half3 normalWS, float3 positionWS, float3 color)
{
	float metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic); //金属性
	float3 specularColor = lerp(MIN_REFLECTIVITY, color, metallic); //镜面反射颜色
	float smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
	float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);  //感知粗糙度
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness); //粗糙度
	half3 mainLightDir = half3(_MainLightPosition.xyz); //主光照方向
	half3 mainLightColor = _MainLightColor.rgb; //主光照颜色
	half3 viewDirWS = GetWorldSpaceNormalizeViewDir(positionWS); //视角向量

	float3 h = SafeNormalize(mainLightDir + viewDirWS);
	float nh2 = Square(saturate(dot(normalWS, h)));
	float lh2 = Square(saturate(dot(mainLightDir, h)));
	float r2 = Square(roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = roughness *4.0 + 2.0;
	float seqcularStrength = r2 / (d2 * max(0.1, lh2) * normalization); //镜面反射强度
	return seqcularStrength * specularColor;
}

//直射光双向反射分布函数：镜面反射双向反射分布函数加上漫反射双向反射分布函数
float3 DirectBRDF(half3 normalWS, float3 positionWS, float3 color)
{
	float3 diffuseBRDF = DiffuseBRDF(color);
	float3 seqcularBRDF = SeqcularBRDF(normalWS, positionWS, color);
	return seqcularBRDF + diffuseBRDF;
}

//接收到光照（强度乘以阴影衰减因子）
float3 IncomingLight(half3 normalWS, float3 positionWS)
{
	half3 mainLightDir = half3(_MainLightPosition.xyz); //主光照方向
	half3 mainLightColor = _MainLightColor.rgb; //主光照颜色
	float attenuation = GetDirectionalShadowAttenuation(positionWS); //主光照阴影衰减因子
	return saturate(dot(normalWS, mainLightDir) * attenuation) * mainLightColor; 
}

//直射光：接收到光照乘以直射光双向反射分布函数
float3 DirectLight(half3 normalWS, float3 positionWS, float3 color)
{
	return IncomingLight(normalWS, positionWS) * DirectBRDF(normalWS, positionWS, color);
}
 //间接光照（环境光）
float3 IndirectLight(half3 normalWS, float3 color)
{
	float4 coefficients[7];
	coefficients[0] = unity_SHAr;
	coefficients[1] = unity_SHAg;
	coefficients[2] = unity_SHAb;
	coefficients[3] = unity_SHBr;
	coefficients[4] = unity_SHBg;
	coefficients[5] = unity_SHBb;
	coefficients[6] = unity_SHC;
	return max(0.0, SampleSH9(coefficients, normalWS)) * DiffuseBRDF(color);
}

#endif