from io import BytesIO
from pathlib import Path
import random
import sys

import numpy as np
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "captures"
ART = ROOT / "artwork"
VIDEO = ROOT / "video" / "public"
OUT = ROOT / "screenshots"
W, H = 1920, 1080
INK = "#100c20"
WHITE = "#fff7ee"
MINT = "#76ffe2"
ORANGE = "#ffc08c"
LILAC = "#e0b7ff"
ICE = "#b2e5ff"
font_files = {}


def font(weight, size):
    if weight not in font_files:
        face = TTFont(VIDEO / "Outfit.woff2")
        if "fvar" in face:
            face = instantiateVariableFont(face, {"wght": weight}, inplace=True)
        face.flavor = None
        buf = BytesIO()
        face.save(buf)
        font_files[weight] = buf.getvalue()
    return ImageFont.truetype(BytesIO(font_files[weight]), size)


def image(name):
    return Image.open(SRC / f"{name}.png").convert("RGB")


def fit(img, size, at=(0.5, 0.5)):
    return ImageOps.fit(img, size, method=Image.Resampling.LANCZOS, centering=at)


def gradient(size, color, top=0.0, bottom=0.0, power=1.0):
    scale = np.linspace(0, 1, size[1], dtype=np.float32)
    alpha = np.rint(255 * (top + (bottom - top) * scale ** power)).astype(np.uint8)
    data = np.empty((size[1], size[0], 4), dtype=np.uint8)
    data[:, :, :3] = color
    data[:, :, 3] = alpha[:, None]
    return Image.fromarray(data)


def background(start, end, glow=(0.7, 0.45), grid=True):
    yy, xx = np.mgrid[:H, :W]
    r = np.clip(1 - np.hypot((xx / W - glow[0]) * .93, (yy / H - glow[1]) * 1.25), 0, 1) ** 2
    data = np.array(start) * (1 - r[:, :, None]) + np.array(end) * r[:, :, None]
    art = Image.fromarray(np.uint8(data)).convert("RGBA")
    if grid:
        overlay = Image.new("RGBA", art.size)
        d = ImageDraw.Draw(overlay)
        for x in range(48, W, 68):
            d.line((x, 0, x, H), fill=(211, 197, 255, 17))
        for y in range(26, H, 68):
            d.line((0, y, W, y), fill=(211, 197, 255, 17))
        art.alpha_composite(overlay)
    return art


def label(d, xy, s, color=MINT, size=25):
    x, y = xy
    for char in s.upper():
        d.text((x, y), char, font=font(700, size), fill=color, anchor="lt")
        x += d.textlength(char, font=font(700, size)) + 3


def headline(d, xy, lines, color=WHITE, accent=None, size=143, gap=.79):
    x, y = xy
    for idx, line in enumerate(lines):
        d.text((x, y + idx * size * gap), line, font=font(900, size),
               anchor="lt", fill=accent if idx > 0 and accent else color,
               stroke_width=1)
    return round(y + (len(lines) - 1) * size * gap + size)


def body(d, xy, s, color=WHITE, size=36):
    d.text(xy, s, font=font(550, size), anchor="lt", fill=color)


def clipped(base, img, box, polygon, at=(.5, .5)):
    left, top, right, bottom = box
    plate = fit(img, (right-left, bottom-top), at)
    local = [(x-left, y-top) for x, y in polygon]
    mask = Image.new("L", plate.size)
    ImageDraw.Draw(mask).polygon(local, fill=255)
    base.paste(plate, (left, top), mask)


def frame(base, img, xy, width, stroke, rotate=0, radius=16):
    height = round(width * img.height / img.width)
    plate = Image.new("RGBA", (width+12, height+12))
    d = ImageDraw.Draw(plate)
    d.rounded_rectangle((0, 0, plate.width-1, plate.height-1), radius=radius, fill=stroke)
    mask = Image.new("L", (width, height))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width-1, height-1), radius=radius-3, fill=255)
    plate.paste(img.resize((width,height),Image.Resampling.LANCZOS), (6,6), mask)
    if rotate:
        plate = plate.rotate(rotate, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(plate, xy)


def marker(d, x, y, color, size=20):
    d.polygon([(x,y-size), (x+size,y), (x,y+size), (x-size,y)], fill=color)


def pixels(d, area, color, seed, count=16):
    rng = random.Random(seed)
    for _ in range(count):
        x = rng.randrange(area[0], area[2])
        y = rng.randrange(area[1], area[3])
        s = rng.choice([4,6,8,13])
        d.rectangle((x,y,x+s,y+s), fill=color)


def save(img, name):
    img.convert("RGB").save(OUT / f"{name}.png", optimize=True)


def branding():
    icon = Image.open(ART / "icon-art.png").convert("RGBA")
    for dim in (512, 1024):
        fit(icon, (dim, dim)).save(ROOT / f"icon-{dim}.png", optimize=True)
    hero = fit(Image.open(ART / "verdania-key-art.png").convert("RGB"), (1024, 500), (.59, .5)).convert("RGBA")
    black = gradient((500,1024), (11,5,22), 0.83, 0, 0.66).transpose(Image.Transpose.ROTATE_90)
    hero.alpha_composite(black)
    d = ImageDraw.Draw(hero)
    d.line((66,165,119,165), fill=MINT, width=4)
    d.line((126,165,142,165), fill=ORANGE, width=4)
    d.text((63,204),"PlanetCraft",font=font(900,81),anchor="lt",fill=WHITE,stroke_width=1)
    label(d,(68,292),"Galactic Survival",ORANGE,22)
    hero.convert("RGB").save(ROOT / "feature-graphic-1024x500.png", optimize=True)


def survival():
    im = fit(image("verdania"), (W,H)).convert("RGBA")
    im.alpha_composite(gradient((W,H), (13,8,26), 0.0, 0.94, 2.5))
    d = ImageDraw.Draw(im)
    d.rectangle((75,685,135,693),fill=MINT)
    label(d,(76,716),"PlanetCraft",MINT,28)
    headline(d,(73,763),["Crash. Adapt. Survive."],size=134)
    body(d,(83,936),"Explore an offline voxel sandbox.",WHITE,43)
    save(im,"01-crash-adapt-survive")


def mining():
    im = background((13,11,26),(56,34,83),(.27,.44))
    d = ImageDraw.Draw(im)
    d.polygon([(958,0),(1920,0),(1920,1080),(660,1080)], fill="#43286b")
    d.line([(1021,-10),(715,1090)], fill=LILAC, width=4)
    frame(im,image("mining"),(746,187),1052,LILAC,-5)
    d = ImageDraw.Draw(im)
    label(d,(76,181),"Mining laser",LILAC)
    headline(d,(69,242),["Dig into","alien","worlds."],accent=LILAC,size=151)
    body(d,(80,709),"Break blocks. Gather rare ore.",WHITE,37)
    d.line((80,793,416,793),fill="#a185bb",width=2)
    pixels(d,(77,855,588,962),"#674b89",2,20)
    save(im,"02-dig-into-alien-worlds")


def crafting():
    im = background((7,19,24),(22,66,62),(.46,.51))
    d = ImageDraw.Draw(im)
    d.polygon([(60,337),(1842,270),(1780,1063),(106,1063)],fill="#1c534e")
    frame(im,image("crafting"),(378,271),1371,MINT,0,13)
    d = ImageDraw.Draw(im)
    headline(d,(69,70),["Craft what keeps you alive."],size=126)
    body(d,(81,216),"Build gear and stations with 75 recipes.",MINT,42)
    d.line([(81,424),(235,424),(235,711),(330,711)],fill="#579e96",width=3)
    marker(d,235,424,MINT,11)
    marker(d,235,711,MINT,11)
    pixels(d,(83,441,197,1010),"#4f8983",11,26)
    save(im,"03-craft-what-keeps-you-alive")


def colony():
    im = background((18,12,23),(81,39,53),(.18,.44),False)
    d = ImageDraw.Draw(im)
    d.polygon([(0,765),(725,691),(1016,1079),(0,1079)],fill="#372138")
    box=(558,0,W,H)
    poly=[(952,0),(W,0),(W,H),(558,H)]
    clipped(im,image("colony"),box,poly,(.53,.5))
    d = ImageDraw.Draw(im)
    d.line((953,0,558,H),fill=ORANGE,width=6)
    label(d,(78,147),"Powered machines",ORANGE)
    headline(d,(73,225),["Put your","colony","to work."],accent=ORANGE,size=139)
    body(d,(85,670),"Grow food, smelt ore",WHITE,41)
    body(d,(85,722),"and run mining drones.",WHITE,41)
    for k in range(4):
        marker(d,96+k*38,869,ORANGE if k==0 else "#895d79",10)
    save(im,"04-put-your-colony-to-work")


def wildlife():
    im = background((14,10,28),(63,38,105),(.78,.39))
    d = ImageDraw.Draw(im)
    d.polygon([(0,220),(1548,84),(1920,492),(1920,944),(0,1080)],fill="#553a87")
    frame(im,image("wildlife"),(440,140),1368,LILAC,4,14)
    d = ImageDraw.Draw(im)
    d.polygon([(0,685),(1210,656),(1057,1080),(0,1080)],fill="#160e2b")
    d.line((0,686,1210,657),fill="#a971e2",width=5)
    label(d,(79,721),"Alien wildlife",LILAC)
    headline(d,(72,774),["Tame the wild."],size=132)
    body(d,(83,933),"Make allies among alien creatures.",WHITE,40)
    save(im,"05-tame-the-wild")


def rover():
    im = fit(image("rover"),(W,H)).convert("RGBA")
    color = gradient((H,W),(9,12,24),0.87,0.0,0.78).transpose(Image.Transpose.ROTATE_90)
    im.alpha_composite(color)
    d = ImageDraw.Draw(im)
    d.polygon([(0,0),(554,0),(458,130),(0,153)],fill="#112928")
    label(d,(76,61),"Surface rover",MINT,28)
    headline(d,(69,237),["Go","off-road."],accent=MINT,size=173)
    body(d,(85,614),"Drive across alien terrain.",WHITE,43)
    d.line((86,711,443,711),fill=MINT,width=3)
    d.line((86,726,278,726),fill="#539799",width=2)
    save(im,"06-go-off-road")


def worlds():
    im = background((8,13,28),(31,47,86),(.5,.5))
    d = ImageDraw.Draw(im)
    headline(d,(70,68),["Jump between six worlds."],size=137)
    body(d,(82,227),"Build a starship and chart your next landing.",ICE,43)
    panels = [("verdania","Verdania",MINT),("kryos","Kryos",ICE),("aridus","Aridus",ORANGE)]
    for idx,(file,world,tint) in enumerate(panels):
        x=74+idx*597
        y=333+(idx%2)*42
        poly=[(x+48,y),(x+578,y),(x+532,y+498),(x,y+498)]
        clipped(im,image(file),(x,y,x+578,y+498),poly,(.58,.54))
        d=ImageDraw.Draw(im)
        d.line([*poly,poly[0]],fill=tint,width=4)
        marker(d,x+19,y+549,tint,9)
        label(d,(x+43,y+535),world,tint,28)
    save(im,"07-jump-between-six-worlds")


def terraform():
    im = background((9,20,25),(39,70,63),(.65,.58),False)
    d = ImageDraw.Draw(im)
    headline(d,(71,66),["Give a planet life."],size=143)
    body(d,(83,226),"Grow an atmosphere, bring water and seed life.",MINT,40)
    x0,y0,x1,y1=67,316,1852,1001
    left=fit(image("terraform-before"),(x1-x0,y1-y0),(.54,.52))
    right=fit(image("terraform-after"),(x1-x0,y1-y0),(.54,.52))
    im.paste(left,(x0,y0))
    poly=[(1000,y0),(x1,y0),(x1,y1),(822,y1)]
    mask=Image.new("L",left.size)
    ImageDraw.Draw(mask).polygon([(x-x0,y-y0) for x,y in poly],fill=255)
    im.paste(right,(x0,y0),mask)
    d=ImageDraw.Draw(im)
    d.line((1000,y0,822,y1),fill=MINT,width=6)
    d.rectangle((x0,y0,x1,y1),outline="#90c8bc",width=3)
    d.rounded_rectangle((93,893,440,965),radius=12,fill="#291722")
    d.rounded_rectangle((1387,893,1825,965),radius=12,fill="#13342c")
    label(d,(114,913),"Barren Aridus",ORANGE,25)
    label(d,(1413,913),"After Terraforming",MINT,24)
    save(im,"08-give-a-planet-life")


def contact_sheet():
    sheet=Image.new("RGB",(1618,1854),"#100c20")
    for i,file in enumerate(sorted(OUT.glob("*.png"))):
        x=15+i%2*800
        y=15+i//2*460
        sheet.paste(fit(Image.open(file),(788,443)),(x,y))
    sheet.save(ROOT / "preview-screenshots.jpg",quality=91)


if __name__ == "__main__":
    branding()
    if "--branding-only" not in sys.argv:
        for build in (survival,mining,crafting,colony,wildlife,rover,worlds,terraform):
            build()
        contact_sheet()


