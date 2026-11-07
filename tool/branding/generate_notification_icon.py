#!/usr/bin/env python3
"""Render the existing vector brand mask. Requires librsvg's rsvg-convert."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def main():
    for density, size in [('mdpi',24),('hdpi',36),('xhdpi',48),('xxhdpi',72),('xxxhdpi',96)]:
        subprocess.run(['rsvg-convert', '--width', str(size), '--height', str(size),
            '--output', str(ROOT / f'android/app/src/main/res/drawable-{density}/notification_icon.png'),
            str(ROOT / 'assets/brand/source/notification-icon.svg')], check=True)

if __name__ == '__main__': main()
