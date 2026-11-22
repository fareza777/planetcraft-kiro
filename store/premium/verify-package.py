from pathlib import Path
import hashlib
import json
import subprocess
import zipfile
from io import BytesIO
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
QA = ROOT / "qa"
QA.mkdir(exist_ok=True)
STILLS = [1.43, 5.1, 9.08, 13.3, 17.62, 21.32, 24.55, 26.72, 30.88, 36.4]
TARGETS = {
    "wide": ("planetcraft-youtube-1920x1080.mp4", (1920, 1080), (480, 270), 2),
    "vertical": ("planetcraft-vertical-1080x1920.mp4", (1080, 1920), (270, 480), 5),
}


def run(command):
    return subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def check_image(path, size, mode):
    with Image.open(path) as photo:
        assert photo.size == size, (path.name, photo.size)
        assert photo.mode == mode, (path.name, photo.mode)
        photo.verify()
    assert path.stat().st_size <= (1024**2 if path.name=="icon-512.png" else 8*1024**2)
    return {"path": path.relative_to(ROOT).as_posix(), "size": list(size), "mode": mode, "sha256": checksum(path)}


def check_video(path, size, thumb, cols):
    args=["ffprobe","-v","error","-show_streams","-show_format","-of","json",str(path)]
    data=json.loads(run(args).stdout)
    vid, aud = (next(s for s in data["streams"] if s["codec_type"]==kind) for kind in ("video","audio"))
    assert (vid["width"],vid["height"]) == size, (path, vid)
    assert vid["codec_name"] == "h264" and vid["pix_fmt"]=="yuv420p" and vid["avg_frame_rate"]=="30/1"
    assert int(vid["nb_frames"]) == 1140 and abs(float(data["format"]["duration"])-38) <= .06
    assert aud["codec_name"]=="aac" and aud["channels"]==2
    run(["ffmpeg","-v","error","-xerror","-i",str(path),"-map","0:v","-map","0:a","-f","null","NUL"])
    sound=run(["ffmpeg","-hide_banner","-i",str(path),"-vn","-af","ebur128=peak=true","-f","null","NUL"]).stderr
    sound=sound.decode("utf-8", errors="replace").split("Summary:")[-1].strip()
    (QA/(path.stem+"-loudness.txt")).write_text(sound+"\n",encoding="utf-8")
    rows=(len(STILLS)+cols-1)//cols
    page=Image.new("RGB",(cols*(thumb[0]+14)+14,rows*(thumb[1]+34)+14),"#110e1d")
    d=ImageDraw.Draw(page)
    for i,t in enumerate(STILLS):
        args=["ffmpeg","-v","error","-ss",str(t),"-i",str(path),"-frames:v","1",
              "-vf",f"scale={thumb[0]}:{thumb[1]}","-c:v","mjpeg","-f","image2pipe","-"]
        value=run(args).stdout
        x=14+i%cols*(thumb[0]+14)
        y=14+i//cols*(thumb[1]+34)
        page.paste(Image.open(BytesIO(value)).convert("RGB"),(x,y))
        d.text((x,y+thumb[1]+7),f"{t:05.2f} s",fill="white")
    return page, {"path":path.name,"size":list(size),"fps":30,"frames":1140,"duration":38,
                  "video":"H.264","audio":"stereo AAC","bytes":path.stat().st_size,"sha256":checksum(path)}


def package(retain):
    out = ROOT / "planetcraft-assets-and-remotion.zip"
    with zipfile.ZipFile(out,"w",zipfile.ZIP_DEFLATED,compresslevel=5) as z:
        for f in sorted(retain):
            z.write(f,f.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(out) as z:
        assert z.testzip() is None
        assert len([n for n in z.namelist() if n.startswith("screenshots/") and n.endswith(".png")])==8
        assert "video/package-lock.json" in z.namelist()
        print(f"Archive passes CRC: {len(z.namelist())} files, {out.stat().st_size:,} bytes")


if __name__=="__main__":
    singles=[("icon-512.png",(512,512),"RGBA"),("icon-1024.png",(1024,1024),"RGBA"),
             ("feature-graphic-1024x500.png",(1024,500),"RGB")]
    store=sorted((ROOT/"screenshots").glob("*.png"))
    assert len(store)==8
    images=[check_image(ROOT/file,size,mode) for file,size,mode in singles]
    images += [check_image(file,(1920,1080),"RGB") for file in store]
    records=[]
    for name,(file,size,thumb,cols) in TARGETS.items():
        contact, info=check_video(ROOT/file,size,thumb,cols)
        contact.save(QA/f"{name}-scenes.jpg",quality=90)
        records.append(info)
        print(info)
    report = QA / "media-report.json"
    report.write_text(json.dumps({"images":images,"videos":records},indent=2)+"\n",encoding="utf-8")
    named=["README.md","APP-REVIEW.md","PROMPTS.md","PROJECT-LICENSE.txt","PROJECT-NOTICES.md",
           "preview-screenshots.jpg","make-score.py","build-assets.py"]
    files=[ROOT/n for n,_,_ in singles] + store + [ROOT/n for n in named] + [report]
    for folder in ("artwork","captures","test-logs","video/public","video/src"):
        files.extend(f for f in (ROOT/folder).iterdir() if f.is_file())
    files.extend(ROOT/"video"/name for name in ("package.json","package-lock.json","tsconfig.json"))
    package(files)


