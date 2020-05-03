Shader "Water/BrethingUnderwater_R"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _WaterHeight("Water Height",float) = 0
        _Fineness("Fineness",float) = 1
        _WaveDiv("Wave divide",float) = 1
        _Frequency("Frequency",float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching" = "True"}
        LOD 100
        Cull Front
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            // UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            // sampler2D _CameraDepthTexture;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 objpos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.objpos = v.vertex;
                return o;
            }
            

            fixed4 frag (v2f i) : SV_Target
            {

                float4 col = i.objpos;
                return col;
            }
            ENDCG
        }
        Tags { "RenderType"="Opaque"}
        GrabPass{"_GrabTex"}
        Cull back
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro :TEXCOORD1;
                float3 surf : TEXCOORD2;
                float3 objsurf : TEXCOORD3;
                float4 guv : TEXCOORD4;
                float3 normal :NORMAL;

                float3 worldPos : TEXCOORD5;
                float3 worldNormal : TEXCOORD6;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _GrabTex;

            float _WaterHeight;
            float _Fineness;
            float _WaveDiv;
            float _Frequency;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                if(false)
                {
                    o.ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
                    o.surf = v.vertex.xyz;
                    }else{
                    o.ro = _WorldSpaceCameraPos  - mul(unity_ObjectToWorld,float4(0,0,0,1)).xyz;
                    o.surf = mul(unity_ObjectToWorld,v.vertex) - mul(unity_ObjectToWorld,float4(0,0,0,1));
                }
                o.guv = ComputeGrabScreenPos(o.vertex);
                o.objsurf = v.vertex;
                o.normal = v.normal;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                return o;
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

            fixed2 random2(fixed2 st){
                st = fixed2( dot(st,fixed2(127.1,311.7)),
                dot(st,fixed2(269.5,183.3)) );
                return -1.0 + 2.0*frac(sin(st)*43758.5453123);
            }
            
            float perlinNoise(fixed2 st) 
            {
                fixed2 p = floor(st);
                fixed2 f = frac(st);
                fixed2 u = f*f*(3.0-2.0*f);

                float v00 = random2(p+fixed2(0,0));
                float v10 = random2(p+fixed2(1,0));
                float v01 = random2(p+fixed2(0,1));
                float v11 = random2(p+fixed2(1,1));

                return lerp( lerp( dot( v00, f - fixed2(0,0) ), dot( v10, f - fixed2(1,0) ), u.x ),
                lerp( dot( v01, f - fixed2(0,1) ), dot( v11, f - fixed2(1,1) ), u.x ), 
                u.y)+0.5f;
            }

            float3x3 RotMat(float3 axis, float angle)
            {
                // http://www.neilmendoza.com/glsl-rotation-about-an-arbitrary-axis/
                axis = normalize(axis);
                float s = sin(angle);
                float c = cos(angle);
                float oc = 1.0 - c;
                
                return float3x3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s, 
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s, 
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c          );
            }

            float c(float x, float f)
            {
                return x - (x - x * x) * -f;
            }

            float sea_octave(float2 uv, float choppy)
            {
                uv += perlinNoise(uv);        
                float2 wv = 1.0 - abs(sin(uv));
                float2 swv = abs(cos(uv));    
                wv = lerp(wv, swv, wv);
                return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
            }

            float wave(float3 p)
            {
                float SEA_TIME = (1. + _Time.y * .8); 
                //    float snoise = simplex3d(p);
                // 分かりやすさのために、指定されている値をコメントしました
                float freq = .16; // => 0.16
                float amp = .6; // => 0.6
                float choppy = 4.; // => 4.0

                // XZ平面による計算
                float2 uv = p.xz;

                float d, h = 0.0;    


                float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);
                // ITER_GEOMETRY = 3
                // ここで「フラクタルブラウン運動」によるノイズの計算を行っている
                for (int i = 0; i < 3; i++)
                {
                    // #define SEA_TIME (1.0 + iTime * SEA_SPEED)
                    // SEA_SPEED = 0.8
                    // 単純に、iTime（時間経過）によってUV値を微妙にずらしてアニメーションさせている
                    // iTimeのみを指定してもほぼ同じアニメーションになる
                    //
                    // SEA_TIMEのプラス分とマイナス分を足して振幅を大きくしている・・・？
                    d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);

                    h += d * amp;

                    // octave_m = mat2(1.6, 1.2, -1.2, 1.6);
                    // これは回転行列・・・？
                    // uv値を回転させている風。これをなくすと平坦な海になる
                    uv = mul(octave_m,uv);

                    // fbm関数として、振幅を0.2倍、周波数を2.0倍して次の計算を行う
                    freq *= 2.0;
                    amp *= 0.2;

                    // choppyを翻訳すると「波瀾」という意味
                    // これを小さくすると海が「おとなしく」なる
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return h;
            }

            float sdPlane( float3 p, float4 n )
            {
                // n must be normalized
                return dot(p,n.xyz) + n.w;
            }

            float map(float3 p)
            {
                float o = max(p.y,-p.y);
                o = p.y;
                // + (sin(p.x*13 + cos(_Time.y) ) * sin(p.z * 13 + sin(_Time.y) ))/10.
                o =  sdPlane(p,normalize(float4(0,0.7,0,0.1))) - _WaterHeight + sin(sin(_Time.y * _Frequency))/10.;
                o -= wave(p * _Fineness)/_WaveDiv;
                return o * .71;
            }

            float2 march(float3 ro,float3 rd,float maxLen)
            {
                // if(map(ro + rd ) < 0 ){return float2(0,1);}
                rd = normalize(rd);
                float depth = 0.;
                float negativedepth = 0.;
                for(int i = 0; i <23 ; i++)
                {
                    float3 pos = ro + rd * depth;
                    float d = map(pos);
                    
                    if(abs(d) < 1e-5)break;
                    depth += d;
                    if(depth > maxLen)return float2(-1,0);
                }
                return float2(depth,0);
            }

            float getDepth(float3 pos)
            {
                pos = mul(unity_WorldToObject,float4(pos,1.)).xyz;
                float4 sPos = UnityObjectToClipPos(float4(pos, 1.0));
                #if defined(SHADER_TARGET_GLSL)
                    return (sPos.z / sPos.w) * 0.5 + 0.5;
                #else 
                    return sPos.z / sPos.w;
                #endif 
            }

            float diffuse(float3 n, float3 l, float p)
            {
                return pow(dot(n, l) * 0.4 + 0.6, p);
            }

            float specular(float3 n, float3 l, float3 e, float s)
            {
                float nrm = (s + 8.0) / (UNITY_PI * 8.0);
                return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
            }

            float3 getSkyColor(float3 e)
            {
                e.y = max(e.y, 0.0);
                float r = pow(1.0 - e.y, 2.0);
                float g = 1.0 - e.y;
                float b = 0.6 + (1.0 - e.y) * 0.4;
                return float3(r, g, b);
            }

            float3 getSeaColor(float3 p, float3 n, float3 l, float3 eye, float3 dist)
            {
                float3 SEA_BASE = float3(0.,.12,.1);
                float3 SEA_WATER_COLOR = float3(.0,.8,1.);
                float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
                fresnel = pow(fresnel, 3.0) * 0.65;

                float3 reflected = getSkyColor(reflect(eye, n));    
                float3 refracted = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12; 

                float3 color = lerp(refracted, reflected, fresnel);

                float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
                color += SEA_WATER_COLOR * (p.y + _WaterHeight + sin(sin(_Time.y * _Frequency))/10.) * 0.18 * atten;

                color += float3(1,1,1) * specular(n, l, eye,60.0);

                return color;
            }

            float3 getInSeaColor(float3 ro,float3 light,float3 rd,float maxlen)
            {
                float3 origin = ro;
                float3 color = 0;

                float t = _Time.y;
                float up = max(0.,dot(light,rd));
                float down = max(0.,dot(-light,rd))*.5 + .5;

                up = lerp(1,up,.3);

                color.rgb += float3(0.,.06,.2) * lerp(0. ,1., up * perlinNoise(rd.yz) );
                color.rgb += down * float3(0.,.1,.2)  * (simplex3d(2*ro) * .3 + .7);
                color.rgb += pow(c(up,-.7),60) ;
                
                //color.rgb = smoothstep(float3(0.,0.,1.),float3(0.,.1,0.),.5);
                float3 rp = ro;
                for(int i = 0; i<8;i++)
                {
                    rp += rd * 0.07 * lerp(1,perlinNoise(rp.xz +t/30),.3) * float3(1,0.,1);
                    if(length(origin - rp) > maxlen)break;
                    float3 grd = rp;
                    float3 dir= float3(0.,1.,0.);
                    grd = mul(RotMat(float3(0.5,1.,0.),( (t +  16.) )/5),grd);
                    //grd *= dir;
                    grd.y = 1;
                    color +=max(0., (simplex3d(grd*1.1)/pow(2 + float(i*.4),2.) ) * pow( lerp(up*2.,.7,.4) ,2.)); 
                }
                color = clamp(color,0.,1.);
                // color = pow(color,.4545);
                return color;
            }

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

            fixed4 frag (v2f i) :SV_Target
            {

                float3 cd = -UNITY_MATRIX_V[2].xyz;
                float3 ro = i.ro;
                float3 rd = (i.surf - ro);
                //rd = (dot(cd,rd) < 0.)?normalize(rd):rd;
                
                float Dist = length( i.objsurf - tex2D(_GrabTex,i.guv.xy/i.guv.w).xyz );
                
                float2 depth = (map(ro + rd ) < 0 )?float2(-1,1):march(i.surf,rd,Dist);
                rd = normalize(rd);
                fixed4 col = depth.y;
                col.a = 1;
                
                float3 pos = depth.x * normalize(rd) + i.surf;
                
                if((depth.x < 0.) * (depth.y < 1.) > 0 )
                {
                    half3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                    half3 reflDir = reflect(-worldViewDir, i.worldNormal);
                    
                    half3 reflDir0 = boxProjection(reflDir, i.worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                    half3 reflDir1 = boxProjection(reflDir, i.worldPos, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
                    
                    half4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir0, 0);
                    refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);

                    // SpecCube1のサンプラはSpecCube0のものを使う
                    half4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflDir1, 0);
                    refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);

                    // unity_SpecCube0_BoxMin.w にブレンド率が入ってくる
                    return lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);
                }
                
                float2 e = float2(1e-4,0.);
                float3 N = -normalize(map(pos) - float3(map(pos + e.xyy),map(pos + e.yxy),map(pos + e.yyx)));
                
                float3 light = _WorldSpaceLightPos0;
                if(depth.y > 0 )
                {
                    float4 base = float4( getInSeaColor(i.surf,light,rd,Dist),1 ) ;
                    float fresnel = clamp(1.0 - dot(i.normal, -rd), 0.0, 1.0);
                    fresnel = pow(fresnel, 3.0) * 0.65;
                    //base.rgb += fresnel;

                    float dif = max(0.,dot(light,i.normal)) * .7 + .3;
                    //float up = max(0.,dot(i.normal,mul(unity_ObjectToWorld,float4(0.,1.,0.,1.)).xyz));
                    // float down = max(0.,dot(i.normal,mul(unity_ObjectToWorld,float4(0.,-1.,0.,1.)).xyz));
                    float spc = specular(i.normal,light,cd,60.);
                    //  base.rgb = base.rgb/100. + dif * float3(0.,.4,.2) + spc;
                    base.rgb = lerp(base.rgb,  ( dif * float3(.0,.6,.2)) * .1,.02);
                    return base; 
                }
                else if(depth.x > 0.)
                {
                    col.rgb = (N) ;

                    
                    float3 sky = getSkyColor(rd);
                    float3 sea = getSeaColor(pos, N, light, rd, length(pos - ro) );

                    // This is coefficient for smooth blending sky and sea with 
                    float t = pow(smoothstep(0.0, -0.05, rd.y), 0.3);
                    col.rgb = lerp(sky, sea, t);
                    // o.oDepth = getDepth(depth.x * normalize(rd) + ro);
                }

                return (col);
            }
            ENDCG
        }
    }
}
