from __future__ import annotations

import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_URI = 'http://schemas.android.com/apk/res/android'
A_DRAWABLE = f'{{{ANDROID_URI}}}drawable'


def ic_launcher_xml_path(project_root=None):
    root = project_root or Path(__file__).resolve().parent.parent
    return root / 'android' / 'app' / 'src' / 'main' / 'res' / 'mipmap-anydpi-v26' / 'ic_launcher.xml'


def strip_foreground_inset(path=None):
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
        tree.write(path, encoding='utf-8', xml_declaration=True, short_empty_elements=True)
    return changed


def ensure_adaptive_background_uses_bitmap_drawable(project_root=None):
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
        tree.write(path, encoding='utf-8', xml_declaration=True, short_empty_elements=True)
    return changed


def run_refresh_launcher_icons(project_root=None):
    root = project_root or Path(__file__).resolve().parent.parent
    subprocess.check_call(['dart', 'run', 'flutter_launcher_icons'], cwd=root)
    strip_foreground_inset(ic_launcher_xml_path(root))
    ensure_adaptive_background_uses_bitmap_drawable(root)


def main():
    argv = sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    if argv == ['--fix-only']:
        if strip_foreground_inset(ic_launcher_xml_path(root)):
            print('ic_launcher.xml: removed foreground inset.')
        if ensure_adaptive_background_uses_bitmap_drawable(root):
            print('ic_launcher.xml: background -> @drawable/ic_launcher_background')
        return
    if argv:
        print('Usage: python tools/ic_launcher_xml_fix.py')
        print('       python tools/ic_launcher_xml_fix.py --fix-only')
        sys.exit(2)
    run_refresh_launcher_icons(root)


if __name__ == '__main__':
    main()
