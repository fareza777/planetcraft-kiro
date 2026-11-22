import React from 'react';
import {Audio} from '@remotion/media';
import {AbsoluteFill, Composition, Sequence, staticFile, useVideoConfig, registerRoot} from 'remotion';
import {Chapter, EndCard, Terraform, ice, lilac, mint, orange} from './scenes';
import './style.css';

const Trailer = () => {
  const {fps}=useVideoConfig();
  return <AbsoluteFill style={{background:'#100b1d',overflow:'hidden',fontFamily:'Outfit, sans-serif'}}>
    <Audio src={staticFile('original-score.mp3')} premountFor={fps}/>
    <Sequence name="Crash hook" from={0} durationInFrames={102} premountFor={fps}>
      <Chapter name="verdania" mode="bleed" kicker="Verdania" title={['The crash was','the easy part.']}
        support="Survive an alien world." tint={mint} from={19}/>
    </Sequence>
    <Sequence name="Mining laser" from={102} durationInFrames={123} premountFor={fps}>
      <Chapter name="mining" kicker="Mining laser" title={['Dig for','rare ore.']} tint={lilac} from={6}/>
    </Sequence>
    <Sequence name="Crafting" from={225} durationInFrames={105} premountFor={fps}>
      <Chapter name="crafting" mode="right" kicker="75 recipes" title={['Craft your','next move.']}
        support="Start with a Fabricator." tint={mint} from={8}/>
    </Sequence>
    <Sequence name="Colony automation" from={330} durationInFrames={135} premountFor={fps}>
      <Chapter name="colony" kicker="Colony automation" title={['Make the','base work.']}
        support="Power farms, smelters and drones." tint={orange} from={10}/>
    </Sequence>
    <Sequence name="Alien companions" from={465} durationInFrames={120} premountFor={fps}>
      <Chapter name="wildlife" mode="right" kicker="Alien wildlife" title={['Tame','the wild.']}
        support="Take a Mossback with you." tint={lilac} from={9}/>
    </Sequence>
    <Sequence name="Off-road rover" from={585} durationInFrames={120} premountFor={fps}>
      <Chapter name="rover" mode="bleed" kicker="Surface rover" title={['Go','off-road.']}
        support="Drive across alien terrain." tint={orange} from={13}/>
    </Sequence>
    <Sequence name="Launchpad" from={705} durationInFrames={57} premountFor={fps}>
      <Chapter name="ship" mode="right" kicker="Starship assembly" title={['Build','a starship.']}
        tint={ice} from={53}/>
    </Sequence>
    <Sequence name="Kryos landing" from={762} durationInFrames={90} premountFor={fps}>
      <Chapter name="kryos" mode="bleed" kicker="Kryos" title={['Jump to','six worlds.']} tint={ice} from={18}/>
    </Sequence>
    <Sequence name="Aridus terraforming" from={852} durationInFrames={168} premountFor={fps}>
      <Terraform/>
    </Sequence>
    <Sequence name="PlanetCraft and F7 Developer" from={1020} durationInFrames={120} premountFor={fps}>
      <EndCard/>
    </Sequence>
  </AbsoluteFill>;
};

const Root = () => <>
  <Composition id="PlanetCraftWide" component={Trailer} durationInFrames={1140} fps={30} width={1920} height={1080}/>
  <Composition id="PlanetCraftVertical" component={Trailer} durationInFrames={1140} fps={30} width={1080} height={1920}/>
</>;
registerRoot(Root);

