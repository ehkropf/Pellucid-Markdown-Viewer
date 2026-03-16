#!/usr/bin/env python3
"""Generate md_viewr app icon: M↓ with magnifying glass, Preview.app aesthetic."""

import math

# We'll generate an SVG, then convert to PNG via sips
OUTPUT_SVG = "Resources/AppIcon.svg"
OUTPUT_PNG = "Resources/AppIcon.png"
SIZE = 1024

def generate_svg():
    """Create the icon as SVG for maximum quality."""

    # macOS icon: rounded rect with continuous corners (squircle)
    # Preview.app style: light background, magnifying glass, subject underneath

    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">
  <defs>
    <!-- Icon background gradient (warm white like Preview.app) -->
    <linearGradient id="bgGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FAFAFA"/>
      <stop offset="100%" stop-color="#E8E8EC"/>
    </linearGradient>

    <!-- Subtle inner shadow for depth -->
    <filter id="innerShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="8" result="blur"/>
      <feOffset dx="0" dy="4" result="offsetBlur"/>
      <feComposite in="SourceGraphic" in2="offsetBlur" operator="over"/>
    </filter>

    <!-- Drop shadow for magnifying glass -->
    <filter id="glassShadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="0" dy="12" stdDeviation="18" flood-color="#000000" flood-opacity="0.25"/>
    </filter>

    <!-- Subtle shadow for the text -->
    <filter id="textShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#000000" flood-opacity="0.08"/>
    </filter>

    <!-- Glass lens gradient (frosted/clear) -->
    <radialGradient id="lensGrad" cx="0.4" cy="0.35" r="0.65">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.95"/>
      <stop offset="50%" stop-color="#F0F4FF" stop-opacity="0.85"/>
      <stop offset="100%" stop-color="#D8DFEF" stop-opacity="0.75"/>
    </radialGradient>

    <!-- Lens rim gradient (metallic) -->
    <linearGradient id="rimGrad" x1="0" y1="0" x2="0.7" y2="1">
      <stop offset="0%" stop-color="#C8CCD4"/>
      <stop offset="30%" stop-color="#9EA3AD"/>
      <stop offset="60%" stop-color="#787D88"/>
      <stop offset="100%" stop-color="#5C6170"/>
    </linearGradient>

    <!-- Handle gradient -->
    <linearGradient id="handleGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#8E939E"/>
      <stop offset="50%" stop-color="#6B707C"/>
      <stop offset="100%" stop-color="#4A4F5C"/>
    </linearGradient>

    <!-- M↓ text color gradient -->
    <linearGradient id="textGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#3A3F4B"/>
      <stop offset="100%" stop-color="#1A1D24"/>
    </linearGradient>

    <!-- Magnified text inside lens -->
    <linearGradient id="magTextGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#2A2D34"/>
      <stop offset="100%" stop-color="#0F1117"/>
    </linearGradient>

    <!-- Clip for lens content -->
    <clipPath id="lensClip">
      <circle cx="520" cy="360" r="185"/>
    </clipPath>

    <!-- Lens reflection -->
    <linearGradient id="reflectionGrad" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.6"/>
      <stop offset="40%" stop-color="#FFFFFF" stop-opacity="0.15"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <!-- === BACKGROUND === -->
  <!-- macOS squircle (approximated with large corner radius) -->
  <rect x="20" y="20" width="984" height="984" rx="220" ry="220"
        fill="url(#bgGrad)" stroke="#D0D0D5" stroke-width="1"/>

  <!-- Subtle top highlight -->
  <rect x="22" y="22" width="980" height="490" rx="219" ry="219"
        fill="url(#reflectionGrad)" opacity="0.3"/>

  <!-- === M↓ TEXT (behind the glass) === -->
  <g filter="url(#textShadow)">
    <!-- The "M" — large, filling left-center -->
    <text x="120" y="680" font-family="SF Pro Display, Helvetica Neue, Helvetica, Arial, sans-serif"
          font-weight="800" font-size="620" fill="url(#textGrad)" letter-spacing="-15">M</text>
    <!-- The "↓" arrow — prominent, right of M -->
    <text x="580" y="700" font-family="SF Pro Display, Helvetica Neue, Helvetica, Arial, sans-serif"
          font-weight="400" font-size="480" fill="url(#textGrad)" opacity="0.75">↓</text>
  </g>

  <!-- === MAGNIFYING GLASS === -->
  <g filter="url(#glassShadow)">
    <!-- Handle -->
    <line x1="640" y1="490" x2="800" y2="650"
          stroke="url(#handleGrad)" stroke-width="48" stroke-linecap="round"/>
    <!-- Handle highlight -->
    <line x1="644" y1="486" x2="796" y2="642"
          stroke="#A0A5B0" stroke-width="7" stroke-linecap="round" opacity="0.4"/>

    <!-- Lens rim (outer) -->
    <circle cx="520" cy="360" r="205" fill="none"
            stroke="url(#rimGrad)" stroke-width="26"/>
    <!-- Rim highlight -->
    <circle cx="520" cy="360" r="217" fill="none"
            stroke="#B8BCC5" stroke-width="2" opacity="0.6"/>

    <!-- Lens glass -->
    <circle cx="520" cy="360" r="185" fill="url(#lensGrad)"/>

    <!-- Magnified content inside lens — shows enlarged portion of M↓ -->
    <g clip-path="url(#lensClip)">
      <!-- Magnified M — shifted to show right side of M and left of arrow -->
      <text x="100" y="620" font-family="SF Pro Display, Helvetica Neue, Helvetica, Arial, sans-serif"
            font-weight="800" font-size="740" fill="url(#magTextGrad)" letter-spacing="-18"
            opacity="0.85">M</text>
      <text x="520" y="640" font-family="SF Pro Display, Helvetica Neue, Helvetica, Arial, sans-serif"
            font-weight="400" font-size="580" fill="url(#magTextGrad)"
            opacity="0.65">↓</text>
    </g>

    <!-- Glass reflection (arc highlight) -->
    <ellipse cx="480" cy="300" rx="110" ry="75"
             fill="url(#reflectionGrad)" opacity="0.5"
             transform="rotate(-15, 480, 300)"/>

    <!-- Small specular highlight -->
    <circle cx="448" cy="278" r="16" fill="white" opacity="0.6"/>
  </g>
</svg>"""

    return svg


def main():
    import os
    import subprocess

    svg_content = generate_svg()

    # Write SVG
    os.makedirs("Resources", exist_ok=True)
    with open(OUTPUT_SVG, "w") as f:
        f.write(svg_content)
    print(f"Created {OUTPUT_SVG}")

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
