import sys
from PIL import Image

SCALE = 1.5  # display_z 640 over 960px client, MyOpenGLView.m:525-527 with a 4:3 client
CX, CY = 480.0, 360.0
Y_OFFSET = 240.0


def hud_point(vx, vy0, y_origin):
    vy = vy0 + Y_OFFSET * y_origin
    return CX + vx * SCALE, CY - vy * SCALE


def box_stats(img, x0, y0, x1, y1):
    px = img.convert("RGB").load()
    red = 0
    total = 0
    brightest = (0, 0, 0)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            r, g, b = px[x, y]
            total += 1
            if r >= 100 and g <= 70 and b <= 70:
                red += 1
            if r + g + b > sum(brightest):
                brightest = (r, g, b)
    return red, total, brightest


scan_cx, scan_cy = hud_point(0, 68, -1)
half_w = 288.0 / 2 * SCALE
print("scanner centre px", scan_cx, scan_cy, "half width px", half_w)
left = scan_cx - half_w
right = scan_cx + half_w
print("left arc", left, "right arc", right)

for path in sys.argv[1:]:
    img = Image.open(path)
    print(path, img.size)
    for name, cx in (("LEFT", left), ("RIGHT", right)):
        print("  ", name, box_stats(img, cx - 7, scan_cy - 9, cx + 7, scan_cy + 9))
