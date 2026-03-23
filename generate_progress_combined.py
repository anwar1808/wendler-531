import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
from datetime import datetime, timedelta

# ── Data ──────────────────────────────────────────────────────────────────────

data = {
    'Bench Press': [
        ('2018-06-19', 39), ('2018-07-03', 45), ('2018-07-08', 46), ('2018-07-27', 48),
        ('2018-08-01', 49), ('2018-08-10', 51), ('2018-09-14', 57), ('2018-09-26', 60),
        ('2018-11-06', 61), ('2018-12-14', 63), ('2018-12-27', 65), ('2019-01-24', 66),
        ('2022-02-02', 60), ('2022-02-15', 60), ('2022-03-16', 64), ('2022-03-31', 65),
        ('2022-05-09', 70), ('2022-10-02', 58), ('2022-10-08', 61), ('2023-03-03', 57),
        ('2023-07-12', 50), ('2023-07-22', 56), ('2023-07-28', 61), ('2023-07-31', 59),
        ('2023-08-04', 63), ('2023-08-10', 67), ('2023-08-21', 70), ('2023-09-08', 72),
        ('2023-09-16', 72), ('2023-10-03', 70), ('2023-10-17', 76), ('2023-11-14', 77),
        ('2023-11-18', 74), ('2023-11-27', 77), ('2023-12-08', 75), ('2024-01-12', 79),
        ('2024-02-03', 77), ('2024-02-12', 73), ('2024-04-17', 74), ('2024-04-25', 79),
        ('2024-05-20', 76), ('2024-06-06', 75), ('2024-06-29', 74), ('2024-09-17', 77),
        ('2024-09-25', 86),
    ],
    'Deadlift': [
        ('2018-06-27', 72), ('2018-07-03', 76), ('2018-07-11', 80), ('2018-07-27', 84),
        ('2018-08-01', 86), ('2018-08-10', 88), ('2018-09-14', 90), ('2018-09-26', 96),
        ('2018-10-26', 99), ('2018-12-15', 99), ('2019-02-23', 99),
        ('2022-02-03', 59), ('2022-02-15', 76), ('2022-02-23', 87), ('2022-03-16', 93),
        ('2022-04-12', 90), ('2022-05-09', 101), ('2022-10-08', 82),
        ('2023-10-08', 82), ('2023-10-18', 87), ('2023-11-17', 103), ('2023-12-03', 89),
        ('2023-12-07', 105), ('2023-12-11', 108), ('2024-01-16', 108), ('2024-02-04', 102),
        ('2024-02-16', 110), ('2024-04-22', 113), ('2024-04-30', 114), ('2024-05-21', 113),
        ('2024-07-14', 120), ('2024-09-22', 99),
    ],
    'Military Press': [
        ('2018-06-24', 31), ('2018-06-27', 31), ('2018-07-06', 33), ('2018-07-20', 34),
        ('2018-07-28', 35), ('2018-08-03', 37), ('2018-08-31', 38), ('2018-09-19', 40),
        ('2018-10-26', 38), ('2018-12-11', 39), ('2018-12-23', 39), ('2019-01-03', 40),
        ('2022-02-03', 34), ('2022-02-09', 42), ('2022-02-17', 43), ('2022-03-13', 41),
        ('2022-03-22', 44), ('2022-04-16', 45), ('2022-09-30', 46), ('2022-11-13', 37),
        ('2022-12-20', 41), ('2023-07-12', 30), ('2023-07-17', 36), ('2023-07-21', 37),
        ('2023-08-02', 41), ('2023-08-09', 43), ('2023-09-07', 43), ('2023-09-11', 40),
        ('2023-10-02', 45), ('2023-10-05', 48), ('2023-10-09', 49), ('2023-10-18', 48),
        ('2023-11-15', 48), ('2023-11-19', 48), ('2023-11-23', 51), ('2023-12-13', 53),
        ('2024-02-05', 51), ('2024-02-18', 50), ('2024-04-23', 44), ('2024-07-10', 53),
        ('2024-09-18', 48),
    ],
    'Back Squat': [
        ('2018-06-24', 63), ('2018-07-06', 67), ('2018-07-11', 72), ('2018-07-20', 77),
        ('2018-07-28', 79), ('2018-08-03', 82), ('2018-08-31', 83), ('2018-09-19', 85),
        ('2018-11-06', 85), ('2018-12-15', 85), ('2019-02-23', 85),
        ('2022-02-02', 62), ('2022-02-09', 70), ('2022-02-17', 87), ('2022-03-13', 89),
        ('2022-03-31', 91), ('2022-04-28', 93), ('2022-10-06', 77),
        ('2023-10-17', 76),
    ],
}

COLORS = {
    'Bench Press':    '#E8C547',
    'Deadlift':       '#E87847',
    'Military Press': '#47A8E8',
    'Back Squat':     '#78E847',
}

TODAY = datetime(2026, 3, 23)
GAP_THRESHOLD = 30  # days

# ── Helpers ───────────────────────────────────────────────────────────────────

def parse(raw):
    pts = [(datetime.strptime(d, '%Y-%m-%d'), float(v)) for d, v in raw]
    pts.sort(key=lambda x: x[0])
    return pts


def bezier_dip(t1, v1, t2, v2, n=200):
    gap_days = (t2 - t1).days
    v_mid_linear = (v1 + v2) / 2.0
    dip_depth = abs(v2 - v1) * 0.3 + (gap_days / 365.0) * 0.05 * min(v1, v2)
    floor = v_mid_linear - dip_depth

    tc = t1 + timedelta(days=gap_days * 0.35)
    tc_num = mdates.date2num(tc)
    t1_num = mdates.date2num(t1)
    t2_num = mdates.date2num(t2)

    tt = np.linspace(0, 1, n)
    x_num = (1 - tt)**2 * t1_num + 2*(1 - tt)*tt * tc_num + tt**2 * t2_num
    y     = (1 - tt)**2 * v1      + 2*(1 - tt)*tt * floor  + tt**2 * v2

    x_dates = mdates.num2date(x_num)
    return x_dates, y


def project_squat_from_bench(squat_pts, bench_pts, today):
    last_sq_date, last_sq_val = squat_pts[-1]

    diffs = [abs((bd - last_sq_date).days) for bd, _ in bench_pts]
    start_idx = int(np.argmin(diffs))

    proj_dates = [last_sq_date]
    proj_vals  = [last_sq_val]

    cur_val = last_sq_val
    for i in range(start_idx, len(bench_pts) - 1):
        bd_cur, bv_cur = bench_pts[i]
        bd_nxt, bv_nxt = bench_pts[i + 1]
        pct_change = (bv_nxt - bv_cur) / bv_cur
        cur_val = cur_val * (1 + pct_change)
        offset = bd_nxt - bench_pts[start_idx][0]
        proj_dates.append(last_sq_date + offset)
        proj_vals.append(cur_val)
        if last_sq_date + offset >= today:
            break

    if proj_dates[-1] < today:
        proj_dates.append(today)
        proj_vals.append(proj_vals[-1])

    return proj_dates, proj_vals


def build_series(pts, gap_threshold=GAP_THRESHOLD):
    real_dates = [p[0] for p in pts]
    real_vals  = [p[1] for p in pts]
    interp_segs = []

    for i in range(len(pts) - 1):
        t1, v1 = pts[i]
        t2, v2 = pts[i + 1]
        gap = (t2 - t1).days
        if gap > gap_threshold:
            xd, yv = bezier_dip(t1, v1, t2, v2)
            interp_segs.append((xd, yv))

    return real_dates, real_vals, interp_segs


# ── Figure layout ─────────────────────────────────────────────────────────────

fig = plt.figure(figsize=(16, 9))
fig.patch.set_facecolor('#121212')

# Main chart: left 85%, panel: right 15%
ax = fig.add_axes([0.04, 0.09, 0.77, 0.84])
ax.set_facecolor('#1a1a1a')

lift_order = ['Bench Press', 'Deadlift', 'Military Press', 'Back Squat']
bench_pts  = parse(data['Bench Press'])

last_vals = {}
legend_handles = []

for lift_name in lift_order:
    color = COLORS[lift_name]
    pts   = parse(data[lift_name])

    real_dates, real_vals, interp_segs = build_series(pts)
    last_vals[lift_name] = real_vals[-1]

    # Gap interpolation segments — dashed, 50% alpha
    for xd, yv in interp_segs:
        ax.plot(xd, yv, color=color, alpha=0.5, linewidth=1.5,
                linestyle='--', zorder=2)

    # Real data line + dots
    ax.plot(real_dates, real_vals, color=color, linewidth=2.0,
            linestyle='-', zorder=3, label=lift_name)
    ax.scatter(real_dates, real_vals, color=color, s=20, zorder=4)

    # Squat projection — dotted, 40% alpha
    if lift_name == 'Back Squat':
        proj_dates, proj_vals = project_squat_from_bench(pts, bench_pts, TODAY)
        ax.plot(proj_dates, proj_vals, color=color, alpha=0.4, linewidth=1.5,
                linestyle=':', zorder=2)

    # Legend handle with last 1RM label
    handle = mpatches.Patch(
        color=color,
        label=f'{lift_name}  —  {real_vals[-1]:.0f} kg'
    )
    legend_handles.append(handle)

# ── Axes styling ──────────────────────────────────────────────────────────────

ax.set_xlim(datetime(2018, 1, 1), TODAY)
ax.xaxis.set_major_locator(mdates.YearLocator())
ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
ax.tick_params(colors='#888888', labelsize=9)
for spine in ax.spines.values():
    spine.set_edgecolor('#333333')
ax.grid(True, color='#2a2a2a', linewidth=0.7, zorder=0)
ax.set_ylabel('1RM (kg)', color='#888888', fontsize=10)
ax.set_xlabel('Year', color='#888888', fontsize=10)
ax.set_title('1RM Progress', color='#ffffff', fontsize=14,
             fontweight='bold', pad=12)

# Legend top-left
legend = ax.legend(
    handles=legend_handles,
    loc='upper left',
    framealpha=0.0,
    labelcolor='#cccccc',
    fontsize=9.5,
    handlelength=1.2,
    handleheight=1.0,
    borderpad=0.8,
    labelspacing=0.6,
)

# ── Checkbox panel (right side) ───────────────────────────────────────────────

panel_ax = fig.add_axes([0.83, 0.09, 0.15, 0.84])
panel_ax.set_facecolor('#121212')
panel_ax.set_xlim(0, 1)
panel_ax.set_ylim(0, 1)
panel_ax.axis('off')

n_lifts = len(lift_order)
card_height = 0.16
card_gap    = 0.04
total_block = n_lifts * card_height + (n_lifts - 1) * card_gap
top_start   = (1.0 - total_block) / 2.0 + total_block  # top of first card

for i, lift_name in enumerate(lift_order):
    color = COLORS[lift_name]
    last_val = last_vals[lift_name]

    # Card y position (top to bottom)
    card_y = top_start - i * (card_height + card_gap) - card_height

    # Dark card background
    card_bg = FancyBboxPatch(
        (0.04, card_y), 0.92, card_height,
        boxstyle='round,pad=0.02',
        facecolor='#1E1E1E',
        edgecolor='#2a2a2a',
        linewidth=1.0,
        zorder=2,
    )
    panel_ax.add_patch(card_bg)

    # Coloured left border strip
    left_border = FancyBboxPatch(
        (0.04, card_y), 0.05, card_height,
        boxstyle='round,pad=0.005',
        facecolor=color,
        edgecolor='none',
        zorder=3,
    )
    panel_ax.add_patch(left_border)

    # Checkbox icon — filled square with checkmark
    cb_x = 0.17
    cb_y = card_y + card_height * 0.5
    cb_size = 0.038

    cb_box = FancyBboxPatch(
        (cb_x - cb_size / 2, cb_y - cb_size / 2),
        cb_size, cb_size,
        boxstyle='round,pad=0.004',
        facecolor=color,
        edgecolor='none',
        zorder=4,
    )
    panel_ax.add_patch(cb_box)

    # Checkmark drawn as two line segments
    ck_x0, ck_y0 = cb_x - cb_size * 0.32, cb_y
    ck_xm, ck_ym = cb_x - cb_size * 0.05, cb_y - cb_size * 0.28
    ck_x1, ck_y1 = cb_x + cb_size * 0.38, cb_y + cb_size * 0.32

    panel_ax.plot([ck_x0, ck_xm], [ck_y0, ck_ym],
                  color='#121212', linewidth=1.4, zorder=5, solid_capstyle='round')
    panel_ax.plot([ck_xm, ck_x1], [ck_ym, ck_y1],
                  color='#121212', linewidth=1.4, zorder=5, solid_capstyle='round')

    # Lift name (bold white)
    panel_ax.text(
        0.30, card_y + card_height * 0.66,
        lift_name,
        color='#ffffff',
        fontsize=8.2,
        fontweight='bold',
        va='center',
        ha='left',
        zorder=5,
    )

    # Last 1RM (grey, smaller)
    panel_ax.text(
        0.30, card_y + card_height * 0.30,
        f'{last_val:.0f} kg',
        color='#888888',
        fontsize=7.5,
        va='center',
        ha='left',
        zorder=5,
    )

# Panel header
panel_ax.text(
    0.50, top_start + 0.04,
    'L  I  F  T  S',
    color='#555555',
    fontsize=7,
    fontweight='bold',
    va='bottom',
    ha='center',
    zorder=5,
)

# ── Save ──────────────────────────────────────────────────────────────────────

out_path = '/Users/annie/Downloads/wendler_progress_combined.png'
plt.savefig(out_path, dpi=150, bbox_inches='tight',
            facecolor='#121212', edgecolor='none')
print(f'Saved → {out_path}')
plt.close()
