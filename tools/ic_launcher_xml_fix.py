"""Remove flutter_launcher_icons' 16% foreground <inset> from adaptive ic_launcher.xml.

The package always wraps the foreground in an inset, which exposes the background as a
visible ring on circular masks. Foreground must reference the drawable directly.
Monochrome inset is left unchanged.
"""
from __future__ import annotations

import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_URI = 'http://schemas.android.com/apk/res/android'
A_DRAWABLE = f'{{{ANDROID_URI}}}drawable'


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


def run_refresh_launcher_icons(project_root: Path | None = None) -> None:
    root = project_root or Path(__file__).resolve().parent.parent
    subprocess.check_call(['dart', 'run', 'flutter_launcher_icons'], cwd=root)
    strip_foreground_inset(ic_launcher_xml_path(root))


def main() -> None:
    argv = sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    if argv == ['--fix-only']:
        if strip_foreground_inset(ic_launcher_xml_path(root)):
            print('ic_launcher.xml: removed foreground <inset> (flutter_launcher_icons default).')
        return
    if argv:
        print('Usage: python tools/ic_launcher_xml_fix.py           # dart run flutter_launcher_icons + fix')
        print('       python tools/ic_launcher_xml_fix.py --fix-only # fix XML only')
        sys.exit(2)
    run_refresh_launcher_icons(root)


if __name__ == '__main__':
    main()
