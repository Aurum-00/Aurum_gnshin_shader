Shader "Unlit/Simpler"
{
	 Properties
	 {
		 _BaseMap ("Base Map", 2D) = "white"{}
		 _BaseColor ("Base Color", Color) = (1,1,1,1)
	 }
	SubShader
		 {
			 Tags
			 {
				 "RenderPipeline" = "universalPipeline"
				 "Queue" = "Geometry"
				 "RenderType" = "Opaque"
			 }
			 HLSLINCLUDE
			 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			 
			 CBUFFER_START(UnityPerMaterial)
			 float4 _BaseMap_ST;
			 half4 _BaseColor;
			 CBUFFER_END
			
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);

			/*�ڡ�UnityShader ���ž�Ҫ����һ��Դ�Ӧ�ô���
			������ɫ��������ṹ��ʹӶ��㴫��ƬԪ��ɫ��������ṹ������Ϊa2v��v2f��
			��HLSL���������ṹ��һ�㱻������Attributes��Varying��

			����һЩ��ά���ꡢ��������������HLSL��һ����������βʹ�ÿռ�������д��ʾ�������Ŀռ䡣
			����positionOS���Ƕ�������Ϸ��Object Space���µ�λ�����꣬NormalWS������������ϵ�µķ������ꡣ*/

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct Varings
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			Varings vert(Attributes IN)
			{
				Varings OUT;
				/*VertexPositionInputs GetVertexPositionInputs(float3 positionOS)
				{
					VertexPositionInputs input;
					input.positionWS = TransformObjectToWorld(positionOS);
					input.positionVS = TransformWorldToView(input.positionWS);
					input.positionCS = TransformWorldToHClip(input.positionWS);

					float4 ndc = input.positionCS * 0.5f;
					input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
					input.positionNDC.zw = input.positionCS.zw;

					return input;
				}*/
				//����������һ���ṹ��positionInputs����������GetVertexPositionInputs()�������������ṹ��������ݡ�
				//GetVertexPositionInputs()���Է��ʸ����ռ��µĶ�������,����������˱任��
				VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				OUT.positionCS = positionInputs.positionCS;

				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				return OUT;
			}

			float4 frag(Varings IN) : SV_Target
			{
				half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
				return baseMap.a * _BaseColor;
			}
				ENDHLSL

				Pass
			{
				HLSLPROGRAM 
				
				#pragma vertex vert
				#pragma fragment frag
				
					ENDHLSL
			}
			//������ʱ�����ʧ����������ʹ�õĵ�ͨ����Ⱦ����Universal Renderer Data�����ҵ���Ⱦ��Rendering��->�������ģʽ��Depth Priming Mode���������Ĭ�ϵġ��Զ����޸�Ϊ���ѽ��á���

		 }
}