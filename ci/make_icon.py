"""Draws the Nexa Tap logo: an N whose right stroke becomes tap waves."""
from PIL import Image, ImageDraw
S = 1024
LIME = '#C8FF4D'; INK = '#0B0D1A'

def mark(size, col):
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    w = 92
    x0, y0, x1, y1 = 300, 300, 560, 724
    d.rounded_rectangle([x0, y0, x0 + w, y1], radius=w // 2, fill=col)
    d.line([(x0 + w / 2, y0 + w / 2), (x1, y1 - w / 2)], fill=col, width=w)
    d.ellipse([x1 - w / 2, y1 - w, x1 + w / 2, y1], fill=col)
    d.ellipse([x0, y0, x0 + w, y0 + w], fill=col)
    cx, cy = x1, y1 - w / 2
    for r in (150, 250, 350):
        d.arc([cx - r, cy - r, cx + r, cy + r], start=-90, end=-20, fill=col, width=62)
    box = im.getbbox(); im = im.crop(box)
    k = size / max(im.size); im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    return im

def place(bg, m):
    bg.alpha_composite(m, ((S - m.width) // 2, (S - m.height) // 2)); return bg

full = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(full).rounded_rectangle([0, 0, S, S], radius=240, fill=INK)
place(full, mark(560, LIME)).save('assets/icon.png')
place(Image.new('RGBA', (S, S), (0, 0, 0, 0)), mark(470, LIME)).save('assets/icon_fg.png')
