"""Post-process flutter_launcher_icons Android adaptive launcher output.

1. Remove the default 16% foreground <inset> from ic_launcher.xml.
2. Snap sky-like pixels in ic_launcher_foreground.png to exact #C0D4EC.
3. Premultiply every pixel onto sky and force alpha=255 so Pixel Launcher parallax/reveal
   (FG scales vs full BG) never shows a semi-transparent gutter — the animated "blue ring".
4. Point adaptive <background> at @drawable/ic_launcher_background (bitmap) so it matches
   the rescaled foreground layers in the compositor.

Monochrome inset is left unchanged.
"""
from __future__ import annotations

import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image

ANDROID_URI = 'http://schemas.android.com/apk/res/android'
A_DRAWABLE = f'{{{ANDROID_URI}}}drawable'

# Must match values/colors.xml ic_launcher_background and pubspec adaptive_icon_background.
LAUNCHER_BG_RGB = np.array([192, 212, 236], dtype=np.float32)  # #C0D4EC
# Global snap: LANCZOS drift from exact sky. Outer band: extra slack where the OEM mask cuts.
SKY_SNAP_EUCLIDEAN_MAX = 34.0
SKY_SNAP_EUCLIDEAN_MAX_IN_MASK_EDGE = 52.0
# Reject navy / hill: only lighten pixels that already read as sky / haze.
SKY_SNAP_MIN_R, SKY_SNAP_MIN_G, SKY_SNAP_MIN_B = 148, 158, 175


def flatten_premultiply_opaque_sky(rgba: Image.Image) -> Image.Image:
    """Premultiply onto sky and set alpha=255 everywhere (kills parallax gutter on Pixel)."""
    arr = np.asarray(rgba.convert('RGBA'), dtype=np.float32)
    rgb, a = arr[:, :, :3], arr[:, :, 3:4] / 255.0
    sky = LAUNCHER_BG_RGB.reshape(1, 1, 3)
    rgb_out = rgb * a + sky * (1.0 - a)
    out = np.zeros_like(arr)
    out[:, :, :3] = np.clip(rgb_out, 0, 255)
    out[:, :, 3] = 255.0
    return Image.fromarray(out.astype(np.uint8), 'RGBA')


def ic_launcher_xml_path(project_root: Path | None = None) -> Path:
    root = project_root or Path(__file__).resolve().parent.parent
    return (
        root
        / 'android'
        / 'app'
        / 'src'
        / 'main'
        / 'res'
        / 'mipmap-anydpi-v26'
        / 'ic_launcher.xml'
    )


def strip_foreground_inset(path: Path | None = None) -> bool:
    """Flatten <foreground><inset .../></foreground> to <foreground android:drawable=.../>.

    Returns True if the file was modified.
    """
    path = path or ic_launcher_xml_path()
    if not path.is_file():
        return False
    tree = ET.parse(path)
    root = tree.getroot()
    changed = False
    for fg in root.findall('foreground'):
        inset = fg.find('inset')
        if inset is None:
            continue
        drawable = inset.get(A_DRAWABLE)
        if not drawable:
            continue
        for child in list(fg):
            fg.remove(child)
        fg.text = None
        fg.set(A_DRAWABLE, drawable)
        changed = True
    if changed:
        ET.register_namespace('android', ANDROID_URI)
        tree.write(
            path,
            encoding='utf-8',
            xml_declaration=True,
            short_empty_elements=True,
        )
    return changed


def ensure_adaptive_background_uses_bitmap_drawable(project_root: Path | None = None) -> bool:
    """Use @drawable/ic_launcher_background so BG matches FG mipmaps (flutter-generated PNG)."""
    root = project_root or Path(__file__).resolve().parent.parent
    probe = root / 'android' / 'app' / 'src' / 'main' / 'res' / 'drawable-mdpi' / 'ic_launcher_background.png'
    if not probe.is_file():
        return False
    path = ic_launcher_xml_path(root)
    tree = ET.parse(path)
    r = tree.getroot()
    changed = False
    for bg in r.findall('background'):
        if bg.get(A_DRAWABLE) == '@color/ic_launcher_background':
            bg.set(A_DRAWABLE, '@drawable/ic_launcher_background')
            changed = True
    if changed:
        ET.register_namespace('android', ANDROID_URI)
        tree.write(
            path,
            encoding='utf-8',
            xml_declaration=True,
            short_empty_elements=True,
        )
    return changed


def snap_foreground_png(path: Path) -> bool:
    """Snap sky fringes, then flatten to fully opaque on sky (Pixel home reveal / parallax)."""
    img0 = Image.open(path).convert('RGBA')
    arr = np.asarray(img0, dtype=np.uint8).copy()
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]
    dist = np.linalg.norm(rgb - LAUNCHER_BG_RGB, axis=2)

    yy, xx = np.mgrid[0:h, 0:w]
    d_edge = np.minimum.reduce([xx, yy, (w - 1) - xx, (h - 1) - yy])
    # Outer ~18dp of 108dp layer + a few px: square perimeter zone (mask + parallax).
    band = int(np.ceil(min(w, h) * (18.0 / 108.0))) + 6
    in_mask_edge = d_edge <= band

    # Circular mask cuts through interior (e.g. top centre on Pixel), not only near square corners.
    cx = (w - 1) * 0.5
    cy = (h - 1) * 0.5
    r_in = min(w, h) * 0.5
    radial = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    curve_band = max(6.0, float(min(w, h)) * (18.0 / 108.0))
    near_circle = radial > (r_in - curve_band)

    r0, g0, b0 = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    light_sky = (
        (r0 >= SKY_SNAP_MIN_R)
        & (g0 >= SKY_SNAP_MIN_G)
        & (b0 >= SKY_SNAP_MIN_B)
        & (b0 >= r0 - 25)
    )
    opaque = alpha > 127
    global_snap = (dist <= SKY_SNAP_EUCLIDEAN_MAX) & opaque & light_sky
    edge_snap = in_mask_edge & (dist <= SKY_SNAP_EUCLIDEAN_MAX_IN_MASK_EDGE) & opaque & light_sky
    curve_snap = near_circle & (dist <= SKY_SNAP_EUCLIDEAN_MAX_IN_MASK_EDGE) & opaque & light_sky

    exact = (r0 == 192) & (g0 == 212) & (b0 == 236)
    fill = (global_snap | edge_snap | curve_snap) & ~exact
    if np.any(fill):
        arr[fill, 0] = 192
        arr[fill, 1] = 212
        arr[fill, 2] = 236
    im_snapped = Image.fromarray(arr, 'RGBA')
    im_out = flatten_premultiply_opaque_sky(im_snapped)
    if np.array_equal(np.asarray(im_out), np.asarray(img0)):
        return False
    im_out.save(path, optimize=True)
    return True


def snap_foreground_drawables_sky(project_root: Path | None = None) -> int:
    """Snap + flatten opaque every ic_launcher_foreground.png under res/."""
    root = project_root or Path(__file__).resolve().parent.parent
    res = root / 'android' / 'app' / 'src' / 'main' / 'res'
    n = 0
    for pattern in ('drawable-*/ic_launcher_foreground.png', 'mipmap-*/ic_launcher_foreground.png'):
        for path in sorted(res.glob(pattern)):
            if snap_foreground_png(path):
                print(f'  foreground: {path.relative_to(root)}')
                n += 1
    return n


def run_refresh_launcher_icons(project_root: Path | None = None) -> None:
    root = project_root or Path(__file__).resolve().parent.parent
    subprocess.check_call(['dart', 'run', 'flutter_launcher_icons'], cwd=root)
    strip_foreground_inset(ic_launcher_xml_path(root))
    snap_foreground_drawables_sky(root)
    if ensure_adaptive_background_uses_bitmap_drawable(root):
        print('ic_launcher.xml: adaptive background -> @drawable/ic_launcher_background')


def main() -> None:
    argv = sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    if argv == ['--fix-only']:
        if strip_foreground_inset(ic_launcher_xml_path(root)):
            print('ic_launcher.xml: removed foreground <inset> (flutter_launcher_icons default).')
        n = snap_foreground_drawables_sky(root)
        if n:
            print(f'Launcher foregrounds: updated {n} file(s) (sky snap + opaque flatten).')
        if ensure_adaptive_background_uses_bitmap_drawable(root):
            print('ic_launcher.xml: adaptive background -> @drawable/ic_launcher_background')
        return
    if argv:
        print('Usage: python tools/ic_launcher_xml_fix.py           # dart run flutter_launcher_icons + fixes')
        print('       python tools/ic_launcher_xml_fix.py --fix-only # XML + sky snap (no dart)')
        sys.exit(2)
    run_refresh_launcher_icons(root)


if __name__ == '__main__':
    main()
