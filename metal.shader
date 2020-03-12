Shader "Unlit/metal"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		LOD 100
        
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 vertexW : Pos;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.vertexW = mul(unity_ObjectToWorld,v.vertex).xyz;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
            
                float3 L = (_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - i.vertexW);
                float3 N = i.normal;
                
                //texture albedo
                fixed4 tex = tex2D(_MainTex, i.uv);
                
                //ambient
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                
                float3 lightCol = _LightColor0.rgb * LIGHT_ATTENUATION(i);
                
                float diff = pow( max(0.,dot(L,N)) * .5 + .5 , 2.);
                float spec = pow( max(0.,dot(normalize(L+V) ,N)),10.);
                
                tex.rgb = tex.rgb * (diff + ambient) + spec * lightCol;
                return tex;
            }
            ENDCG
        }
        
        Pass
        {
            Tags { "LightMode"="ForwardAdd" }
            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 vertexW : Pos;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.vertexW = mul(unity_ObjectToWorld,v.vertex).xyz;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
            
                float3 L = (_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - i.vertexW);
                float3 N = i.normal;
                
                //texture albedo
                fixed4 tex = tex2D(_MainTex, i.uv);
                
                
                float3 lightCol = _LightColor0.rgb * LIGHT_ATTENUATION(i);
                
                float diff = pow( max(0.,dot(L,N)) * .5 + .5 , 2.);
                float spec = pow( max(0.,dot(normalize(L+V) ,N)),190.);
                
                tex.rgb = tex.rgb * (diff) + spec * lightCol;
                return tex;
            }
            ENDCG
        }
        
		Pass
		{
            Tags { "LightMode"="ShadowCaster" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
			};

			struct v2f
			{
				V2F_SHADOW_CASTER;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
