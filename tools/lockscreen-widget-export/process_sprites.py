#!/usr/bin/env python3
"""Throwaway harness: knock out sprite mattes the same way WidgetSpriteView does."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "sprites"
OUT = ROOT / "sprites_knockout"
CLAY_SOURCES = {
    "pet-sleepy.jpg": Path("/opt/cursor/artifacts/assets/pet-sleepy.jpg"),
    "pet-missesyou.jpg": Path("/opt/cursor/artifacts/assets/pet-missesyou.jpg"),
    "pet-mad.jpg": Path("/opt/cursor/artifacts/assets/pet-mad.jpg"),
}
WALLPAPER_SRC = Path("/opt/cursor/artifacts/assets/homescreen-wallpaper-blur.jpg")


def knockout_edge_white(im: Image.Image, matte_threshold: float = 0.93, softness: float = 0.11, max_chroma: float = 0.065) -> Image.Image:
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    matte_floor = max(0.0, matte_threshold - max(softness, 0.0001))

    def is_matte(x: int, y: int) -> bool:
        r, g, b, _a = px[x, y]
        rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
        min_c = min(rf, gf, bf)
        chroma = max(rf, gf, bf) - min_c
        return min_c >= matte_floor and chroma <= max_chroma

    visited = bytearray(w * h)
    q: deque[int] = deque()

    def enqueue(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= w or y >= h:
            return
        flat = y * w + x
        if visited[flat] or not is_matte(x, y):
            return
        visited[flat] = 1
        q.append(flat)

    for x in range(w):
        enqueue(x, 0)
        enqueue(x, h - 1)
    for y in range(h):
        enqueue(0, y)
        enqueue(w - 1, y)

    while q:
        flat = q.popleft()
        x, y = flat % w, flat // w
        enqueue(x + 1, y)
        enqueue(x - 1, y)
        enqueue(x, y + 1)
        enqueue(x, y - 1)

    for flat, flag in enumerate(visited):
        if flag:
            x, y = flat % w, flat // w
            px[x, y] = (0, 0, 0, 0)
    return rgba


def content_fit_scale(im: Image.Image, target_max_fill: float = 0.92) -> float:
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    min_x, min_y, max_x, max_y = w, h, 0, 0
    found = False
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 20:
                found = True
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if not found:
        return 0.88
    bw = (max_x - min_x + 1) / w
    bh = (max_y - min_y + 1) / h
    max_fill = max(bw, bh)
    if max_fill <= target_max_fill:
        return 1.0
    return target_max_fill / max_fill


def main() -> None:
    SRC.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    scales = {}
    for name, src in CLAY_SOURCES.items():
        if not src.exists():
            raise SystemExit(f"missing clay sprite {src}")
        dest = SRC / name
        dest.write_bytes(src.read_bytes())
        im = Image.open(dest)
        knocked = knockout_edge_white(im, matte_threshold=0.94, softness=0.10, max_chroma=0.08)
        out = OUT / (Path(name).stem + ".png")
        knocked.save(out)
        scales[out.name] = round(content_fit_scale(knocked), 4)
        print(f"{out.name}: fitScale={scales[out.name]} size={knocked.size}")

    if not WALLPAPER_SRC.exists():
        raise SystemExit(f"missing wallpaper {WALLPAPER_SRC}")
    wallpaper = Image.open(WALLPAPER_SRC).convert("RGB")
    wallpaper = wallpaper.resize((1080, 1920), Image.Resampling.LANCZOS)
    wallpaper = ImageEnhance.Color(wallpaper).enhance(0.55)
    wallpaper = ImageEnhance.Contrast(wallpaper).enhance(0.82)
    wallpaper = ImageEnhance.Brightness(wallpaper).enhance(0.92)
    wallpaper = wallpaper.filter(ImageFilter.GaussianBlur(radius=6))
    wallpaper.save(ROOT / "wallpaper-1080x1920.jpg", quality=90)
    print("wallpaper-1080x1920.jpg", wallpaper.size)
    (ROOT / "sprite-fit-scales.json").write_text(
        __import__("json").dumps(scales, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
