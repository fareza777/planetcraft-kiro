import React, {type CSSProperties} from 'react';
import {Video} from '@remotion/media';
import {
  AbsoluteFill, Easing, Img, interpolate, Sequence, staticFile,
  useCurrentFrame, useVideoConfig,
} from 'remotion';

export const mint = '#80ffe6';
export const orange = '#ffc08b';
export const lilac = '#e9c4ff';
export const ice = '#b9e8ff';
const ink = '#100b1d';
const ivory = '#fff8ee';

const easing = Easing.bezier(.16, 1, .3, 1);
const enter = (frame: number, start: number, end: number) =>
  interpolate(frame, [start, end], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing,
  });
const media = (name: string) => staticFile(name);
const headlineFont = '"Outfit", sans-serif';
const imageStyle: CSSProperties = {width:'100%', height:'100%', objectFit:'cover'};

type FootageProps = {
  name: string;
  from?: number;
  fit?: 'cover' | 'contain';
};

export const Footage = ({name, from = 0, fit = 'cover'}: FootageProps) => {
  const {fps} = useVideoConfig();
  return <Video src={media(name + '.mp4')} trimBefore={from} muted premountFor={fps}
    style={{...imageStyle, objectFit:fit}}/>;
};

type CopyProps = {
  title: readonly string[];
  kicker?: string;
  support?: string;
  tint: string;
  size: number;
};

const Copy = ({title, kicker, support, tint, size}: CopyProps) => {
  const f = useCurrentFrame();
  const accent = enter(f,0,16);
  return <div style={{fontFamily:headlineFont, color:ivory}}>
    {kicker && <div style={{display:'flex',alignItems:'center',gap:18,color:tint,
      fontSize:24,fontWeight:650,letterSpacing:5, textTransform:'uppercase',marginBottom:24,
      opacity:accent,transform:'translateY('+20*(1-accent)+'px)'}}>
      <i style={{width:32,height:4,background:tint}}/>{kicker}
    </div>}
    {title.map((line,i)=>{
      const p=enter(f, 2+i*3, 15+i*4);
      return <div key={line} style={{fontSize:size, fontWeight:900, lineHeight:.91,
        color:i===title.length-1 && i>0?tint:ivory, letterSpacing:'-.061em',
        opacity:p, transform:'translateY('+36*(1-p)+'px)',whiteSpace:'nowrap'}}>
        {line}
      </div>;
    })}
    {support && <div style={{fontFamily:'"DM Sans", sans-serif',fontSize:34,
      fontWeight:550,letterSpacing:'-.025em',lineHeight:1.2,marginTop:28,
      color:'#f6e9f3', opacity:enter(f,12,29)}}>
      {support}
    </div>}
  </div>;
};

const Grain = ({tint}: {tint:string}) => {
  const f=useCurrentFrame();
  return <AbsoluteFill style={{pointerEvents:'none',overflow:'hidden'}}>
    <AbsoluteFill style={{opacity:.16,
      backgroundImage:'linear-gradient(#b9abc134 1px, transparent 1px),linear-gradient(90deg,#b9abc134 1px,transparent 1px)',
      backgroundSize:'64px 64px', transform:'translateX(-'+(f%64)*.35+'px)'}}/>
    {Array.from({length:18},(_,i)=>{
      const left=(i*319+91)%1680+100;
      const top=(i*521+157)%1040+14;
      const size=3+i%4*2;
      return <div key={i} style={{position:'absolute',left,top,background:tint,
        opacity:(.28+.15*Math.sin(i+f/18))*(i%3===0?1:.45),
        width:size,height:size,transform:'translateY(-'+f*(.09+i%4*.05)+'px)'}}/>;
    })}
  </AbsoluteFill>;
};

const Corners = ({tint}: {tint:string}) =>
  <AbsoluteFill style={{inset:-11, width:'auto',height:'auto',pointerEvents:'none'}}>
    {['top-left','top-right','bottom-left','bottom-right'].map((corner)=>{
      const [vertical,horizontal] = corner.split('-');
      return <i key={corner} style={{position:'absolute',[vertical]:0,[horizontal]:0,
        width:28,height:28, ['border-'+vertical]:undefined,
        borderTop:vertical==='top'?'3px solid '+tint:undefined,
        borderBottom:vertical==='bottom'?'3px solid '+tint:undefined,
        borderLeft:horizontal==='left'?'3px solid '+tint:undefined,
        borderRight:horizontal==='right'?'3px solid '+tint:undefined}}/>;
    })}
  </AbsoluteFill>;

const Flash = ({tint}: {tint:string}) => {
  const f=useCurrentFrame();
  const p=enter(f,0,11);
  return <AbsoluteFill style={{background:tint,opacity:(1-p)*.22,pointerEvents:'none'}}/>;
};

const Backdrop = ({name,tint}: {name:string;tint:string}) =>
  <AbsoluteFill style={{background:ink,overflow:'hidden'}}>
    <AbsoluteFill style={{opacity:.28,filter:'blur(35px)',transform:'scale(1.18)'}}>
      <Img src={media(name + '.png')} style={imageStyle}/>
    </AbsoluteFill>
    <AbsoluteFill style={{background:'linear-gradient(140deg,#150d2833,#0a0715f2 88%)'}}/>
    <Grain tint={tint}/>
  </AbsoluteFill>;

type ChapterProps = {
  name: string;
  title: readonly string[];
  kicker: string;
  support?: string;
  tint: string;
  mode?: 'bleed'|'frame'|'right';
  from?: number;
};

export const Chapter = ({name,title,kicker,support,tint,mode='frame',from=0}:ChapterProps) => {
  const f=useCurrentFrame();
  const {width,height}=useVideoConfig();
  const tall=height>width;
  const p=enter(f,0,18);
  if (mode==='bleed' && !tall) {
    return <AbsoluteFill style={{background:ink}}>
      <AbsoluteFill style={{transform:'scale(1.015)'}}><Footage name={name} from={from}/></AbsoluteFill>
      <AbsoluteFill style={{background:'linear-gradient(90deg,#120a24ec 0%,#180f29b2 24%,#180f2900 74%)'}}/>
      <div style={{position:'absolute',left:95,bottom:157}}>
        <Copy title={title} kicker={kicker} support={support} tint={tint} size={140}/>
      </div>
      <Flash tint={tint}/>
    </AbsoluteFill>;
  }
  if (tall) {
    const hero=mode==='bleed';
    return <AbsoluteFill style={{background:ink}}>
      <Backdrop name={name} tint={tint}/>
      <div style={{position:'absolute',inset:'192px 0 auto 0',height:720,overflow:'hidden',
        clipPath:'polygon(0 10%,100% 0,100% 87%,0 100%)',opacity:hero?.72:.42}}>
        <Img src={media(name+'.png')} style={{...imageStyle,objectPosition:'50% 49%',transform:'scale('+ (1.035+f*.00042)+')'}}/>
      </div>
      <div style={{position:'absolute',top:hero?285:237,left:90,right:72,textShadow:'0 6px 35px #0d081b'}}>
        <Copy title={title} kicker={kicker} tint={tint} size={hero?129:124}/>
      </div>
      <div style={{position:'absolute',top:hero?794:765,left:73,width:934,height:525,
        background:ink,boxShadow:'0 30px 100px #100717bb',
        border:'2px solid '+tint,transform:'translateY('+31*(1-p)+'px)',opacity:p}}>
        <Footage name={name} from={from}/>
        <Corners tint={tint}/>
      </div>
      {support && <div style={{position:'absolute',top:hero?1374:1345,left:93,
        right:81,fontFamily:'"DM Sans", sans-serif',fontWeight:600,color:ivory,
        letterSpacing:'-.025em',fontSize:52,lineHeight:1.14,opacity:enter(f,12,30)}}>
        {support}
      </div>}
      <div style={{position:'absolute',left:89,top:1573,width:104,height:4,background:tint,opacity:p}}/>
      <Flash tint={tint}/>
    </AbsoluteFill>;
  }
  const right=mode==='right';
  return <AbsoluteFill style={{background:ink}}>
    <Backdrop name={name} tint={tint}/>
    <div style={{position:'absolute',top:204,left:right?94:627,width:right?1136:1200,
      height:right?639:675,background:ink,border:'2px solid '+tint,boxShadow:'0 30px 95px #0b0717bb',
      transform:'translateX('+ (right?-1:1)*46*(1-p)+'px)',opacity:p}}>
      <Footage name={name} from={from}/>
      <Corners tint={tint}/>
    </div>
    <div style={{position:'absolute',left:right?1310:91,top:0,bottom:0,width:right?525:484,
      display:'flex',alignItems:'center',textShadow:'0 7px 38px #0b0718'}}>
      <Copy title={title} kicker={kicker} support={support} tint={tint} size={102}/>
    </div>
    <Flash tint={tint}/>
  </AbsoluteFill>;
};

export const Terraform = () => {
  const f=useCurrentFrame();
  const {width,height,fps}=useVideoConfig();
  const tall=height>width;
  const split=enter(f,16,61);
  return <AbsoluteFill style={{background:ink}}>
    <Backdrop name="terraform-after" tint={mint}/>
    <div style={{position:'absolute',left:tall?77:627,top:tall?748:203,width:tall?926:1200,height:tall?520:675,
      border:'2px solid '+mint,boxShadow:'0 28px 100px #000a',overflow:'hidden'}}>
      <Sequence from={0} durationInFrames={70} premountFor={fps}>
        <Img src={media('terraform-before.png')} style={imageStyle}/>
        <div style={{position:'absolute',inset:0,
          clipPath:'polygon('+((1-split)*100)+'% 0,100% 0,100% 100%,'+((1-split)*100-9)+'% 100%)'}}>
          <Img src={media('terraform-after.png')} style={imageStyle}/>
        </div>
        {f>=16 && f<60 && <div style={{position:'absolute',top:-45,bottom:-45,left:((1-split)*100-4.5)+'%',
          width:5,background:mint,boxShadow:'0 0 25px #a3fff0',transform:'skewX(-9deg)'}}/>}
      </Sequence>
      <Sequence from={70} durationInFrames={98} premountFor={fps}>
        <Footage name="terraformed" from={51}/>
      </Sequence>
      <div style={{position:'absolute',bottom:26,left:26,background:'#151326ef',color:f<43?orange:mint,
        padding:'12px 18px',borderRadius:5,fontFamily:headlineFont,fontWeight:700,fontSize:23,
        textTransform:'uppercase',letterSpacing:3}}>
        {f<43?'Barren Aridus':'After terraforming'}
      </div>
    </div>
    <div style={{position:'absolute',left:tall?87:91,top:tall?256:338}}>
      <Copy kicker="Planet evolution" title={tall?['Give a planet','life.']:['Give a','planet life.']}
        tint={mint} size={tall?126:100}/>
    </div>
    {tall && <div style={{position:'absolute',left:89,right:87,top:1345,
      fontSize:50,fontWeight:550,color:ivory,letterSpacing:'-.035em',
      opacity:enter(f,16,34)}}>Build an atmosphere. Bring water. Seed life.</div>}
    <Flash tint={mint}/>
  </AbsoluteFill>;
};

export const EndCard = () => {
  const f=useCurrentFrame();
  const {width,height}=useVideoConfig();
  const tall=height>width;
  const p=enter(f,0,19);
  return <AbsoluteFill style={{background:ink,overflow:'hidden'}}>
    <AbsoluteFill style={{transform:'scale('+ (1.025+f*.00035)+')'}}>
      <Img src={media('verdania-key-art.png')} style={{...imageStyle,objectPosition:tall?'69% center':'55% center'}}/>
    </AbsoluteFill>
    <AbsoluteFill style={{background:tall
      ?'linear-gradient(180deg,#140b2a66 0%,#140b2a11 26%,#140b2a72 46%,#10081ff7 80%)'
      :'linear-gradient(90deg,#11091ff7,#11091fa8 36%,#11091f00 73%)'}}/>
    <Grain tint={orange}/>
    <div style={{position:'absolute',left:tall?86:96,top:tall?1014:352,
      transform:'translateY('+33*(1-p)+'px)',opacity:p,color:ivory,fontFamily:headlineFont}}>
      <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:28}}>
        <i style={{width:54,height:5,background:mint}}/><i style={{width:18,height:5,background:orange}}/>
      </div>
      <div style={{fontWeight:900,fontSize:tall?130:148,letterSpacing:'-.06em',lineHeight:1}}>PlanetCraft</div>
      <div style={{fontWeight:700,fontSize:tall?32:38,letterSpacing:8,textTransform:'uppercase',color:orange,marginTop:13}}>
        Galactic Survival
      </div>
      <div style={{fontFamily:'"DM Sans", sans-serif',fontSize:tall?42:38,marginTop:27,opacity:enter(f,12,25)}}>
        An offline voxel survival sandbox
      </div>
      <div style={{display:'flex',alignItems:'center',gap:17,marginTop:tall?84:75,opacity:enter(f,23,41),
        fontSize:tall?28:27,fontWeight:550,letterSpacing:1.3,color:'#efdeed'}}>
        <div style={{display:'grid',placeItems:'center',width:49,height:49,border:'1px solid #f5c8ac77',color:orange,
          fontSize:22,fontWeight:800}}>F7</div>A game by F7 Developer
      </div>
    </div>
    <Flash tint={orange}/>
  </AbsoluteFill>;
};

