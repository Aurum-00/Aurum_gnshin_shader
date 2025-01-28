Shader "Unlit/Genshin_Aurum_Face"
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
		_FaceShadowOffset("Face Shadow Offset", range(-1.0, 1.0)) = 0.0
		_FaceShadowMapPow("Face Shadow Map Pow", range(0.001, 1.0)) = 0.2
		
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
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
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
		float _FaceShadowOffset;
		float _FaceShadowMapPow;
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

			half3 ShadowColor = baseMap.rgb * _ShadowMultColor.rgb;
			half3 DarkShadowColor = baseMap.rgb * _DarkShadowMultColor.rgb;

			float3 UpDir = float3(0, 1, 0);
			float3 FrontDir = TransformObjectToWorldDir(float3(0.0, 0.0, 1.0));
			//Unity左手坐标系,所以叉乘的正向结果为左向
			float3 LeftDir = cross(UpDir, FrontDir);
			float3 RightDir = -cross(UpDir, FrontDir);
			//光源信息
			Light mainLight = GetMainLight();
			half3 mainLightColor = mainLight.color;
			float3 LightDirWS = normalize(mainLight.direction);

			//在由于直接使用会产生头发阴影和面部阴影交错的问题，需要对光照方向进行偏移。
			//但直接在采样得到的FaceLightMap数据上±Offset等操作，会导致光照进入边缘时产生阴影跳变。
			//因此采用旋转偏移光照的方式。只需要构建一个XZ平面上的旋转矩阵即可。


			//sin(x) 输入参数为弧度，计算正弦值，返回值范围[-1,1]；
			float sinx = sin(_FaceShadowOffset);
			float cosx = cos(_FaceShadowOffset);
			//在XZ平面顺时针，绕y轴（unity向上是Y轴）
			//旋转矩阵[ cosx   -sinx ]
			//        [ sinx    cosx ]
			//旋转矩阵就是用来旋转的
			float2x2 rotationOffset = float2x2(cosx, -sinx, sinx, cosx);

			//为什么是xz，可能是为了效果在一个平面内横扫,不受光线向上向下
			float2 LightDir = normalize(mul(rotationOffset, LightDirWS.xz));
			//判断是否使用lightmap,dot(Front, lightDir)小于0说明光在角色背面，不应用lightmap（全部是阴影）
			//判断是否在阴影下，dot(RightDir , lightDir)小于lightmap的值 说明当前片元在阴影下面。
			float UseLightmap = dot(normalize(FrontDir.xz), LightDir);
			//计算xz平面下的光照角度
			float RdotL = dot(normalize(RightDir.xz), LightDir);
			float LdotL = dot(normalize(LeftDir.xz), LightDir);
			//这个计算我也不太明白,直接用Rdot好像也可以
			RdotL = -(acos(RdotL) / 3.14159265 - 0.5) * 2;

			//采样左右的Lightmap
			half4 ShadowR = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv);
			half4 ShadowL = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, float2(-input.uv.x, input.uv.y));

			half2 lightData = half2(ShadowR.a, ShadowL.a);
			//修改lightData的变化曲线，使中间大部分变化速度趋于平缓。
			lightData = pow(abs(lightData), _FaceShadowMapPow);
			
			//根据光照角度判断是否处于背光，使用正向还是反向的lightData
			//也就是说当min（1,1）的情况下处于亮部,这里需要想象一下
			//假设右侧30度角的光线照射，正向采样恒为1,取min就受到反向采样的影响，画出阴影
			float lightAttenuation = step(0, UseLightmap) * min(step(RdotL, lightData.x), step(-RdotL, lightData.y));
			//lightAttenuation [0.1]
			half3 FaceColor = lerp(ShadowColor.rgb, baseMap.rgb, lightAttenuation);

			return half4(FaceColor.rgb,1.0);
		}
			Varyings OutLineVertex(Attributes input)
		{
			Varyings output = (Varyings)0;
			float4 scaledScreenParams = GetScaledScreenParams();
			//计算
			float ScaleX = abs(scaledScreenParams.x / scaledScreenParams.y);
			VertexPositionInputs positionInputs = GetVertexPositionInputs(input.PositionOS.xyz);
			VertexNormalInputs normalInputs = GetVertexNormalInputs(input.Normal.xyz);
			float3 NormalCS = TransformWorldToHClipDir(normalInputs.normalWS);
			//_OutLineRange控制描边粗细
			float2 LineDis = normalize(NormalCS.xy) * (_OutLineRange * 0.01);
			LineDis.x /= ScaleX;
			output.PositionCS = positionInputs.positionCS;
			//描边随摄像机变化
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