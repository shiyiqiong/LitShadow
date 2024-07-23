Shader "Custom/LitShadow"
{
    Properties
    {
        _BaseMap("Texture", 2D) = "white" {} //基础颜色贴图
        _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0) //基础颜色
        _Metallic("Metallic", Range(0, 1)) = 0 //金属性
        _Smoothness("Smoothness", Range(0, 1)) = 0.5 //光滑度
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0 //开关：是否根据透明通道进行裁剪
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5 //alpha通道裁剪，临界值
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0 //阴影类型：打开阴影，裁剪阴影，抖动阴影，关闭阴影
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma shader_feature _CLIPPING
            #pragma vertex vert
            #pragma fragment frag
            #include "LitInput.hlsl"
            #include "BRDF.hlsl"

            struct appdata
            {
                float3 vertex : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 positionWS : VAR_POSITION;
                half3 normalWS : VAR_NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                //顶点计算
                o.positionWS = TransformObjectToWorld(v.vertex); //顶点：模型空间转世界空间
                o.vertex = TransformWorldToHClip(o.positionWS); //顶点：世界空间转齐次裁剪空间

                //法线计算
                o.normalWS = TransformObjectToWorldNormal(v.normalOS); //法线向量：模型空间转世界空间
                //UV坐标计算
                float4 baseMapST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
                o.uv = v.uv * baseMapST.xy + baseMapST.zw; //纹理UV坐标：加上缩放和平移参数
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                float4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
                col = col * baseColor;
                //根据alpha通道进行裁剪
                #if defined(_CLIPPING) 
                    float cutoff = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
                    clip(col.a - cutoff);
                #endif
                //间接光
                float3 indirectLight = IndirectLight(i.normalWS, col.rgb);
                //直接光
                float3 directLight = DirectLight(i.normalWS, i.positionWS, col.rgb);
                //最终光照
                return float4(indirectLight + directLight, col.a);
            }

            ENDHLSL
        }

        Pass
        {
            Tags {
				"LightMode" = "ShadowCaster"
			}

			ColorMask 0

			HLSLPROGRAM
			#pragma target 3.5
			#pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
			#pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
            #include "LitInput.hlsl"
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
        }
    }
    CustomEditor "CustomShaderGUI"
}
