#!/usr/bin/env python3
"""Fix XML encoding declaration in .strings files.

Xcode 26.5 compiles String Catalogs (.xcstrings) into .strings files with
UTF-16LE byte encoding, but the XML declaration incorrectly claims UTF-8.
This causes macOS to fail parsing them, falling back to English bundle names.

This script scans the build output and corrects the XML declaration to match
the actual byte encoding.
"""
import plistlib
import re
import sys
from pathlib import Path

DECL = re.compile(r'encoding="UTF-8"')

def fix_one(path: Path) -> bool:
    raw = path.read_bytes()
    # Detect actual byte encoding
    if raw[:2] == b'\xff\xfe':
        text = raw[2:].decode('utf-16-le')
        enc = 'utf-16-le'
    elif raw[:3] == b'\xef\xbb\xbf':
        text = raw[3:].decode('utf-8')
        enc = 'utf-8'
    else:
        text = raw.decode('utf-8')
        enc = 'utf-8'
    
    # Check if declaration needs fixing
    if not DECL.search(text):
        return False
    
    # Fix declaration to match actual encoding
    if enc == 'utf-16-le':
        fixed = DECL.sub('encoding="UTF-16"', text, count=1)
        path.write_bytes(b'\xff\xfe' + fixed.encode('utf-16-le'))
    else:
        # Already UTF-8 with UTF-8 declaration, no fix needed
        return False
    
    return True

def main():
    if len(sys.argv) != 2:
        print(f'Usage: {sys.argv[0]} <build-output-dir>', file=sys.stderr)
        sys.exit(1)
    
    build_dir = Path(sys.argv[1])
    if not build_dir.exists():
        print(f'Build directory not found: {build_dir}', file=sys.stderr)
        sys.exit(1)
    
    changed = 0
    for p in sorted(build_dir.rglob('*.strings')):
        try:
            if fix_one(p):
                changed += 1
                print(f'Fixed {p.relative_to(build_dir)}')
        except Exception as e:
            print(f'Warning: failed to fix {p}: {e}', file=sys.stderr)
    
    print(f'Fixed {changed} .strings file(s)')

if __name__ == '__main__':
    main()
