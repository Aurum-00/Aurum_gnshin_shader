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

			/*在《UnityShader 入门精要》中一般对从应用传入
			顶点着色器的输出结构体和从顶点传入片元着色器的输出结构体命名为a2v和v2f。
			在HLSL中这两个结构体一般被命名成Attributes和Varying。

			对于一些三维坐标、向量的命名，在HLSL中一般在命名结尾使用空间名字缩写表示其所属的空间。
			比如positionOS就是对象坐标戏（Object Space）下的位置坐标，NormalWS就是世界坐标系下的法线坐标。*/

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
				//我们声明了一个结构体positionInputs，并调用了GetVertexPositionInputs()函数来填充这个结构体里的数据。
				//GetVertexPositionInputs()可以访问各个空间下的顶点坐标,替我们完成了变换。
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
			//物体这时候会消失，打开你正在使用的的通用渲染器（Universal Renderer Data），找到渲染（Rendering）->深度引动模式（Depth Priming Mode），将其从默认的“自动”修改为“已禁用”。

		 }
}