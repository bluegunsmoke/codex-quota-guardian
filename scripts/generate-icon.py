from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
APP_ICON = ROOT / "src" / "CodexGuardian.App" / "guardian.ico"
PREVIEW = ROOT / "assets" / "guardian-mark.png"
SIZE = 1024

image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((32, 32, 992, 992), radius=220, fill="#101014")
draw.arc((224, 224, 800, 800), start=-42, end=228, fill="#B8A6FF", width=64)
draw.ellipse((388, 388, 636, 636), fill="#B8A6FF")
draw.ellipse((710, 230, 822, 342), fill="#F3EFFF")
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
image.resize((512, 512), Image.Resampling.LANCZOS).save(PREVIEW)
image.save(APP_ICON, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print(APP_ICON)
