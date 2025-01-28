Shader "Unlit/Genshin_Aurum_Hair"
{
	Properties
	{
		//Basecolor(Diffuse)
		[Header(Main Texture Setting)]
		[Space(5)]
		[NoScaleOffset] [MainTexture] _BaseMap("Base Map(Albedo)", 2D) = "black" {}
		[MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)

		[Header(LightMap)]
		[Space(5)]
		[NoScaleOffset] _LightMap("Light Map", 2D) = "black" {}
		_ShadowMultColor("Shadow CoLor", Color) = (1,1,1,1)
		_DarkShadowMultColor("Dark Shadow Color", Color) = (1,1,1,1)
		
		[Header(Specular Setting)]
		_SpecularColor("Specular color", Color) = (1,1,1,1)
		_Gloss("Gloss", Range(8, 20)) = 8.0
		
		[Header(RampMap)]
		[Space(5)]
		[NoScaleOffset] _RampMap("Ramp Map", 2D) = "black" {}
		_RampRange("Ramp Range", Range(0.0, 1.0)) = 0.8
		_Day("Day or Night",Range(0.0,1.0)) = 0.2

		[Header(OutLine)]
		[Space(5)]
		_OutLineRange("Out Line Range", Range(0, 5)) = 0.4
		_OutLineColor("Out Line Color", Color) = (0,0,0,0)

	}

		SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
		CBUFFER_START(UnityPerMaterial)
		
		float4 _BaseMap_ST;
		float4 _BaseColor;
		float4 _LightMap_ST;
		float4 _RampMap_ST;
		float4 _ShadowMultColor;
		float4 _DarkShadowMultColor;
		float4 _SpecularColor;
		float _Gloss;
		float _RampRange;
		float _Day;
		float _OutLineRange;
		float4 _OutLineColor;
		
		
		CBUFFER_END
		

		TEXTURE2D(_BaseMap);       SAMPLER(sampler_BaseMap);
		TEXTURE2D(_LightMap);      SAMPLER(sampler_LightMap);
		TEXTURE2D(_RampMap);      SAMPLER(sampler_RampMap);

		struct Attributes
		{
			float4 PositionOS : POSITION;
			float3 Normal : NORMAL;
			float2 texcoord : TEXCOORD0;
			float4 tangentOS : TANGENT;
			float4 vertexColor : COLOR;
		};

		struct Varyings
		{
			float4 PositionCS : SV_POSITION;
			float3 NormalWS : TEXCOORD0;
			float3 PositionWS : TEXCOORD1;
			float2 uv : TEXCOORD2;
			float4 Color : TEXCOORD3;
			float3 PositionVS : TEXCOORD4;
			float HalfLambert : TEXCOORD5;
			
		};

		Varyings MainVertex(Attributes input)
		{
			Varyings output = (Varyings)0;
			//VertexPositionInput 各个空间坐标结构体 
			VertexPositionInputs positionInputs = GetVertexPositionInputs(input.PositionOS.xyz);
			output.PositionCS = positionInputs.positionCS;
			output.PositionWS = positionInputs.positionWS;
			output.PositionVS = positionInputs.positionVS;
			//VertexNormalInputs 各个空间法线结构体
			VertexNormalInputs normalInputs = GetVertexNormalInputs(input.Normal.xyz);
			output.NormalWS = normalInputs.normalWS;
			output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

			//半兰伯特
			float3 LightDirWS = normalize(_MainLightPosition.xyz);
			float Lambert = dot(output.NormalWS, LightDirWS);
			output.HalfLambert = Lambert * 0.5 + 0.5;

			return output;

		}

		half4 MainFrag(Varyings input) : SV_Target
		{
			
			half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
			half4 LightMapColor = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv);

			half3 ShadowColor = baseMap.rgb * _ShadowMultColor.rgb;
			half3 DarkShadowColor = baseMap.rgb * _DarkShadowMultColor.rgb;



			float rampValue = input.HalfLambert * (1.0 / _RampRange - 0.003);
			float rampVmove = 0;
			if (_Day > 0.5) {
				rampVmove += 0.5;   //如果是白天，采样上面
			}
			else {
				rampVmove += 0.0;   //如果是夜晚，采样下面
			}
			half3 ShadowRamp1 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampValue, 0.45 + rampVmove)).rgb;
			half3 ShadowRamp2 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampValue, 0.35 + rampVmove)).rgb;
			half3 ShadowRamp3 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampValue, 0.25 + rampVmove)).rgb;
			half3 ShadowRamp4 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampValue, 0.15 + rampVmove)).rgb;
			half3 ShadowRamp5 = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(rampValue, 0.05 + rampVmove)).rgb;

			//这里的0.05应该是个经验数值，判断Alpha值误差是否在一定范围内
			half3 skinRamp = step(abs(LightMapColor.a - 1), 0.05) * ShadowRamp2;
			half3 tightsRamp = step(abs(LightMapColor.a - 0.7), 0.05) * ShadowRamp1;
			half3 softCommonRamp = step(abs(LightMapColor.a - 0.5), 0.05) * ShadowRamp1;
			half3 hardSilkRamp = step(abs(LightMapColor.a - 0.3), 0.05) * ShadowRamp1;
			half3 metalRamp = step(abs(LightMapColor.a - 0), 0.05) * ShadowRamp1;

			half3 finalRamp = skinRamp + tightsRamp + metalRamp + softCommonRamp + hardSilkRamp;

			rampValue = step(_RampRange, input.HalfLambert);
			half3 RampShadowColor = rampValue * baseMap.rgb + (1 - rampValue) * finalRamp * baseMap.rgb;

			ShadowColor = RampShadowColor;
			DarkShadowColor = RampShadowColor;

			return half4 (RampShadowColor.rgb, 1.0);
		}
			Varyings OutLineVertex(Attributes input)
		{
			Varyings output = (Varyings)0;
			float4 scaledScreenParams = GetScaledScreenParams();
			float ScaleX = abs(scaledScreenParams.x / scaledScreenParams.y);
			VertexPositionInputs positionInputs = GetVertexPositionInputs(input.PositionOS.xyz);
			VertexNormalInputs normalInputs = GetVertexNormalInputs(input.Normal.xyz);
			float3 NormalCS = TransformWorldToHClipDir(normalInputs.normalWS);
			float2 LineDis = normalize(NormalCS.xy) * (_OutLineRange * 0.01);
			LineDis.x /= ScaleX;
			output.PositionCS = positionInputs.positionCS;
			output.PositionCS.xy += LineDis;

			return output;


		}

		half4 OutLineFrag(Varyings input) : SV_Target
		{
			return float4(_OutLineColor.rgb, 1);
		}
			ENDHLSL

		Pass
		{
			Tags { "LightMode" = "UniversalForward" }
				
			HLSLPROGRAM

			
			#pragma vertex MainVertex
			#pragma fragment MainFrag
			ENDHLSL
		}
		Pass
		{
			Tags{}
				Cull front
				HLSLPROGRAM

#pragma vertex OutLineVertex
#pragma fragment OutLineFrag

				ENDHLSL
		}
	}
}