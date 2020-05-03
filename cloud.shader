Shader "Unlit/cloud1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent"}
        LOD 100
        Cull Off
        //GrabPass{"_GrabTex"}
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float4 uv : TEXCOORD0;
                float2 tuv : TEXCOORD1;
                float4 vertex : POSITION;
            };

            struct g2f
            {
                float4 uv : TEXCOORD0;
                float4 vertexW : TEXCOORD1;
                float2 tuv : TEXCOORD2;
                float dd : TEXCOORD3;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
           // sampler2D _GrabTex;

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.uv = v.vertex;
               // o.vertex = mul(unity_ObjectToWorld,v.vertex);
                o.tuv = v.uv;
                return o;
            }

            float2x2 rot(float a)
            {
                float c = cos(a),s = sin(a);
                return float2x2(c,s,-s,c);
            }

            float3 random3(float3 c) {
                float j = 4096.0*sin(dot(c,float3(17.0, 59.4, 15.0)));
                float3 r;
                r.z = frac(512.0*j);
                j *= .125;
                r.x = frac(512.0*j);
                j *= .125;
                r.y = frac(512.0*j);
                return r-0.5;
            }

			float rand(float3 st)
			{
				return frac(sin(dot(st, float3(12.9898, 78.233,31.531))) * 100.0);
			}

            //https://www.shadertoy.com/view/XsX3zB
            /* skew constants for 3d simplex functions */
            const float F3 =  0.3333333;
            const float G3 =  0.1666667;
            
            /* 3d simplex noise */
            float simplex3d(float3 p) {
                /* 1. find current tetrahedron T and it's four vertices */
                /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
                /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
                
                /* calculate s and x */
                float3 s = floor(p + dot(p, float3(F3,F3,F3)));
                float3 x = p - s + dot(s, float3(G3,G3,G3));
                
                /* calculate i1 and i2 */
                float3 e = step(float3(0.,0.,0.), x - x.yzx);
                float3 i1 = e*(1.0 - e.zxy);
                float3 i2 = 1.0 - e.zxy*(1.0 - e);
                    
                /* x1, x2, x3 */
                float3 x1 = x - i1 + G3;
                float3 x2 = x - i2 + 2.0*G3;
                float3 x3 = x - 1.0 + 3.0*G3;
                
                /* 2. find four surflets and store them in d */
                float4 w, d;
                
                /* calculate surflet weights */
                w.x = dot(x, x);
                w.y = dot(x1, x1);
                w.z = dot(x2, x2);
                w.w = dot(x3, x3);
                
                /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
                w = max(0.6 - w, 0.0);
                
                /* calculate surflet components */
                d.x = dot(random3(s), x);
                d.y = dot(random3(s + i1), x1);
                d.z = dot(random3(s + i2), x2);
                d.w = dot(random3(s + 1.0), x3);
                
                /* multiply d by w^4 */
                w *= w;
                w *= w;
                d *= w;
                
                /* 3. return the sum of the four surflets */
                return dot(d, float4(52.0,52.0,52.0,52.0));
            }

            float3 simplex3dVector(float3 p)
            {
                float s = simplex3d(p);
                float s2 = simplex3d(random3(float3(p.y,p.x,p.z)) + p.yxz);
                float s3 = simplex3d(random3(float3(p.z,p.y,p.x)) + p.zyx);
                return float3(s,s2,s3);
            }

             float3 random33(float3 st)
            {
                st = float3(dot(st, float3(127.1, 311.7,811.5)),
                            dot(st, float3(269.5, 183.3,211.91)),
                            dot(st, float3(511.3, 631.19,431.81))
                            );
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            float4 celler3D(float3 i,float3 sepc)
            {
                float3 sep = i * sepc;
                float3 fp = floor(sep);
                float3 sp = frac(sep);
                float dist = 5.;
                float3 mp = 0.;

                [unroll]
                for (int z = -1; z <= 1; z++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 neighbor = float3(x, y ,z);
                            float3 pos = float3(random33(fp+neighbor));
                            pos = sin( (pos*6. +_Time.y/2.) )* 0.5 + 0.5;
                            float divs = length(neighbor + pos - sp);
                            mp = (dist >divs)?pos:mp;
                            dist = (dist > divs)?divs:dist;
                        }
                    }
                }
                return float4(mp,dist);
            }

            float3 curlNoiseSimp(float3 p)
            {
                float3 e = float3(0.0009765625,0.,0.);

                float3 x1 = simplex3dVector(p - e);
                float3 x2 = simplex3dVector(p + e);
                float3 y1 = simplex3dVector(p - e.yxz);
                float3 y2 = simplex3dVector(p + e.yxz);
                float3 z1 = simplex3dVector(p - e.zyx);
                float3 z2 = simplex3dVector(p - e.zyx);

                float x = y2.z - y1.z - z2.y + z1.y;
                float y = z2.x - z1.x - x2.z + x1.z;
                float z = x2.y - x1.y - y2.x + y1.x;

                return normalize(float3(x,y,z)/2.*e.x);
            }

            float3 curlNoiseCell(float3 p,float s)
            {
                float3 e = float3(0.0009765625,0.,0.);

                float3 x1 = celler3D(p - e,s).xyz;
                float3 x2 = celler3D(p + e,s).xyz;
                float3 y1 = celler3D(p - e.yxz,s).xyz;
                float3 y2 = celler3D(p + e.yxz,s).xyz;
                float3 z1 = celler3D(p - e.zyx,s).xyz;
                float3 z2 = celler3D(p - e.zyx,s).xyz;

                float x = y2.z - y1.z - z2.y + z1.y;
                float y = z2.x - z1.x - x2.z + x1.z;
                float z = x2.y - x1.y - y2.x + y1.x;

                return normalize(float3(x,y,z)/2.*e.x);
            }

            float3 lightCurl(float3 p)
            {
                float2 e = float2(.001,0);
                return normalize(.0000001 + simplex3d(p) - float3(simplex3d(p - e.xyy),simplex3d(p - e.yxy),simplex3d(p - e.yyx)));
            }

            [maxvertexcount(12) ]
			 void geom(triangle v2g ip[3], inout TriangleStream<g2f> OutputStream)
			{

				g2f v = (g2f)0;
                float3 cd = -UNITY_MATRIX_V[2].xyz;
                float3 cu = normalize(UNITY_MATRIX_V[1].xyz);
                float3 cs = normalize(UNITY_MATRIX_V[0].xyz);

                //cu = mul(unity_WorldToObject,float4(cu,1)).xyz;
                //cs = mul(unity_WorldToObject,float4(cs,1)).xyz;
                
				float3 o = (ip[0].vertex.xyz/3. + ip[1].vertex.xyz/3. +ip[2].vertex.xyz/3.) ;
                float dd = length(ip[0].vertex.xyz - ip[1].vertex.xyz - ip[2].vertex.xyz) ;
                float3 ow = mul(unity_ObjectToWorld,float4(o,1.)).xyz;
                float3 m =  curlNoiseSimp(o*20.);
                // m =smoothstep(m, lightCurl(ow*2.),(sin((o.y*10+_Time.y)/3.)+1)/2);
                //float3 m = simplex3d(ow *2.);
				//m = 0;
                o += (cu + cs) * (m.xyz)/18.;
                //o = mul(unity_WorldToObject,float4(ow,1)).xyz;
				//o += cd * (simplex3d(o*10.)); 
                v.uv =  (ip[0].uv + ip[1].uv +ip[2].uv)/ 3. ;
				// cu = mul(unity_WorldToObject,float4(cu,1)).xyz;
				// cd = mul(unity_WorldToObject,float4(cu,1)).xyz;
                [unroll]
                for(int x = -1; x < 1 ; x++)
                {
                    [unroll]
                    for(int y = -1; y < 1 ; y++)
                    {
                        float xx = (float(x) + .5) *(.3+0.05*cos((_Time.y + 10. )/15.));
						float yy = (float(y) + .5)*(.3+0.05*sin((_Time.y + 10. )/15.));
                        float3 p = o + ((cu) * yy + (cs) * xx );
                        v.tuv = float2(y+.5 ,x+.5 );
                        v.vertexW = float4(p,1);
                        v.vertex = UnityObjectToClipPos(float4(p,1));
                        v.dd = (dd < .2);
                        v.uv = (v.vertex);
                        v.normal = UnityObjectToWorldNormal(normalize(m));
                        OutputStream.Append(v);
                    }
                }
		    }

            //http://light11.hatenadiary.com/entry/2018/07/08/212014
            // Box Projectionを考慮した反射ベクトルを取得
            float3 boxProjection(float3 normalizedDir, float3 worldPosition, float4 probePosition, float3 boxMin, float3 boxMax)
            {
               #if UNITY_SPECCUBE_BOX_PROJECTION
                    if (probePosition.w > 0) {
                        float3 magnitudes = ((normalizedDir > 0 ? boxMax : boxMin) - worldPosition) / normalizedDir;
                        float magnitude = min(min(magnitudes.x, magnitudes.y), magnitudes.z);
                        normalizedDir = normalizedDir* magnitude + (worldPosition - probePosition);
                    }
               #endif

                return normalizedDir;
            }

            fixed4 frag (g2f i) : SV_Target
            {
               // float2 uv = i.uv.xy/i.uv.w;
               // fixed4 col = tex2D(_GrabTex, uv);
               // float dis = length(_WorldSpaceCameraPos.xyz - i.vertexW.xyz);
               // col.rgb =1 - (col.rgb - dis);

                clip(-i.dd);
                float cloud = 0.1;
				//float4 o = mul(unity_WorldToObject,i.vertexW);
                float4 o = i.vertexW;
                cloud += simplex3d(o.xyz * 2.5 +_Time.y/6.) * 0.5;
               // cloud += simplex3d(i.vertexW.xyz*0.1 - _Time.y/100) * 0.5;
                
                i.tuv *= 2.;
                i.dd = saturate(i.dd);
                float sep = ((cloud < length(i.tuv)*.4 )) > 0;
                clip(sep*-1);
                float depth = 0.;
                float3 cc = 0.;

                float3 color;
                color = 0.;
				color.r = 1 - sin((cloud * 16. +_Time.y)/5.);
				cloud = cloud * cloud + 0.5;
				color.bg = cos((cloud+_Time.y) /25);

				color = saturate(color);
                
                half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.vertexW);
                half3 reflDir = reflect(-worldViewDir, i.normal);
                
                half3 reflDir0 = boxProjection(reflDir, i.vertexW, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                half3 reflDir1 = boxProjection(reflDir, i.vertexW, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
                
                half4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir0, 0);
                refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);

                // SpecCube1のサンプラはSpecCube0のものを使う
                half4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflDir1, 0);
                refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);

                // unity_SpecCube0_BoxMin.w にブレンド率が入ってくる
                float4 probe = lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);
                color = (color) * probe;
                return float4(color,1 -length(i.tuv));
            }
            ENDCG
        }
    }
}
