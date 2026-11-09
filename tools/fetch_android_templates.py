"""Download only the Android entries of the official Godot export-template bundle.

The .tpz file is a zip archive (~1.2 GB). Using HTTP range requests we read its central
directory and fetch only android_debug.apk / android_release.apk / version.txt
(~230 MB) into the local Godot export_templates folder.

Usage: python tools/fetch_android_templates.py 4.7.2 [dest_dir]
"""
import io
import os
import sys
import urllib.request
import zipfile

VERSION = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
URL = (f"https://downloads.godotengine.org/?version={VERSION}&flavor=stable"
       f"&slug=export_templates.tpz&platform=templates")
DEST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.environ.get("APPDATA", os.path.expanduser("~/.local/share")), "Godot", "export_templates",
    f"{VERSION}.stable")
UA = {"User-Agent": "Mozilla/5.0 (PlanetCraft template fetcher)"}
WANTED = ("version.txt", "android_debug.apk", "android_release.apk", "android_source.zip")


class HttpRangeFile(io.RawIOBase):
    def __init__(self, url):
        req = urllib.request.Request(url, method="HEAD", headers=UA)
        with urllib.request.urlopen(req) as r:
            self.url = r.geturl()
            self.size = int(r.headers["Content-Length"])
        self.pos = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else self.size + off)
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(self.url, headers={**UA, "Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        self.pos += len(data)
        return data

    def readinto(self, b):
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)


def main():
    os.makedirs(DEST, exist_ok=True)
    f = HttpRangeFile(URL)
    print(f"archive size {f.size / 1e6:.0f} MB")
    buffered = io.BufferedReader(f, buffer_size=4 * 1024 * 1024)
    with zipfile.ZipFile(buffered) as z:
        for info in z.infolist():
            name = info.filename.split("/")[-1]
            if name not in WANTED:
                continue
            target = os.path.join(DEST, name)
            if os.path.exists(target) and os.path.getsize(target) == info.file_size:
                print(f"skip {name} (exists)")
                continue
            print(f"fetch {name} {info.file_size / 1e6:.0f} MB", flush=True)
            with z.open(info) as src, open(target + ".part", "wb") as dst:
                done = 0
                while True:
                    chunk = src.read(8 * 1024 * 1024)
                    if not chunk:
                        break
                    dst.write(chunk)
                    done += len(chunk)
                    print(f"  {name}: {done / 1e6:.0f} MB", flush=True)
            os.replace(target + ".part", target)
    print("done", DEST)


if __name__ == "__main__":
    main()
