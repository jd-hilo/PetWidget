#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$ROOT/out"
REPO_OUT="/workspace/slideshows/widget-lockscreen"
ART_OUT="/opt/cursor/artifacts/petmoji-lockscreen"
mkdir -p "$OUT_DIR" "$REPO_OUT" "$ART_OUT"

FONT_DIR="$ROOT/fonts"
mkdir -p "$FONT_DIR"
if [[ ! -f "$FONT_DIR/InterDisplay-Thin.ttf" || ! -f "$FONT_DIR/Nunito-Variable.ttf" ]]; then
  zip="/tmp/Inter-4.1.zip"
  if [[ ! -f "$zip" ]]; then
    curl -fsSL -o "$zip" "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip"
  fi
  unzip -qo -j "$zip" \
    extras/ttf/Inter-Thin.ttf \
    extras/ttf/Inter-ExtraLight.ttf \
    extras/ttf/Inter-Regular.ttf \
    extras/ttf/Inter-Medium.ttf \
    extras/ttf/Inter-SemiBold.ttf \
    extras/ttf/InterDisplay-Thin.ttf \
    extras/ttf/InterDisplay-ExtraLight.ttf \
    -d "$FONT_DIR"
  curl -fsSL -o "$FONT_DIR/Nunito-Variable.ttf" "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
fi

python3 "$ROOT/process_sprites.py"

CHROME="${CHROME:-/usr/bin/google-chrome-stable}"
COMMON=(
  --headless=new
  --disable-gpu
  --no-sandbox
  --disable-dev-shm-usage
  --hide-scrollbars
  --force-device-scale-factor=1
  --window-size=1080,1920
  --default-background-color=000000
  --virtual-time-budget=8000
  --run-all-compositor-stages-before-draw
)

render_one() {
  local state="$1"
  local dest="$2"
  local tmp="$OUT_DIR/${state}.png"
  "$CHROME" "${COMMON[@]}" \
    --screenshot="$tmp" \
    "file://${ROOT}/index.html?state=${state}"
  python3 - <<PY
from PIL import Image
src = Image.open("$tmp")
print("raw", src.size, src.mode)
img = src.convert("RGB").resize((1080, 1920), Image.Resampling.LANCZOS) if src.size != (1080, 1920) else src.convert("RGB")
img.save("$dest", "PNG")
print("wrote", "$dest", img.size)
PY
}

render_one missesyou "$OUT_DIR/lockscreen-missesyou.png"
render_one happy "$OUT_DIR/lockscreen-happy.png"
render_one hungry "$OUT_DIR/lockscreen-hungry.png"

cp -f "$OUT_DIR"/lockscreen-*.png "$REPO_OUT/"
cp -f "$OUT_DIR"/lockscreen-*.png "$ART_OUT/"
cp -f "$ROOT/states.json" "$REPO_OUT/"
cp -f "$ROOT/states.json" "$ART_OUT/"
ls -la "$OUT_DIR" "$REPO_OUT" "$ART_OUT"
