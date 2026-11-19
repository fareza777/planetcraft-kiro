"""Builds the PlanetCraft cinematic title intro and the F7 Developer brand splash.

Outputs (Godot Ogg Theora):
  art/intro/intro.ogv      title cinematic with English voice-over
  art/intro/f7_brand.ogv   F7 Developer 4 s ident, with its own sting

Sources:
  store/premium/artwork/verdania-key-art.png   title / end card art
  store/premium/planetcraft-assets-and-remotion.zip  captured gameplay clips + score
  F7 Brand splash (external, --brand)          brand MP4

Run: python tools/build_intro.py [--brand PATH]
Requires ffmpeg (libtheora, libvorbis), edge-tts, fontTools.
"""

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / ".work" / "intro"
MEDIA = WORK / "media"
SEG = WORK / "segments"
OUT = ROOT / "art" / "intro"
ZIP = ROOT / "store" / "premium" / "planetcraft-assets-and-remotion.zip"
BRAND_DEFAULT = Path(
    "G:/My Drive/F7 Developer - Content/F7 Brand/Splash Screen Video/App-Ready/"
    "f7_splash_landscape_1280x720_audio.mp4"
)

VOICE = "en-US-AndrewNeural"
W, H = 1280, 720
CINEMA_H = 536
BAR = (H - CINEMA_H) // 2
FPS = 24

LINES = [
    "Beyond the mapped stars, a world is waiting.",
    "Mine. Build. Survive the dark.",
    "Raise a colony that works while you sleep.",
    "Cross six alien worlds.",
    "Terraform the dead into the living.",
    "Survive. Build. Evolve.",
    "PlanetCraft: Galactic Survival. Your expedition begins.",
]


def run(cmd, quiet=True, cwd=None):
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    if p.returncode != 0:
        print(" ".join(str(c) for c in cmd))
        print(p.stderr[-4000:])
        raise SystemExit(1)
    if not quiet and p.stderr.strip():
        print(p.stderr)
    return p


def probe_duration(path):
    p = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1", str(path),
    ])
    return float(p.stdout.strip())


def extract_sources():
    MEDIA.mkdir(parents=True, exist_ok=True)
    keyart = ROOT / "store" / "premium" / "artwork" / "verdania-key-art.png"
    shutil.copy2(keyart, MEDIA / "keyart.png")
    with zipfile.ZipFile(ZIP) as z:
        for name in z.namelist():
            if name.startswith("video/public/") and name.endswith((".mp4", ".mp3", ".woff2")):
                z.extract(name, WORK / "zip")
                src = WORK / "zip" / name
                shutil.copy2(src, MEDIA / Path(name).name)


def make_fonts():
    from fontTools.ttLib import TTFont

    for name in ("Outfit", "DMSans"):
        src = MEDIA / (name + ".woff2")
        dst = MEDIA / (name + ".ttf")
        if not dst.exists():
            f = TTFont(src)
            f.flavor = None
            f.save(dst)


def make_gradient():
    from PIL import Image

    dst = MEDIA / "gradient.png"
    if dst.exists():
        return
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            a = 0
            if y < 320:
                a = max(a, int(150 * (1 - y / 320) ** 1.9))
            if y > 430:
                a = max(a, int(150 * ((y - 430) / 290) ** 1.9))
            if x < 300:
                a = max(a, int(95 * (1 - x / 300) ** 1.9))
            if a:
                px[x, y] = (0, 0, 0, min(a, 165))
    img.save(dst)


def synth_vo(force=False):
    import time

    vo_dir = WORK / "vo"
    vo_dir.mkdir(parents=True, exist_ok=True)
    out = []
    for i, line in enumerate(LINES, 1):
        mp3 = vo_dir / ("vo%02d.mp3" % i)
        if force or not mp3.exists() or mp3.stat().st_size < 4000:
            ok = False
            for attempt in range(5):
                p = subprocess.run([
                    sys.executable, "-m", "edge_tts",
                    "--voice", VOICE, "--rate=-6%", "--pitch=-2Hz",
                    "--text", line, "--write-media", str(mp3),
                ], capture_output=True, text=True)
                if p.returncode == 0 and mp3.exists() and mp3.stat().st_size > 4000:
                    ok = True
                    break
                print(f"  vo{i} attempt {attempt + 1} failed; retrying")
                time.sleep(1.5 + attempt)
            if not ok:
                raise SystemExit(f"edge-tts failed for line {i}: {line}")
        out.append(mp3)
        time.sleep(0.4)
    return out


def plan(vo):
    d = [probe_duration(p) for p in vo]
    lead, gap, cut = 0.9, 0.3, 0.15
    # title holds through line 1, then an instrumental establishing shot
    title = lead + d[0] + gap
    verdania = 1.8
    segs = []

    def add(name, dur):
        segs.append([name, dur])

    add("title", title)
    add("verdania", verdania)
    # each following shot: vocal line + lead-in and gap
    for i, name in zip(range(1, 7), ["mining", "colony", "rover", "terraformed", "wildlife", "end"]):
        add(name, cut + d[i] + gap if name != "end" else cut + d[i] + 1.1)

    starts, t = {}, 0.0
    for name, dur in segs:
        starts[name] = t
        t += dur
    total = t
    line_at = [lead]
    line_at += [starts[n] + cut for n in
                ["mining", "colony", "rover", "terraformed", "wildlife", "end"]]
    return {"durations": d, "segments": segs, "starts": starts,
            "lines": line_at, "total": total}


def render_segments(plan):
    SEG.mkdir(parents=True, exist_ok=True)
    keyart = MEDIA / "keyart.png"
    sources = {
        "verdania": MEDIA / "verdania.mp4",
        "mining": MEDIA / "mining.mp4",
        "colony": MEDIA / "colony.mp4",
        "rover": MEDIA / "rover.mp4",
        "terraformed": MEDIA / "terraformed.mp4",
        "wildlife": MEDIA / "wildlife.mp4",
    }
    for idx, (name, dur) in enumerate(plan["segments"]):
        out = SEG / ("%02d_%s.mp4" % (idx, name))
        frames = max(2, round(dur * FPS))
        grade = "eq=contrast=1.05:saturation=1.07:brightness=-0.012,vignette=angle=PI/4.5"
        dip = f"fade=t=in:st=0:d=0.3,fade=t=out:st={max(0.0, dur - 0.3):.3f}:d=0.3"
        if name in ("title", "end"):
            # slow push-in on the cover art, keeping the left key-art gradient clear for type
            vf = (
                f"scale=2560:1440:flags=lanczos,"
                f"zoompan=z='1+0.05*on/{frames}':x='iw*0.5-(iw/zoom)/2':"
                f"y='ih*0.5-(ih/zoom)/2':d={frames}:s={W}x{CINEMA_H}:fps={FPS},"
                f"{grade},{dip},format=yuv420p"
            )
            run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-t", f"{dur:.3f}",
                 "-i", str(keyart), "-vf", vf, "-frames:v", str(frames), "-an",
                 "-c:v", "libx264", "-crf", "16", "-preset", "medium", str(out)])
        else:
            inc = 0.00055 if name != "rover" else 0.0004
            vf = (
                f"scale=2560:1440:flags=lanczos,"
                f"zoompan=z='min(zoom+{inc},1.14)':x='iw/2-(iw/zoom)/2':"
                f"y='ih/2-(ih/zoom)/2':d=1:s={W}x{CINEMA_H}:fps={FPS},"
                f"{grade},{dip},format=yuv420p"
            )
            run(["ffmpeg", "-v", "error", "-y", "-t", f"{dur:.3f}",
                 "-i", str(sources[name]), "-vf", vf, "-frames:v", str(frames), "-an",
                 "-c:v", "libx264", "-crf", "16", "-preset", "medium", str(out)])


def ass_time(t):
    h = int(t // 3600)
    m = int(t % 3600 // 60)
    s = t % 60
    return f"{h}:{m:02d}:{s:05.2f}"


def write_subs(plan):
    head = """[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,DM Sans,25,&H00F2F5FF,&H00FFFFFF,&HB4000000,&H00000000,0,0,0,0,100,100,0.6,0,1,2,0,2,80,80,30,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, Effect, Text
"""
    rows = []
    for i, (text, t0) in enumerate(zip(LINES, plan["lines"])):
        t1 = t0 + plan["durations"][i] + 0.35
        rows.append(f"Dialogue: 0,{ass_time(t0)},{ass_time(t1)},Cap,,0,0,,{text}")
    p = WORK / "intro.ass"
    p.write_text(head + "\n".join(rows) + "\n", encoding="utf-8")
    return p


def drawtext(font, text, size, color, x, y, t0, t1, alpha=1.0):
    a = f"{alpha:.2f}"
    return (
        f"drawtext=fontfile='{font}':text='{text}':fontsize={size}:fontcolor={color}@{a}:"
        f"x={x}:y={y}:enable='between(t,{t0:.2f},{t1:.2f})':"
        f"shadowcolor=black@0.55:shadowx=2:shadowy=3"
    )


def render_picture(plan, subs):
    inputs, filters = [], []
    for idx, (name, dur) in enumerate(plan["segments"]):
        inputs += ["-i", str(SEG / ("%02d_%s.mp4" % (idx, name)))]
    n = len(plan["segments"])
    cat_in = "".join(f"[{i}:v]" for i in range(n))
    filters.append(f"{cat_in}concat=n={n}:v=1:a=0[cat]")
    last = "[cat]"
    title_end = plan["starts"]["verdania"] - 0.2
    end_t = plan["starts"]["end"] + 0.25
    total = plan["total"]
    outfit = "media/Outfit.ttf"
    dmsans = "media/DMSans.ttf"
    texts = [
        drawtext(dmsans, "AN OFFLINE VOXEL SANDBOX", 19, "0xFFC24D", 92, 268, 1.1, title_end, 0.9),
        drawtext(outfit, "P L A N E T C R A F T", 68, "0xF4F7FF", 86, 300, 0.8, title_end),
        drawtext(dmsans, "G A L A C T I C   S U R V I V A L", 26, "0x7FE7FF", 92, 402, 1.15, title_end, 0.95),
        f"drawbox=x=92:y=386:w=560:h=2:color=0xFFC24D@0.75:t=fill:enable='between(t,1.2,{title_end:.2f})'",
        drawtext(dmsans, "S U R V I V E   ·   B U I L D   ·   E V O L V E", 22, "0xFFC24D", 92, 258, end_t, total),
        drawtext(outfit, "P L A N E T C R A F T", 62, "0xF4F7FF", 88, 292, end_t + 0.1, total),
        drawtext(dmsans, "G A L A C T I C   S U R V I V A L", 25, "0x7FE7FF", 92, 372, end_t + 0.2, total),
    ]
    gradient = MEDIA / "gradient.png"
    filters.append(
        f"{last}pad={W}:{H}:0:{BAR}:black[g0];"
        f"[g0][{n}:v]overlay=0:0[g1];"
        f"[g1]"
        + ",".join(texts)
        + ",ass=intro.ass[vout]"
    )
    inputs += ["-loop", "1", "-t", f"{plan['total']:.3f}", "-i", str(gradient)]
    out = WORK / "picture.mp4"
    cmd = ["ffmpeg", "-v", "error", "-y"] + inputs + [
        "-filter_complex", ";".join(filters), "-map", "[vout]",
        "-t", f"{plan['total']:.3f}",
        "-r", str(FPS), "-c:v", "libx264", "-crf", "16", "-preset", "medium",
        "-pix_fmt", "yuv420p", str(out),
    ]
    run(cmd, cwd=WORK)
    return out


def render_audio(plan, vo):
    total = plan["total"]
    inputs = ["-i", str(MEDIA / "original-score.mp3")]
    for p in vo:
        inputs += ["-i", str(p)]
    parts = [
        f"[0:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,aresample=48000,"
        f"pan=stereo|c0=c0|c1=c0,afade=t=in:st=0:d=1.4,"
        f"afade=t=out:st={total - 1.8:.3f}:d=1.8,volume=0.85[music]"
    ]
    labels = []
    for i, (p, t0) in enumerate(zip(vo, plan["lines"])):
        ms = round(t0 * 1000)
        parts.append(
            f"[{i + 1}:a]aresample=48000,pan=stereo|c0=c0|c1=c0,"
            f"adelay={ms}|{ms}[v{i}]"
        )
        labels.append(f"[v{i}]")
    parts.append("".join(labels) + f"amix=inputs={len(vo)}:normalize=0[vo]")
    parts.append("[vo]asplit=2[voice][side0]")
    parts.append(f"[side0]apad=whole_dur={total:.3f}[side]")
    parts.append("[music][side]sidechaincompress=threshold=0.025:ratio=6:attack=120:release=900[ducked]")
    parts.append(
        "[ducked][voice]amix=inputs=2:normalize=0:weights=0.62 1.0,"
        "alimiter=limit=0.95,loudnorm=I=-16:TP=-1.5:LRA=9[out]"
    )
    out = WORK / "mix.wav"
    run(["ffmpeg", "-v", "error", "-y"] + inputs +
        ["-filter_complex", ";".join(parts), "-map", "[out]",
         "-t", f"{total:.3f}", "-ar", "48000", "-ac", "2", str(out)])
    return out


def mux(plan, picture, mix):
    review = WORK / "intro_review.mp4"
    run(["ffmpeg", "-v", "error", "-y", "-i", str(picture), "-i", str(mix),
         "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest",
         "-movflags", "+faststart", str(review)])
    OUT.mkdir(parents=True, exist_ok=True)
    ogv = OUT / "intro.ogv"
    run(["ffmpeg", "-v", "error", "-y", "-i", str(picture), "-i", str(mix),
         "-c:v", "libtheora", "-q:v", "5", "-c:a", "libvorbis", "-q:a", "4",
         "-shortest", str(ogv)])
    return review, ogv


def brand(brand_path):
    if not brand_path.exists():
        raise SystemExit(f"brand video not found: {brand_path}")
    OUT.mkdir(parents=True, exist_ok=True)
    ogv = OUT / "f7_brand.ogv"
    run(["ffmpeg", "-v", "error", "-y", "-i", str(brand_path),
         "-vf", f"scale={W}:{H}:flags=lanczos,fps=30,format=yuv420p",
         "-af", "loudnorm=I=-16:TP=-1.5:LRA=9",
         "-c:v", "libtheora", "-q:v", "7", "-c:a", "libvorbis", "-q:a", "4",
         str(ogv)])
    return ogv


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--brand", default=str(BRAND_DEFAULT))
    ap.add_argument("--skip-vo", action="store_true")
    args = ap.parse_args()
    extract_sources()
    make_fonts()
    make_gradient()
    vo = synth_vo()
    if args.skip_vo and (WORK / "mix.wav").exists():
        pass
    p = plan(vo)
    print(json.dumps({k: (v if k not in ("durations", "lines") else [round(x, 2) for x in v])
                      for k, v in p.items()}, indent=2, default=str))
    render_segments(p)
    subs = write_subs(p)
    picture = render_picture(p, subs)
    mix = render_audio(p, vo)
    review, ogv = mux(p, picture, mix)
    brand_ogv = brand(Path(args.brand))
    for f in (review, ogv, brand_ogv):
        print(f"{f}  {f.stat().st_size / 1e6:.2f} MB  {probe_duration(f):.2f} s")


if __name__ == "__main__":
    main()
