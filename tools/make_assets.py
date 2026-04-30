from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ASSETS_DIR = Path('assets')
SOURCE_ICON_PATH = ASSETS_DIR / 'icon_main.png'
SPLASH_FONT_PATH = Path('C:/Windows/Fonts/arialbd.ttf')

ICON_LARGE_SIZE = 1024
ICON_PLAY_STORE_SIZE = 512

FOREGROUND_CANVAS = 1024
FOREGROUND_INNER_FRACTION = 0.62

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


def main():
    source = Image.open(SOURCE_ICON_PATH).convert('RGBA')
    save_landscape_icons(source)
    foreground = build_foreground(source)
    foreground.save(ASSETS_DIR / 'app_icon_foreground.png')
    monochrome = to_white_silhouette(foreground)
    monochrome.save(ASSETS_DIR / 'app_icon_monochrome.png')
    splash = build_splash_text()
    splash.save(ASSETS_DIR / 'splash_text.png')
    print('done')


def save_landscape_icons(source):
    source.resize((ICON_LARGE_SIZE, ICON_LARGE_SIZE), Image.LANCZOS).save(ASSETS_DIR / 'app_icon_1024.png')
    source.resize((ICON_PLAY_STORE_SIZE, ICON_PLAY_STORE_SIZE), Image.LANCZOS).save(ASSETS_DIR / 'app_icon_512.png')


def build_foreground(source):
    isolated = source.copy()
    clear_all_edge_connected_regions(isolated)
    keep_only_pin_around_largest_navy_blob(isolated)
    keep_only_largest_opaque_blob(isolated)
    pin_only = crop_to_opaque_bbox(isolated)
    print(f'pin extracted size {pin_only.size}')
    return paste_centered_with_padding(pin_only, FOREGROUND_CANVAS, FOREGROUND_INNER_FRACTION)


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
    print(f'found {blob_count} navy blobs; pin body is label {largest_blob_label} (size {int(blob_sizes[largest_blob_label - 1])} px)')
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
            print(f'splash font size {size}px gives "{text}" width {width}px (target {target_width}px)')
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
