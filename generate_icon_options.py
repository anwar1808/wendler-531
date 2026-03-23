from PIL import Image, ImageDraw, ImageFont
import math

# ── Config ────────────────────────────────────────────────────────────────────

GOLD   = (232, 197, 71)       # #E8C547
DARK   = (30, 30, 30)         # #1E1E1E  — icon background
BG     = (18, 18, 18)         # #121212  — overall image background
WHITE  = (255, 255, 255)
ICON_SIZE = 192
CORNER_R  = 32                # rounded corner radius for icon background

COLS = 3
ROWS = 2
PAD_X = 48    # horizontal padding between / around icons
PAD_Y = 48    # vertical padding between / around icons
LABEL_H = 36  # height reserved for number label below each icon

CELL_W = ICON_SIZE + PAD_X
CELL_H = ICON_SIZE + LABEL_H + PAD_Y

IMG_W = COLS * ICON_SIZE + (COLS + 1) * PAD_X
IMG_H = ROWS * (ICON_SIZE + LABEL_H) + (ROWS + 1) * PAD_Y


def make_icon_canvas():
    """Return a new 192x192 RGBA image with a dark rounded-square background."""
    img = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([(0, 0), (ICON_SIZE - 1, ICON_SIZE - 1)],
                            radius=CORNER_R, fill=DARK)
    return img, draw


# ── Icon 1 — Barbell side view ────────────────────────────────────────────────

def icon_barbell(arrow=False):
    img, draw = make_icon_canvas()
    cx = ICON_SIZE // 2
    cy = ICON_SIZE // 2

    bar_y  = cy + 10 if arrow else cy
    bar_x1 = 20
    bar_x2 = ICON_SIZE - 20
    bar_h  = 8          # bar thickness
    plate_w = 16        # plate width
    plate_h = 52        # plate height
    collar_w = 8
    collar_h = 28

    # Main bar
    draw.rectangle([(bar_x1 + plate_w + collar_w, bar_y - bar_h // 2),
                    (bar_x2 - plate_w - collar_w, bar_y + bar_h // 2)],
                   fill=GOLD)

    # Left plate
    draw.rectangle([(bar_x1, bar_y - plate_h // 2),
                    (bar_x1 + plate_w, bar_y + plate_h // 2)],
                   fill=GOLD)
    # Left collar
    draw.rectangle([(bar_x1 + plate_w, bar_y - collar_h // 2),
                    (bar_x1 + plate_w + collar_w, bar_y + collar_h // 2)],
                   fill=GOLD)

    # Right plate
    draw.rectangle([(bar_x2 - plate_w, bar_y - plate_h // 2),
                    (bar_x2, bar_y + plate_h // 2)],
                   fill=GOLD)
    # Right collar
    draw.rectangle([(bar_x2 - plate_w - collar_w, bar_y - collar_h // 2),
                    (bar_x2 - plate_w, bar_y + collar_h // 2)],
                   fill=GOLD)

    if arrow:
        # Small upward arrow above centre of bar
        ax = cx
        ay_tip = bar_y - plate_h // 2 - 10   # tip of arrow
        ay_base = bar_y - 18                  # base of arrow shaft
        shaft_w = 5
        arrow_w = 18
        arrow_h = 14

        # Shaft
        draw.rectangle([(ax - shaft_w // 2, ay_tip + arrow_h),
                        (ax + shaft_w // 2, ay_base)],
                       fill=GOLD)
        # Arrowhead (triangle)
        draw.polygon([
            (ax,             ay_tip),
            (ax - arrow_w // 2, ay_tip + arrow_h),
            (ax + arrow_w // 2, ay_tip + arrow_h),
        ], fill=GOLD)

    return img


# ── Icon 3 — Deadlift silhouette ──────────────────────────────────────────────

def icon_deadlift():
    img, draw = make_icon_canvas()

    # Geometric stick figure mid-deadlift: torso angled forward ~45deg,
    # arms hanging, bar at floor level
    cx = ICON_SIZE // 2
    floor_y = ICON_SIZE - 28

    # Bar (on floor)
    bar_y = floor_y
    draw.rectangle([(22, bar_y - 5), (ICON_SIZE - 22, bar_y + 5)], fill=GOLD)

    # Left plate
    draw.ellipse([(22, bar_y - 26), (38, bar_y + 26)], fill=GOLD)
    # Right plate
    draw.ellipse([(ICON_SIZE - 38, bar_y - 26), (ICON_SIZE - 22, bar_y + 26)], fill=GOLD)

    # Figure: hands grip at bar level (slightly inward)
    hand_lx, hand_rx = 60, ICON_SIZE - 60
    hand_y = bar_y - 6

    # Arms (straight down from shoulders to hands)
    shoulder_lx, shoulder_rx = 68, ICON_SIZE - 68
    hip_y = floor_y - 44
    hip_x = cx + 4

    # Torso: hip to shoulders (angled — hinging forward)
    torso_top_x = cx - 10
    torso_top_y = floor_y - 100
    draw.line([(hip_x, hip_y), (torso_top_x, torso_top_y)],
              fill=GOLD, width=9)

    # Head (circle above torso top)
    head_r = 10
    draw.ellipse([(torso_top_x - head_r - 2, torso_top_y - head_r * 2 - 4),
                  (torso_top_x + head_r - 2, torso_top_y - 4)], fill=GOLD)

    # Left arm
    draw.line([(torso_top_x - 2, torso_top_y + 8), (hand_lx, hand_y)],
              fill=GOLD, width=7)
    # Right arm
    draw.line([(torso_top_x - 2, torso_top_y + 8), (hand_rx, hand_y)],
              fill=GOLD, width=7)

    # Left leg (from hip down to floor, bent at knee)
    knee_lx, knee_ly = hip_x - 16, floor_y - 20
    draw.line([(hip_x, hip_y), (knee_lx, knee_ly)], fill=GOLD, width=9)
    draw.line([(knee_lx, knee_ly), (hand_lx + 4, floor_y)], fill=GOLD, width=9)

    # Right leg
    knee_rx, knee_ry = hip_x + 10, floor_y - 20
    draw.line([(hip_x, hip_y), (knee_rx, knee_ry)], fill=GOLD, width=9)
    draw.line([(knee_rx, knee_ry), (hand_rx - 4, floor_y)], fill=GOLD, width=9)

    return img


# ── Icon 4 — Stacked plates (end-on view) ────────────────────────────────────

def icon_plates_endview():
    img, draw = make_icon_canvas()
    cx = cy = ICON_SIZE // 2

    # Concentric rings from largest to smallest (like a target / bullseye)
    # Alternating filled ring look: draw filled circles from large to small,
    # alternating dark/gold so rings are visible
    radii = [80, 65, 50, 36, 22, 10]
    colors_seq = [GOLD, DARK, GOLD, DARK, GOLD, DARK]

    for r, c in zip(radii, colors_seq):
        draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)], fill=c)

    # Small gold centre dot
    draw.ellipse([(cx - 5, cy - 5), (cx + 5, cy + 5)], fill=GOLD)

    return img


# ── Icon 5 — Barbell + W lettermark ──────────────────────────────────────────

def icon_barbell_W():
    img, draw = make_icon_canvas()
    cx = ICON_SIZE // 2

    # Barbell in upper half
    bar_y = 70
    bar_x1 = 18
    bar_x2 = ICON_SIZE - 18
    bar_h = 7
    plate_w = 14
    plate_h = 40
    collar_w = 7
    collar_h = 22

    draw.rectangle([(bar_x1 + plate_w + collar_w, bar_y - bar_h // 2),
                    (bar_x2 - plate_w - collar_w, bar_y + bar_h // 2)],
                   fill=GOLD)
    draw.rectangle([(bar_x1, bar_y - plate_h // 2),
                    (bar_x1 + plate_w, bar_y + plate_h // 2)], fill=GOLD)
    draw.rectangle([(bar_x1 + plate_w, bar_y - collar_h // 2),
                    (bar_x1 + plate_w + collar_w, bar_y + collar_h // 2)], fill=GOLD)
    draw.rectangle([(bar_x2 - plate_w, bar_y - plate_h // 2),
                    (bar_x2, bar_y + plate_h // 2)], fill=GOLD)
    draw.rectangle([(bar_x2 - plate_w - collar_w, bar_y - collar_h // 2),
                    (bar_x2 - plate_w, bar_y + collar_h // 2)], fill=GOLD)

    # Bold "W" below barbell — drawn as polygon lines
    # W occupies roughly x: 36–156, y: 104–160
    wx1, wx2 = 30, ICON_SIZE - 30
    wy_top = 100
    wy_bot = 162
    wy_mid = wy_bot - 20   # the inner V peaks here

    w_pts = [
        (wx1,                wy_top),
        (wx1 + (wx2 - wx1) * 0.20, wy_bot),
        (cx,                 wy_mid),
        (wx2 - (wx2 - wx1) * 0.20, wy_bot),
        (wx2,                wy_top),
    ]
    draw.line(w_pts, fill=GOLD, width=14, joint='curve')

    return img


# ── Icon 6 — Kettlebell ───────────────────────────────────────────────────────

def icon_kettlebell():
    img, draw = make_icon_canvas()
    cx = ICON_SIZE // 2

    # Bell (circle, lower half)
    bell_r = 52
    bell_cx = cx
    bell_cy = ICON_SIZE - 28 - bell_r
    draw.ellipse([(bell_cx - bell_r, bell_cy - bell_r),
                  (bell_cx + bell_r, bell_cy + bell_r)], fill=GOLD)

    # Mask out a dark circle inside the bell to create a ring effect
    inner_r = 34
    draw.ellipse([(bell_cx - inner_r, bell_cy - inner_r),
                  (bell_cx + inner_r, bell_cy + inner_r)], fill=DARK)

    # Handle arch above the bell
    handle_outer_r = 36
    handle_inner_r = 22
    handle_cy = bell_cy - bell_r + 14   # overlaps top of bell slightly

    # Outer arc (filled ellipse, upper half only — use chord/pieslice)
    bbox_outer = [(bell_cx - handle_outer_r, handle_cy - handle_outer_r),
                  (bell_cx + handle_outer_r, handle_cy + handle_outer_r)]
    draw.pieslice(bbox_outer, start=180, end=360, fill=GOLD)

    # Inner arc cutout
    bbox_inner = [(bell_cx - handle_inner_r, handle_cy - handle_inner_r),
                  (bell_cx + handle_inner_r, handle_cy + handle_inner_r)]
    draw.pieslice(bbox_inner, start=180, end=360, fill=DARK)

    # Cover the bottom flat edge of the arc (rectangle patch so the arch
    # sits cleanly on the bell without a gap line)
    draw.rectangle([(bell_cx - handle_outer_r, handle_cy),
                    (bell_cx + handle_outer_r, handle_cy + 14)], fill=GOLD)
    draw.rectangle([(bell_cx - handle_inner_r + 1, handle_cy),
                    (bell_cx + handle_inner_r - 1, handle_cy + 14)], fill=DARK)

    # Re-draw the bell circle to clean up the overlap at the top
    draw.ellipse([(bell_cx - bell_r, bell_cy - bell_r),
                  (bell_cx + bell_r, bell_cy + bell_r)], fill=GOLD)
    draw.ellipse([(bell_cx - inner_r, bell_cy - inner_r),
                  (bell_cx + inner_r, bell_cy + inner_r)], fill=DARK)

    return img


# ── Assemble grid ─────────────────────────────────────────────────────────────

icons = [
    icon_barbell(arrow=False),   # 1
    icon_barbell(arrow=True),    # 2
    icon_deadlift(),             # 3
    icon_plates_endview(),       # 4
    icon_barbell_W(),            # 5
    icon_kettlebell(),           # 6
]

canvas = Image.new('RGB', (IMG_W, IMG_H), BG)
draw_main = ImageDraw.Draw(canvas)

# Try to load a font; fall back to default
try:
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 20)
except Exception:
    font = ImageFont.load_default()

for idx, icon in enumerate(icons):
    row = idx // COLS
    col = idx % COLS

    x = PAD_X + col * (ICON_SIZE + PAD_X)
    y = PAD_Y + row * (ICON_SIZE + LABEL_H + PAD_Y)

    canvas.paste(icon, (x, y), icon)

    # Number label centred below the icon
    label = str(idx + 1)
    # Get text size
    bbox = draw_main.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    lx = x + ICON_SIZE // 2 - tw // 2
    ly = y + ICON_SIZE + (LABEL_H - th) // 2
    draw_main.text((lx, ly), label, fill=WHITE, font=font)

out_path = '/Users/annie/Downloads/icon_options.png'
canvas.save(out_path, dpi=(150, 150))
print(f'Saved → {out_path}')
