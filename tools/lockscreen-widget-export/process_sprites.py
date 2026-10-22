#!/usr/bin/env python3
"""Throwaway harness: knock out sprite mattes the same way WidgetSpriteView does."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
SRC = ROOT / "sprites"
OUT = ROOT / "sprites_knockout"
REPO_SPRITES = [
    REPO / "tester_happy.png",
    REPO / "tester_sleepy.png",
    REPO / "tester_mad.png",
    REPO / "tester_excited.png",
    REPO / "tester_judging.png",
    REPO / "tester_misses_you.png",
]


def knockout_edge_white(im: Image.Image, matte_threshold: float = 0.93, softness: float = 0.11, max_chroma: float = 0.065) -> Image.Image:
    """Mirrors UIImage.knockingOutEdgeConnectedMatte."""
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


def knockout_near_black(im: Image.Image, threshold: float = 0.08, softness: float = 0.06) -> Image.Image:
    """Mirrors UIImage.knockingOutNearBlack."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    upper = min(1.0, threshold + max(softness, 0.0001))
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            max_c = max(r, g, b) / 255.0
            if max_c >= upper:
                continue
            if max_c <= threshold:
                fade = 0.0
            else:
                fade = (max_c - threshold) / (upper - threshold)
            px[x, y] = (r, g, b, int(max(0, min(1, (a / 255.0) * fade)) * 255.0))
    return rgba


def content_fit_scale(im: Image.Image, target_max_fill: float = 0.84) -> float:
    """Mirrors UIImage.widgetContentFitScale."""
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
    for repo_sprite in REPO_SPRITES:
        if repo_sprite.exists():
            dest = SRC / repo_sprite.name
            dest.write_bytes(repo_sprite.read_bytes())
    OUT.mkdir(parents=True, exist_ok=True)
    scales = {}
    for src in sorted(SRC.glob("tester_*.png")):
        im = Image.open(src)
        knocked = knockout_edge_white(im)
        knocked = knockout_near_black(knocked)
        dest = OUT / src.name
        knocked.save(dest)
        scales[src.name] = round(content_fit_scale(knocked), 4)
        print(f"{src.name}: fitScale={scales[src.name]} size={knocked.size}")

    wallpaper = Image.open(ROOT / "wallpaper.jpg").convert("RGB")
    wallpaper = wallpaper.resize((1080, 1920), Image.Resampling.LANCZOS)
    wallpaper.save(ROOT / "wallpaper-1080x1920.jpg", quality=92)
    print("wallpaper-1080x1920.jpg", wallpaper.size)
    (ROOT / "sprite-fit-scales.json").write_text(
        __import__("json").dumps(scales, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
