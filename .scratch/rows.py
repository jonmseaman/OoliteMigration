import sys
sys.path.insert(0, "upstream/oolite/tests/gui")
from PIL import Image
import conftest

RECT = (0, 0, 960, 720)


def row_band(row):
    _, y = conftest.row_to_point(row, RECT)
    return y


def nonblack(img, y, half=6):
    px = img.convert("RGB").load()
    n = 0
    for yy in range(max(0, y - half), min(719, y + half) + 1):
        for x in range(0, 960):
            r, g, b = px[x, yy]
            if r + g + b > 120:
                n += 1
    return n


for path in sys.argv[1:]:
    img = Image.open(path)
    print("==", path)
    for row in (1, 2, 3, 4, 5, 6, 15, 17, 22, 23, 24, 25, 26, 27):
        print(f"   row {row:2d} y={row_band(row):3d} nonblack={nonblack(img, row_band(row))}")
