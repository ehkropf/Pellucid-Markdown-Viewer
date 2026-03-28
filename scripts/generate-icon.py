#!/usr/bin/env python3
# Pellucid — Native macOS markdown viewer
# Copyright (C) 2026 Everett Kropf
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

"""Generate Pellucid app icon PNG and .icns from the SVG source."""

# SVG is the source of truth — edit Resources/AppIcon.svg directly.
# This script converts SVG → PNG → .icns.
OUTPUT_SVG = "Resources/AppIcon.svg"
OUTPUT_PNG = "Resources/AppIcon.png"
SIZE = 1024


def main():
    import os
    import subprocess

    if not os.path.exists(OUTPUT_SVG):
        print(f"Error: {OUTPUT_SVG} not found. Edit the SVG directly.")
        return

    # Convert to PNG using rsvg-convert if available, otherwise sips
    try:
        # Try rsvg-convert first (best SVG rendering)
        subprocess.run(
            ["rsvg-convert", "-w", str(SIZE), "-h", str(SIZE),
             "-o", OUTPUT_PNG, OUTPUT_SVG],
            check=True, capture_output=True
        )
        print(f"Created {OUTPUT_PNG} (via rsvg-convert)")
    except (FileNotFoundError, subprocess.CalledProcessError):
        try:
            # Try qlmanage (macOS built-in, decent SVG support)
            subprocess.run(
                ["qlmanage", "-t", "-s", str(SIZE), "-o", "Resources/", OUTPUT_SVG],
                check=True, capture_output=True
            )
            # qlmanage creates a .svg.png file
            ql_output = f"{OUTPUT_SVG}.png"
            if os.path.exists(ql_output):
                os.rename(ql_output, OUTPUT_PNG)
                print(f"Created {OUTPUT_PNG} (via qlmanage)")
            else:
                print("qlmanage didn't produce output, trying sips...")
                raise FileNotFoundError
        except (FileNotFoundError, subprocess.CalledProcessError):
            # Last resort: sips (limited SVG support)
            subprocess.run(
                ["sips", "-s", "format", "png",
                 "--resampleWidth", str(SIZE),
                 OUTPUT_SVG, "--out", OUTPUT_PNG],
                check=True, capture_output=True
            )
            print(f"Created {OUTPUT_PNG} (via sips)")

    # Also generate .icns for the app bundle
    generate_icns(OUTPUT_PNG)


def generate_icns(png_path):
    """Generate .icns from the 1024x1024 PNG."""
    import subprocess
    import tempfile
    import os

    iconset_dir = "Resources/AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    # Required sizes for macOS .icns
    sizes = [16, 32, 64, 128, 256, 512, 1024]

    for size in sizes:
        # Standard resolution
        out = os.path.join(iconset_dir, f"icon_{size}x{size}.png")
        subprocess.run(
            ["sips", "-z", str(size), str(size), png_path, "--out", out],
            check=True, capture_output=True
        )
        # @2x resolution (half the stated size, double density)
        if size <= 512:
            out2x = os.path.join(iconset_dir, f"icon_{size//1 if size > 16 else size}x{size//1 if size > 16 else size}@2x.png")
            # Actually the convention is: icon_16x16@2x.png is 32px
            # Let me do this properly

    # Redo with proper naming
    import shutil
    shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir)

    icon_specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, pixel_size in icon_specs:
        out = os.path.join(iconset_dir, filename)
        subprocess.run(
            ["sips", "-z", str(pixel_size), str(pixel_size), png_path, "--out", out],
            check=True, capture_output=True
        )

    # Convert iconset to icns
    icns_path = "Resources/AppIcon.icns"
    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path],
        check=True, capture_output=True
    )
    print(f"Created {icns_path}")

    # Clean up iconset
    shutil.rmtree(iconset_dir)


if __name__ == "__main__":
    main()
