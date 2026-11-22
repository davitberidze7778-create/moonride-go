#!/usr/bin/env python3
"""Apply the same MOONRIDE M + location-pin launcher icon to each Android app."""
from pathlib import Path
import re
import subprocess
import sys

if len(sys.argv) != 4:
    raise SystemExit("usage: apply_moonride_branding.py <android-res-dir> <manifest-path> <app-label>")

res = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
app_label = sys.argv[3]
svg = Path("apps/shared/brand/moonride-app-icon.svg")
if not svg.is_file():
    raise SystemExit(f"Shared MOONRIDE icon source not found: {svg}")
if not manifest_path.is_file():
    raise SystemExit(f"Android manifest not found: {manifest_path}")

densities = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
for density, size in densities.items():
    folder = res / f"mipmap-{density}"
    folder.mkdir(parents=True, exist_ok=True)
    for name in ("ic_launcher.png", "ic_launcher_foreground.png"):
        subprocess.run(
            ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(folder / name), str(svg)],
            check=True,
        )

adaptive = res / "mipmap-anydpi-v26"
adaptive.mkdir(parents=True, exist_ok=True)
(adaptive / "ic_launcher.xml").write_text(
    """<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/moonride_icon_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""",
    encoding="utf-8",
)

values = res / "values"
values.mkdir(parents=True, exist_ok=True)
(values / "moonride_icon_background.xml").write_text(
    """<resources><color name="moonride_icon_background">#071B34</color></resources>""",
    encoding="utf-8",
)

text = manifest_path.read_text(encoding="utf-8")
match = re.search(r"<application\\b[^>]*>", text)
if not match:
    raise SystemExit("AndroidManifest.xml has no application element")
tag = match.group(0)
if re.search(r'android:label="[^"]*"', tag):
    tag = re.sub(r'android:label="[^"]*"', f'android:label="{app_label}"', tag, count=1)
else:
    tag = tag[:-1] + f' android:label="{app_label}">'
if re.search(r'android:icon="[^"]*"', tag):
    tag = re.sub(r'android:icon="[^"]*"', 'android:icon="@mipmap/ic_launcher"', tag, count=1)
else:
    tag = tag[:-1] + ' android:icon="@mipmap/ic_launcher">'
text = text[:match.start()] + tag + text[match.end():]
manifest_path.write_text(text, encoding="utf-8")
print(f"Applied shared MOONRIDE launcher icon and label: {app_label}")
