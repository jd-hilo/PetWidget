#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$ROOT/out"
REPO_OUT="/workspace/slideshows/widget-lockscreen"
ART_OUT="/opt/cursor/artifacts/petmoji-lockscreen"
mkdir -p "$OUT_DIR" "$REPO_OUT" "$ART_OUT"

FONT_DIR="$ROOT/fonts"
mkdir -p "$FONT_DIR"
if [[ ! -f "$FONT_DIR/Inter-Thin.ttf" ]]; then
  curl -fsSL -o "$FONT_DIR/Inter-Thin.ttf" "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuLyeMZg.ttf"
  curl -fsSL -o "$FONT_DIR/Inter-ExtraLight.ttf" "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuDyfMZg.ttf"
  curl -fsSL -o "$FONT_DIR/Inter-Regular.ttf" "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuLyfMZg.ttf"
  curl -fsSL -o "$FONT_DIR/Inter-Medium.ttf" "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuI6fMZg.ttf"
  curl -fsSL -o "$FONT_DIR/Inter-SemiBold.ttf" "https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuGKYMZg.ttf"
  curl -fsSL -o "$FONT_DIR/Nunito-SemiBold.ttf" "https://fonts.gstatic.com/s/nunito/v32/XRXI3I6Li01BKofiOc5wtlZ2di8HDGUmRTM.ttf"
  curl -fsSL -o "$FONT_DIR/Nunito-Bold.ttf" "https://fonts.gstatic.com/s/nunito/v32/XRXI3I6Li01BKofiOc5wtlZ2di8HDFwmRTM.ttf"
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
