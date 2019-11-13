Shader "Unlit/qrystal"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_MaskTex ("MaskTexture", 2D) = "balck" {}
		_QrystalLength("Qrystal Length",float) = 1.0
		_QrystalSize("QrystalSize",float) = 0
		_Sharpness("Sharpness",float) = 1.0
		[HDR]_Color("Color",Color) = (1,1,1)
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "LightMode" = "ForwardBase"}
		LOD 100
		Cull off
		Blend SrcAlpha OneMinusSrcAlpha
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 normal :NORMAL;
			};

			struct v2g
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 normal :NORMAL;
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 normal :NORMAL;
				float nqrystal: TEXCOORD1;
				float4 vertexW : TEXCOORD2;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			sampler2D _MaskTex;

			float _QrystalLength;
			float _QrystalSize;
			float _Sharpness;

			float4 _Color;

			v2g vert (appdata v)
			{
				v2g o;
				o.vertex = v.vertex;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = v.normal;
				return o;
			}

			float3 getNormal(float3 v0,float3 v1,float3 v2)
			{
				float3 edge1 = (v1 - v0);
				float3 edge2 = (v2 - v0);
				float3 normal = normalize(cross(edge1, edge2));
				return normal;
			}

			float rand(float2 co){
				return frac(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453);
			}

			float rand(float3 co){
				return frac(sin(dot(co.xyz ,float3(12.9898,78.233,46.544))) * 43758.5453);
			}

			float3 reflection(g2f i, float3 col, float3 SpecularCol, float Shiness)
			{
					UNITY_LIGHT_ATTENUATION(attenuation, i, i.vertexW.xyz)
					float3 view = normalize(_WorldSpaceCameraPos - i.vertexW.xyz);
					float3 normal = normalize(i.normal);
					float3 light = normalize((_WorldSpaceLightPos0.w == 0) ? _WorldSpaceLightPos0.xyz : _WorldSpaceLightPos0 - i.vertexW);
					light = float3(-1, -0.5, 1);
					//directional light
					float3 rflt = normalize(reflect(-light, normal));
					//反射光ベクトルを検出し正規化している
					float diffuse = saturate(dot(normal, light));
					float specular = pow(saturate(dot(view, rflt)), Shiness);
					float3 ambient = ShadeSH9(half4(normal, 1));
					fixed3 color = diffuse * col * _LightColor0
						+ specular * SpecularCol * _LightColor0;
					color += ambient * col;
					return color;
			}

			float perlinNoise(fixed2 st) 
            {
                fixed2 p = floor(st);
                fixed2 f = frac(st);
                fixed2 u = f*f*(3.0-2.0*f);

                float v00 = rand(p+fixed2(0,0));
                float v10 = rand(p+fixed2(1,0));
                float v01 = rand(p+fixed2(0,1));
                float v11 = rand(p+fixed2(1,1));

                return lerp( lerp( dot( v00, f - fixed2(0,0) ), dot( v10, f - fixed2(1,0) ), u.x ),
                             lerp( dot( v01, f - fixed2(0,1) ), dot( v11, f - fixed2(1,1) ), u.x ), 
                             u.y)+0.5f;
            }

			[maxvertexcount(56) ]
			 void geom(triangle v2g ip[3], inout TriangleStream<g2f> OutputStream)
			{
				g2f v = (g2f)0;

				[unroll]
				for(int j = 0;j < 3;j++){
					v.vertex = UnityObjectToClipPos(ip[j].vertex);
					v.uv = ip[j].uv;
					v.normal = ip[j].normal;
					v.nqrystal = 5;
					OutputStream.Append(v);
				}
				OutputStream.RestartStrip();

				g2f o = (g2f)0;

				o.uv = (ip[0].uv + ip[1].uv + ip[2].uv)/3.;

				float3 p0 = ip[0].vertex.xyz;
				float3 p1 = ip[1].vertex.xyz;
				float3 p2 = ip[2].vertex.xyz;

				float3 needle = float3(1./3.,1./3.,1./3.);
				float3 tri =  float3(2./4.,1./4.,1./4.);
				float3 itri = float3(2./5.,2./5.,1./5.);

				float3 dir = getNormal(p0,p1,p2) * (rand((p0+p1+p2)/3));
				
				float3 random = rand(p0+p1+p2);
				float3 size1 = (random - 0.5)*_QrystalSize;
				float3 size2 = (rand(size1) - 0.5) * _QrystalSize;
				
				float len =_QrystalLength * length(random);


				float3 pp0 = (p0*needle.x  + p1*needle.y + p2*needle.z );
				float3 pp1 = (p0*tri.x   + p1*tri.y  + p2*tri.z);
				float3 pp2 = (p0*itri.x  + p1*itri.y + p2*itri.z );
				float3 pp3 = (p0*tri.y   + p1*tri.x  + p2*tri.z );
				float3 pp4 = (p0*itri.z  + p1*itri.x + p2*itri.y );
				float3 pp5 = (p0*tri.z   + p1*tri.y  + p2*tri.x );
				float3 pp6 = (p0*itri.y  + p1*itri.z + p2*itri.x );

				float3 pv1 = normalize(pp1-pp0);
				float3 pv2 = normalize(pp2-pp0);
				float3 pv3 = normalize(pp3-pp0);
				float3 pv4 = normalize(pp4-pp0);
				float3 pv5 = normalize(pp5-pp0);
				float3 pv6 = normalize(pp6-pp0);

				pp0 += dir * length(size1);
				pp1 += pv1 * size1;
				pp2 += pv2 * size1;
				pp3 += pv3 * size1;
				pp4 += pv4 * size2;
				pp5 += pv5 * size2;
				pp6 += pv6 * size2;

				float3 pp0d = pp0 + dir * len * _Sharpness;
				float3 pp1d = pp1 + dir * len;
				float3 pp2d = pp2 + dir * len;
				float3 pp3d = pp3 + dir * len;
				float3 pp4d = pp4 + dir * len;
				float3 pp5d = pp5 + dir * len;
				float3 pp6d = pp6 + dir * len;
				
				float4 v4o = float4(0,0,0,0);
				float4 normal = float4(0,0,0,1);


				//1
				normal = float4(getNormal(pp1,pp2,pp1d),1);
				v4o = float4(pp1,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp2,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp1d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				normal = float4(getNormal(pp1d,pp2,pp2d),1);
				v4o = float4(pp2,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp1d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp2d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				o.nqrystal = 0;
				OutputStream.RestartStrip();

				//2
				normal = float4(getNormal(pp2,pp3,pp2d),1);
				v4o = float4(pp2,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp3,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp2d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				normal = float4(getNormal(pp2d,pp3,pp3d),1);
				v4o = float4(pp3,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp3d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp2d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				//3
				normal = float4(getNormal(pp3,pp4,pp3d),1);
				v4o = float4(pp3,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp4,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp3d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				normal = float4(getNormal(pp3d,pp4,pp4d),1);
				v4o = float4(pp4,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp4d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp3d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				//4
				normal = float4(getNormal(pp4,pp5,pp4d),1);
				v4o = float4(pp4,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp5,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp4d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				normal = float4(getNormal(pp4d,pp5,pp5d),1);
				v4o = float4(pp5,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp5d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp4d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				//5
				normal = float4(getNormal(pp5,pp6,pp5d),1);
				v4o = float4(pp5,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp6,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp5d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				normal = float4(getNormal(pp5d,pp6,pp6d),1);
				v4o = float4(pp6,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp6d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp5d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				//6
				normal = float4(getNormal(pp6,pp1,pp6d),1);
				v4o = float4(pp6,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp1,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp6d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				normal = float4(getNormal(pp6d,pp1,pp1d),1);
				v4o = float4(pp1,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp1d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp6d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();


				//top1
				normal = float4(getNormal(pp1d,pp2d,pp0d),1);
				v4o = float4(pp1d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp2d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp0d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				//top2
				normal = float4(getNormal(pp2d,pp3d,pp0d),1);
				v4o = float4(pp2d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp3d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp0d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				OutputStream.RestartStrip();

				//top3
				normal = float4(getNormal(pp3d,pp4d,pp0d),1);
				v4o = float4(pp3d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp4d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp0d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				//top4
				normal = float4(getNormal(pp4d,pp5d,pp0d),1);
				v4o = float4(pp4d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp5d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp0d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				//top5
				normal = float4(getNormal(pp5d,pp6d,pp0d),1);
				v4o = float4(pp5d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp6d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp0d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);

				//top6
				normal = float4(getNormal(pp6d,pp1d,pp0d),1);
				v4o = float4(pp6d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp1d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
				v4o = float4(pp0d,1);
				o.normal = normal;
				o.vertex = UnityObjectToClipPos(v4o);
				o.nqrystal = 0;
				o.vertexW = v4o;
				OutputStream.Append(o);
		    }
			
			fixed4 frag (g2f i) : SV_Target
			{
				fixed4 mask = tex2D(_MaskTex,i.uv);
				
				fixed4 col = tex2D(_MainTex, i.uv);

				float Crystal = (i.nqrystal < 0);
				float nCrystal = 1 - Crystal;
				float rate = 0.5;

				float3 specularCol = perlinNoise(i.vertexW.xz) * _Color  ;
				
				specularCol = Crystal*specularCol + nCrystal*float3(1,1,1);
				float3 rcol = reflection(i,col,specularCol,30);
				col.rgb = Crystal * rcol + nCrystal * lerp(col,rcol,rate);

				float alpha = perlinNoise(float2(length(i.vertexW),length(col))*10. );
				col.a = Crystal * clamp( alpha,0,1) + nCrystal * 1;
				col = clamp(col,0,1);
				if(mask.g  < 0.5)
				{
					if(i.nqrystal < 0.5){discard;}
				}
				return col;
			}
			ENDCG
		}
		
	}
}
