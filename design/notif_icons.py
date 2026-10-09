# Notification large icons: a tartan-red disc with the cream Material "rounded" glyph the app uses.
# Writes android/app/src/main/res/drawable-xxhdpi/notif_<channel>.png (64 dp at xxhdpi = 192 px).
#   python3 design/notif_icons.py
from PIL import Image, ImageDraw, ImageFont

FONT = '/Users/sirajul/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
ICONS = {  # channel -> codepoint of Icons.<name>_rounded
    'meals': 0xf0108,  # restaurant
    'water': 0xf03b4,  # water_drop
    'weigh': 0xf8d4,  # monitor_weight
    'walk': 0xf6bd,  # directions_walk
    'streak': 0xf86b,  # local_fire_department
    'fasting': 0xf7fc,  # hourglass_bottom
    'checkins': 0xf719,  # event_available
    'workout': 0xf767,  # fitness_center
}
S, K = 192, 4  # size, supersampling
font = ImageFont.truetype(FONT, int(S * K * .5))
for name, cp in ICONS.items():
    im = Image.new('RGBA', (S * K, S * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, S * K - 1, S * K - 1), fill=(0xAD, 0x3B, 0x26, 255))
    d.text((S * K / 2, S * K / 2), chr(cp), font=font, fill=(0xFF, 0xF8, 0xF3, 255), anchor='mm')
    im.resize((S, S), Image.LANCZOS).save(f'android/app/src/main/res/drawable-xxhdpi/notif_{name}.png')
