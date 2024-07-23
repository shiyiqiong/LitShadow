#ifndef CUSTOM_SHADOW_CASTER_PASS_INCLUDED
#define CUSTOM_SHADOW_CASTER_PASS_INCLUDED

float3 _LightDirection;
float3 _LightPosition;
float4 _ShadowBias; // x: depth bias, y: normal bias

struct Attributes {
	float3 positionOS : POSITION;
	float3 normalOS     : NORMAL;
	float2 baseUV : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS_SS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

//应用阴影深度偏移和法线偏移
float3 ApplyShadowBias(float3 positionWS, float3 normalWS, float3 lightDirection)
{
    float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
    float scale = invNdotL * _ShadowBias.y;

    // normal bias is negative since we want to apply an inset normal offset
    positionWS = lightDirection * _ShadowBias.xxx + positionWS;
    positionWS = normalWS * scale.xxx + positionWS;
    return positionWS;
}

Varyings ShadowCasterPassVertex (Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float3 positionWS = TransformObjectToWorld(input.positionOS);
	float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
	#if _CASTING_PUNCTUAL_LIGHT_SHADOW
		float3 lightDirectionWS = normalize(_LightPosition - positionWS);
	#else
		float3 lightDirectionWS = _LightDirection;
	#endif
	output.positionCS_SS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
	//开启阴影平坠，将顶点齐次裁剪空间Z限制在近平面内，避免超出近平面的物体阴影投影被裁剪
	#if UNITY_REVERSED_Z
		output.positionCS_SS.z = min(output.positionCS_SS.z, UNITY_NEAR_CLIP_VALUE);
	#else
		output.positionCS_SS.z = max(output.positionCS_SS.z, UNITY_NEAR_CLIP_VALUE);
	#endif
	
	float4 baseMapST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	output.baseUV = input.baseUV * baseMapST.xy + baseMapST.zw; //纹理UV坐标：加上缩放和平移参数
	return output;
}

void ShadowCasterPassFragment (Varyings input) {
	UNITY_SETUP_INSTANCE_ID(input);
	float4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	float4 base = col * baseColor;
	
	#if defined(_SHADOWS_CLIP) //裁剪阴影
		float cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
		clip(base.a - cutoff);
	#elif defined(_SHADOWS_DITHER) //抖动阴影
		float dither = InterleavedGradientNoise(input.positionCS_SS.xy, 0);
		clip(base.a - dither);
	#endif
}

#endif