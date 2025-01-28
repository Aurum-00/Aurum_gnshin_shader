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
			//VertexPositionInput �����ռ�����ṹ�� 
			VertexPositionInputs positionInputs = GetVertexPositionInputs(input.PositionOS.xyz);
			output.PositionCS = positionInputs.positionCS;
			output.PositionWS = positionInputs.positionWS;
			output.PositionVS = positionInputs.positionVS;
			//VertexNormalInputs �����ռ䷨�߽ṹ��
			VertexNormalInputs normalInputs = GetVertexNormalInputs(input.Normal.xyz);
			output.NormalWS = normalInputs.normalWS;
			output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

			//��������
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
			//Unity��������ϵ,���Բ�˵�������Ϊ����
			float3 LeftDir = cross(UpDir, FrontDir);
			float3 RightDir = -cross(UpDir, FrontDir);
			//��Դ��Ϣ
			Light mainLight = GetMainLight();
			half3 mainLightColor = mainLight.color;
			float3 LightDirWS = normalize(mainLight.direction);

			//������ֱ��ʹ�û����ͷ����Ӱ���沿��Ӱ��������⣬��Ҫ�Թ��շ������ƫ�ơ�
			//��ֱ���ڲ����õ���FaceLightMap�����ϡ�Offset�Ȳ������ᵼ�¹��ս����Եʱ������Ӱ���䡣
			//��˲�����תƫ�ƹ��յķ�ʽ��ֻ��Ҫ����һ��XZƽ���ϵ���ת���󼴿ɡ�


			//sin(x) �������Ϊ���ȣ���������ֵ������ֵ��Χ[-1,1]��
			float sinx = sin(_FaceShadowOffset);
			float cosx = cos(_FaceShadowOffset);
			//��XZƽ��˳ʱ�룬��y�ᣨunity������Y�ᣩ
			//��ת����[ cosx   -sinx ]
			//        [ sinx    cosx ]
			//��ת�������������ת��
			float2x2 rotationOffset = float2x2(cosx, -sinx, sinx, cosx);

			//Ϊʲô��xz��������Ϊ��Ч����һ��ƽ���ں�ɨ,���ܹ�����������
			float2 LightDir = normalize(mul(rotationOffset, LightDirWS.xz));
			//�ж��Ƿ�ʹ��lightmap,dot(Front, lightDir)С��0˵�����ڽ�ɫ���棬��Ӧ��lightmap��ȫ������Ӱ��
			//�ж��Ƿ�����Ӱ�£�dot(RightDir , lightDir)С��lightmap��ֵ ˵����ǰƬԪ����Ӱ���档
			float UseLightmap = dot(normalize(FrontDir.xz), LightDir);
			//����xzƽ���µĹ��սǶ�
			float RdotL = dot(normalize(RightDir.xz), LightDir);
			float LdotL = dot(normalize(LeftDir.xz), LightDir);
			//���������Ҳ��̫����,ֱ����Rdot����Ҳ����
			RdotL = -(acos(RdotL) / 3.14159265 - 0.5) * 2;

			//�������ҵ�Lightmap
			half4 ShadowR = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv);
			half4 ShadowL = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, float2(-input.uv.x, input.uv.y));

			half2 lightData = half2(ShadowR.a, ShadowL.a);
			//�޸�lightData�ı仯���ߣ�ʹ�м�󲿷ֱ仯�ٶ�����ƽ����
			lightData = pow(abs(lightData), _FaceShadowMapPow);
			
			//���ݹ��սǶ��ж��Ƿ��ڱ��⣬ʹ�������Ƿ����lightData
			//Ҳ����˵��min��1,1��������´�������,������Ҫ����һ��
			//�����Ҳ�30�ȽǵĹ������䣬���������Ϊ1,ȡmin���ܵ����������Ӱ�죬������Ӱ
			float lightAttenuation = step(0, UseLightmap) * min(step(RdotL, lightData.x), step(-RdotL, lightData.y));
			//lightAttenuation [0.1]
			half3 FaceColor = lerp(ShadowColor.rgb, baseMap.rgb, lightAttenuation);

			return half4(FaceColor.rgb,1.0);
		}
			Varyings OutLineVertex(Attributes input)
		{
			Varyings output = (Varyings)0;
			float4 scaledScreenParams = GetScaledScreenParams();
			//����
			float ScaleX = abs(scaledScreenParams.x / scaledScreenParams.y);
			VertexPositionInputs positionInputs = GetVertexPositionInputs(input.PositionOS.xyz);
			VertexNormalInputs normalInputs = GetVertexNormalInputs(input.Normal.xyz);
			float3 NormalCS = TransformWorldToHClipDir(normalInputs.normalWS);
			//_OutLineRange������ߴ�ϸ
			float2 LineDis = normalize(NormalCS.xy) * (_OutLineRange * 0.01);
			LineDis.x /= ScaleX;
			output.PositionCS = positionInputs.positionCS;
			//�����������仯
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