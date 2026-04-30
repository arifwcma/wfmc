from pathlib import Path
from PIL import Image, ImageDraw

OUTPUT_DIR = Path('build/experimental')
FOREGROUND_PATH = Path('assets/app_icon_foreground.png')
# Prefer drawable produced by flutter_native_splash; fallback to source asset.
SPLASH_DRAWABLE_PATH = Path('android/app/src/main/res/drawable-xxxhdpi/splash.png')
SPLASH_FALLBACK_PATH = Path('assets/splash_text.png')
SPLASH_PREVIEW_CANVAS = (1080, 2400)

ICON_SIZE = 1024
PIN_FILL_FRACTION = 0.85

LIGHT_BLUE_BACKGROUND = (195, 210, 232, 255)
GRASS_GREEN_BACKGROUND = (22, 137, 74, 255)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    pin = load_tightly_cropped_pin()
    render_icon_preview(pin, LIGHT_BLUE_BACKGROUND, 'icon_current_bg.png')
    render_icon_preview(pin, GRASS_GREEN_BACKGROUND, 'icon_green_bg.png')
    dump_splash_screen_png()
    print(f'wrote previews to {OUTPUT_DIR}')


def dump_splash_screen_png():
    """Composite Android-style splash (#000000 fill + centered splash bitmap) to a PNG."""
    splash_path = SPLASH_DRAWABLE_PATH if SPLASH_DRAWABLE_PATH.exists() else SPLASH_FALLBACK_PATH
    splash = Image.open(splash_path).convert('RGBA')
    cw, ch = SPLASH_PREVIEW_CANVAS
    canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 255))
    sw, sh = splash.size
    scale = min(cw / sw, ch / sh)
    if scale < 1:
        nw, nh = int(sw * scale), int(sh * scale)
        splash = splash.resize((nw, nh), Image.LANCZOS)
        sw, sh = nw, nh
    sx = (cw - sw) // 2
    sy = (ch - sh) // 2
    canvas.paste(splash, (sx, sy), splash)
    out = OUTPUT_DIR / 'splash_screen.png'
    canvas.convert('RGB').save(out)
    print(f'wrote {out}')


def render_icon_preview(pin, background_color, output_filename):
    canvas = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), background_color)
    target_size = int(ICON_SIZE * PIN_FILL_FRACTION)
    scaled_pin = scale_to_fit(pin, target_size)
    offset_x = (ICON_SIZE - scaled_pin.width) // 2
    offset_y = (ICON_SIZE - scaled_pin.height) // 2
    canvas.paste(scaled_pin, (offset_x, offset_y), scaled_pin)
    apply_circular_mask(canvas)
    canvas.save(OUTPUT_DIR / output_filename)


def load_tightly_cropped_pin():
    foreground = Image.open(FOREGROUND_PATH).convert('RGBA')
    bbox = foreground.getbbox()
    return foreground.crop(bbox)


def scale_to_fit(image, target_size):
    width, height = image.size
    scale = min(target_size / width, target_size / height)
    return image.resize((int(width * scale), int(height * scale)), Image.LANCZOS)


def apply_circular_mask(canvas):
    mask = Image.new('L', canvas.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, canvas.size[0], canvas.size[1]), fill=255)
    canvas.putalpha(mask)


if __name__ == '__main__':
    main()
