Shader "Unlit/StendGrass3"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _Size("Blur Size",float) = 1
        _Scale("Scale",float) = 10.
        _Rate("Rate",range(0,1)) = 0.5
        _Speed("Move Speed",float) = 0.
    }
    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent"}
        GrabPass{"_GrabTex0"}

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _GrabTex0;
            float _Size;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = ComputeGrabScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float Size = _Size;
                Size = max(1,Size);
                fixed4 col = 0.;
                float2 uv = i.uv.xy/i.uv.w;
                float3 texelSize = float3(1./_ScreenParams.xy,0.);
                float weightSum = 0.;
                //[unroll]
                for(float i = -Size ; i <= Size; i++)
                {
                    float normDistance = abs(i/Size);
                    float weight = exp(-.5 * pow(normDistance , 2.)*5.);
                    weightSum += weight;
                    col += tex2D(_GrabTex0,uv + i * texelSize.xz)*weight;
                   // col += tex2D(_GrabTex,uv + i * texelSize.zy)*weight;
                }
                col /= weightSum * 1.;
                return col;
            }
            ENDCG
        }
        GrabPass{"_GrabTex2"}

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _GrabTex2;
            float _Size;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = ComputeGrabScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float Size = _Size;
                Size = max(1,Size);
                fixed4 col = 0.;
                float2 uv = i.uv.xy/i.uv.w;
                float3 texelSize = float3(1./_ScreenParams.xy,0.);
                float weightSum = 0.;
                //[unroll]
                for(float i = -Size ; i <= Size; i++)
                {
                    float normDistance = abs(i/Size);
                    float weight = exp(-.5 * pow(normDistance , 2.)*5.);
                    weightSum += weight;
                    //col += tex2D(_GrabTex,uv + i * texelSize.xz)*weight;
                    col += tex2D(_GrabTex2,uv + i * texelSize.zy)*weight;
                }
                col /= weightSum * 1.;
              //  col = tex2D(_GrabTex,uv);
                return col;
            }
            ENDCG
        }
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent" "LightMode"="ForwardBase"}
        GrabPass{"_GrabTex"}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

             struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
                float2 ouv :texcoord3;
                float3 pos : texcoord4;
                float3 normal : normal;
                half3 lightDir : TEXCOORD5;
                half3 viewDir : TEXCOORD6;
            };

            sampler2D _GrabTex;
            float4 _MainTex_ST;
            float _Scale;
            float4 _LightColor0;
            float _Rate;
            float _Speed;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                //o.uv = v.uv;
                o.uv = ComputeGrabScreenPos(o.vertex);
                o.ouv = v.uv;
                o.pos = v.vertex.xyz;
                o.normal = v.normal;

                TANGENT_SPACE_ROTATION;
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
                return o;
            }

            float3 random33(float3 st)
            {
                st = float3(dot(st, float3(127.1, 311.7,811.5)),
                            dot(st, float3(269.5, 183.3,211.91)),
                            dot(st, float3(511.3, 631.19,431.81))
                            );
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            struct Cells{
                float3 Opos;
                float3 Normal;
                float dist;
            };

            Cells celler3D_returnPos(float3 i,float3 sepc)
            {
                float3 sep = i * sepc;
                float3 fp = floor(sep);
                float3 sp = frac(sep);
                float dist = 5.;
                float3 mp = 0.;
                float3 opos = 0.;
                Cells cell;

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
                            float3 rpos = float3(random33(fp+neighbor));
                            float3 pos = sin( (rpos*6. +_Time.y/2. * _Speed) )* 0.5 + 0.5;
                            float divs = length(neighbor + pos - sp);
                            if(dist > divs)
                            {
                                mp = pos;
                                dist = divs;
                                opos = neighbor + fp + rpos;
                                opos = neighbor + pos - sp;
                                
                                cell.Opos = neighbor + fp + rpos;
                                cell.Normal = neighbor + pos - sp;
                                cell.dist = divs;
                            }
                        }
                    }
                }
                //return float4(opos,dist);
                return cell;
            }

            

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv.xy/i.uv.w;
                float scale = _Scale;
                float2 ouv = i.ouv;
                //float4 opos = celler3D_returnPos(i.pos,scale);
                Cells cell = celler3D_returnPos(i.pos,scale);
                cell.Opos /= scale;
                float4 grabUV = ComputeGrabScreenPos(UnityObjectToClipPos(float4(cell.Opos,1.)));
                float2 screenuv = grabUV.xy / grabUV.w;
                fixed4 col = tex2D(_GrabTex, screenuv) ;
                //col = 1.;

                float3 ld = normalize(i.lightDir);
                float3 vd = normalize(i.viewDir);
                float3 halfDir = normalize(ld + vd);

                //float 
                float3 dir = cell.Normal;
                //i.normal = normalize(i.normal  );
                i.normal = dir;
                //i.normal.x += step(opos.z,.5);
                half4 diff = saturate(dot(i.normal, ld)) * _LightColor0;
                diff = lerp(diff,1.,_Rate);
                half3 sp = pow(max(0, dot(i.normal, halfDir)), 10. * 128.0) * col.rgb;

                col.rgb = diff * col.rgb + sp * col.rgb;
              //  col.rgb = i.normal;
               // col.rgb = opos.rgb*scale;
                //col.rgb = opos.rgb;
                //col.rgb += sp;
                return col;
            }
            ENDCG
        }
    }
}
