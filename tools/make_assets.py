from pathlib import Path
import importlib.util
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from scipy.interpolate import PchipInterpolator

ASSETS_DIR = Path('assets')
SOURCE_ICON_PATH = ASSETS_DIR / 'icon_main.png'
SPLASH_FONT_PATH = Path('C:/Windows/Fonts/arialbd.ttf')

ICON_LARGE_SIZE = 1024
ICON_PLAY_STORE_SIZE = 512

FOREGROUND_CANVAS = 1024
# Layer 108×108 dp; squircle masks clip tighter than a circle. Use ~67dp box (~625px) so the
# pin clears Samsung; was 72dp (682px) and still clipped slightly top/bottom.
PIN_SAFE_BOX_PX = int(FOREGROUND_CANVAS * 67 // 108)
# Must match pubspec flutter_launcher_icons adaptive_icon_background and colors.xml.
LAUNCHER_BACKGROUND_SKY = np.array([192, 212, 236], dtype=np.uint8)  # #C0D4EC
MONOCHROME_INNER_FRACTION = 0.55

SPLASH_CANVAS = 1152
SPLASH_INNER_CIRCLE = 768
SPLASH_TEXT = 'Wimmera CMA'
SPLASH_TEXT_WIDTH_FRACTION = 0.85

EDGE_STEP_PIXELS = 8
COLOR_BACKGROUND_TOLERANCE = 120

PIN_NAVY_RGB = (0, 76, 136)
PIN_NAVY_TOLERANCE = 80
PIN_BBOX_PADDING = 12

WHITE_RGBA = (255, 255, 255, 255)
TRANSPARENT_RGBA = (0, 0, 0, 0)

CLASS_SKY = 0
CLASS_WATER = 1
CLASS_HILL = 2


def main():
    source = Image.open(SOURCE_ICON_PATH).convert('RGBA')
    save_landscape_icons(source)
    foreground = build_foreground(source)
    foreground.save(ASSETS_DIR / 'app_icon_foreground.png')
    pin_silhouette = build_pin_silhouette(source)
    monochrome = to_white_silhouette(pin_silhouette)
    monochrome.save(ASSETS_DIR / 'app_icon_monochrome.png')
    splash = build_splash_text()
    splash.save(ASSETS_DIR / 'splash_text.png')
    print('done')
    _strip_adaptive_foreground_inset_xml()


def _strip_adaptive_foreground_inset_xml():
    """Keep mipmap-anydpi-v26/ic_launcher.xml free of flutter_launcher_icons' foreground inset."""
    root = Path(__file__).resolve().parent.parent
    script = Path(__file__).resolve().parent / 'ic_launcher_xml_fix.py'
    subprocess.check_call([sys.executable, str(script), '--fix-only'], cwd=root)


def save_landscape_icons(source):
    source.resize((ICON_LARGE_SIZE, ICON_LARGE_SIZE), Image.LANCZOS).save(ASSETS_DIR / 'app_icon_1024.png')
    source.resize((ICON_PLAY_STORE_SIZE, ICON_PLAY_STORE_SIZE), Image.LANCZOS).save(ASSETS_DIR / 'app_icon_512.png')


def _flatten_launcher_fg_opaque_sky(rgba: Image.Image) -> Image.Image:
    """Premultiply onto #C0D4EC and alpha=255 (see ic_launcher_xml_fix.flatten_premultiply_opaque_sky)."""
    spec = importlib.util.spec_from_file_location(
        '_ic_launcher_fix', Path(__file__).resolve().parent / 'ic_launcher_xml_fix.py'
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod.flatten_premultiply_opaque_sky(rgba)


def build_foreground(source):
    sky = (192, 212, 236, 255)
    canvas = Image.new('RGBA', (FOREGROUND_CANVAS, FOREGROUND_CANVAS), sky)
    landscape = build_landscape_without_pin(source).convert('RGBA')
    canvas.paste(landscape, (0, 0))
    pin = extract_pin_with_alpha(source)
    pin_scaled = scale_to_fit(pin, PIN_SAFE_BOX_PX)
    offset_x = (FOREGROUND_CANVAS - pin_scaled.width) // 2
    offset_y = (FOREGROUND_CANVAS - pin_scaled.height) // 2
    canvas.alpha_composite(pin_scaled, (offset_x, offset_y))
    return _flatten_launcher_fg_opaque_sky(canvas)


def build_landscape_without_pin(source):
    rgb = np.array(source.convert('RGB'))
    height, width = rgb.shape[:2]
    pin_alpha_mask = compute_pin_alpha_mask(source)
    pin_columns = pin_alpha_mask.any(axis=0)
    pin_columns_padded = pad_columns(pin_columns, padding=12)
    sky_color, water_color, hill_color = sample_landscape_palette(rgb, pin_columns_padded)
    print(
        f'colors  sky(sample)={sky_color.tolist()}  sky(painted)={LAUNCHER_BACKGROUND_SKY.tolist()}  '
        f'water={water_color.tolist()}  hill={hill_color.tolist()}'
    )
    classification = classify_landscape_pixels(rgb, sky_color, water_color, hill_color)
    ground_top = topmost_row_per_column(classification != CLASS_SKY, pin_columns_padded, default=height)
    hill_top = topmost_row_per_column(classification == CLASS_HILL, pin_columns_padded, default=height)
    ground_top = smooth_interpolate_curve(ground_top)
    hill_top = smooth_interpolate_curve(hill_top)
    out = paint_landscape(
        height, width, ground_top, hill_top, LAUNCHER_BACKGROUND_SKY, water_color, hill_color
    )
    return Image.fromarray(out, 'RGB').resize((FOREGROUND_CANVAS, FOREGROUND_CANVAS), Image.LANCZOS)


def extract_pin_with_alpha(source):
    isolated = source.copy()
    clear_all_edge_connected_regions(isolated)
    keep_only_pin_around_largest_navy_blob(isolated)
    keep_only_largest_opaque_blob(isolated)
    pin_only = crop_to_opaque_bbox(isolated)
    print(f'pin extracted size {pin_only.size}')
    return pin_only


def build_pin_silhouette(source):
    pin = extract_pin_with_alpha(source)
    return paste_centered_with_padding(pin, FOREGROUND_CANVAS, MONOCHROME_INNER_FRACTION)


def compute_pin_alpha_mask(source):
    isolated = source.copy()
    clear_all_edge_connected_regions(isolated)
    keep_only_pin_around_largest_navy_blob(isolated)
    keep_only_largest_opaque_blob(isolated)
    return np.array(isolated)[:, :, 3] > 0


def pad_columns(boolean_columns, padding):
    out = boolean_columns.copy()
    for shift in range(1, padding + 1):
        out[shift:] |= boolean_columns[:-shift]
        out[:-shift] |= boolean_columns[shift:]
    return out


def sample_landscape_palette(rgb, pin_columns_padded):
    height, _ = rgb.shape[:2]
    clean_columns = ~pin_columns_padded
    sky_pixels = rgb[: height // 6, clean_columns].reshape(-1, 3)
    sky_color = np.median(sky_pixels, axis=0).astype(np.uint8)
    hill_pixels = rgb[5 * height // 6 :, clean_columns].reshape(-1, 3)
    hill_color = np.median(hill_pixels, axis=0).astype(np.uint8)
    water_color = sample_water_color(rgb, pin_columns_padded)
    return sky_color, water_color, hill_color


def sample_water_color(rgb, pin_columns_padded):
    region = rgb[:, ~pin_columns_padded]
    is_navy = (
        (region[:, :, 2] > 100)
        & (region[:, :, 0] < 60)
        & (region[:, :, 1] > 40)
        & (region[:, :, 1] < 130)
    )
    navy_pixels = region[is_navy]
    if navy_pixels.size == 0:
        return np.array([0, 76, 136], dtype=np.uint8)
    return np.median(navy_pixels, axis=0).astype(np.uint8)


def classify_landscape_pixels(rgb, sky_color, water_color, hill_color):
    pixels = rgb.astype(np.float32)
    distance_sky = np.linalg.norm(pixels - sky_color.astype(np.float32), axis=2)
    distance_water = np.linalg.norm(pixels - water_color.astype(np.float32), axis=2)
    distance_hill = np.linalg.norm(pixels - hill_color.astype(np.float32), axis=2)
    stacked = np.stack([distance_sky, distance_water, distance_hill], axis=2)
    return np.argmin(stacked, axis=2)


def topmost_row_per_column(boolean_mask, pin_columns_padded, default):
    _, width = boolean_mask.shape
    out = np.full(width, -1, dtype=int)
    for x in range(width):
        if pin_columns_padded[x]:
            continue
        column_hits = np.where(boolean_mask[:, x])[0]
        out[x] = int(column_hits[0]) if column_hits.size > 0 else default
    return out


def smooth_interpolate_curve(curve):
    valid = curve >= 0
    if not valid.any():
        return curve.copy()
    valid_x = np.where(valid)[0]
    valid_y = curve[valid].astype(np.float32)
    all_x = np.arange(len(curve))
    if len(valid_x) < 4:
        return np.interp(all_x, valid_x, valid_y).astype(int)
    interpolator = PchipInterpolator(valid_x, valid_y, extrapolate=True)
    smoothed = interpolator(all_x)
    return ndimage.uniform_filter1d(smoothed, size=8).astype(int)


def paint_landscape(height, width, ground_top, hill_top, sky_color, water_color, hill_color):
    out = np.empty((height, width, 3), dtype=np.uint8)
    for x in range(width):
        ground = max(0, min(height, int(ground_top[x])))
        hill = max(ground, min(height, int(hill_top[x])))
        out[:ground, x] = sky_color
        out[ground:hill, x] = water_color
        out[hill:, x] = hill_color
    return out


def keep_only_largest_opaque_blob(image):
    rgba = np.array(image)
    alpha_mask = rgba[:, :, 3] > 0
    labelled, blob_count = ndimage.label(alpha_mask)
    if blob_count == 0:
        return
    blob_sizes = ndimage.sum(alpha_mask, labelled, index=range(1, blob_count + 1))
    largest_blob_label = int(np.argmax(blob_sizes)) + 1
    keep_mask = labelled == largest_blob_label
    rgba[~keep_mask] = (0, 0, 0, 0)
    image.paste(Image.fromarray(rgba, 'RGBA'))


def keep_only_pin_around_largest_navy_blob(image):
    rgba = np.array(image)
    height, width, _ = rgba.shape
    navy_mask = is_color_close_to(rgba, PIN_NAVY_RGB, PIN_NAVY_TOLERANCE)
    labelled, blob_count = ndimage.label(navy_mask)
    if blob_count == 0:
        return
    blob_sizes = ndimage.sum(navy_mask, labelled, index=range(1, blob_count + 1))
    largest_blob_label = int(np.argmax(blob_sizes)) + 1
    pin_body_mask = labelled == largest_blob_label
    pin_bbox = bounding_box_with_padding(pin_body_mask, PIN_BBOX_PADDING, width, height)
    bbox_mask = mask_inside_bbox(pin_bbox, width, height)
    non_pin_navy_mask = navy_mask & ~pin_body_mask
    keep_mask = bbox_mask & ~non_pin_navy_mask
    rgba[~keep_mask] = (0, 0, 0, 0)
    image.paste(Image.fromarray(rgba, 'RGBA'))


def is_color_close_to(rgba_array, target_rgb, tolerance):
    diffs = np.abs(rgba_array[:, :, :3].astype(int) - np.array(target_rgb, dtype=int))
    return diffs.sum(axis=2) <= tolerance


def bounding_box_with_padding(boolean_mask, padding, width, height):
    rows, cols = np.where(boolean_mask)
    y0 = max(0, int(rows.min()) - padding)
    y1 = min(height - 1, int(rows.max()) + padding)
    x0 = max(0, int(cols.min()) - padding)
    x1 = min(width - 1, int(cols.max()) + padding)
    return x0, y0, x1, y1


def mask_inside_bbox(bbox, width, height):
    x0, y0, x1, y1 = bbox
    mask = np.zeros((height, width), dtype=bool)
    mask[y0:y1 + 1, x0:x1 + 1] = True
    return mask


def clear_all_edge_connected_regions(image):
    width, height = image.size
    perimeter_seeds = []
    for x in range(0, width, EDGE_STEP_PIXELS):
        perimeter_seeds.append((x, 0))
        perimeter_seeds.append((x, height - 1))
    for y in range(0, height, EDGE_STEP_PIXELS):
        perimeter_seeds.append((0, y))
        perimeter_seeds.append((width - 1, y))
    for seed in perimeter_seeds:
        if image.getpixel(seed)[3] == 0:
            continue
        ImageDraw.floodfill(image, seed, TRANSPARENT_RGBA, thresh=COLOR_BACKGROUND_TOLERANCE)


def crop_to_opaque_bbox(image):
    bbox = image.getbbox()
    if bbox is None:
        raise ValueError('flood-fill cleared everything; nothing left to extract')
    return image.crop(bbox)


def paste_centered_with_padding(content, canvas_size, inner_fraction):
    inner_size = int(canvas_size * inner_fraction)
    scaled = scale_to_fit(content, inner_size)
    canvas = Image.new('RGBA', (canvas_size, canvas_size), TRANSPARENT_RGBA)
    offset_x = (canvas_size - scaled.width) // 2
    offset_y = (canvas_size - scaled.height) // 2
    canvas.paste(scaled, (offset_x, offset_y), scaled)
    return canvas


def scale_to_fit(image, target_size):
    width, height = image.size
    scale = min(target_size / width, target_size / height)
    new_size = (int(width * scale), int(height * scale))
    return image.resize(new_size, Image.LANCZOS)


def to_white_silhouette(rgba_image):
    width, height = rgba_image.size
    silhouette = Image.new('RGBA', (width, height), TRANSPARENT_RGBA)
    silhouette_pixels = silhouette.load()
    source_pixels = rgba_image.load()
    for y in range(height):
        for x in range(width):
            alpha = source_pixels[x, y][3]
            if alpha > 0:
                silhouette_pixels[x, y] = (255, 255, 255, alpha)
    return silhouette


def build_splash_text():
    canvas = Image.new('RGBA', (SPLASH_CANVAS, SPLASH_CANVAS), TRANSPARENT_RGBA)
    draw = ImageDraw.Draw(canvas)
    target_width = int(SPLASH_INNER_CIRCLE * SPLASH_TEXT_WIDTH_FRACTION)
    font = pick_font_size_for_width(SPLASH_TEXT, target_width)
    text_height = measure_text_height(font, SPLASH_TEXT)
    top_y = (SPLASH_CANVAS - text_height) // 2
    draw_text_centered(draw, font, SPLASH_TEXT, top_y)
    return canvas


def pick_font_size_for_width(text, target_width):
    for size in range(400, 20, -4):
        font = load_arial_bold(size)
        width = measure_text_width(font, text)
        if width <= target_width:
            return font
    return load_arial_bold(20)


def load_arial_bold(size):
    return ImageFont.truetype(str(SPLASH_FONT_PATH), size)


def measure_text_width(font, text):
    bbox = font.getbbox(text)
    return bbox[2] - bbox[0]


def measure_text_height(font, text):
    bbox = font.getbbox(text)
    return bbox[3] - bbox[1]


def draw_text_centered(draw, font, text, top_y):
    bbox = font.getbbox(text)
    text_width = bbox[2] - bbox[0]
    x = (SPLASH_CANVAS - text_width) // 2 - bbox[0]
    y = top_y - bbox[1]
    draw.text((x, y), text, font=font, fill=WHITE_RGBA)


if __name__ == '__main__':
    main()
