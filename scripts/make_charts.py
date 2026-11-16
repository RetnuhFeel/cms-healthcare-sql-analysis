#!/usr/bin/env python3
"""Draw the two README charts from the query results in results/*.csv.

Optional step (needs matplotlib):  pip install matplotlib && python scripts/make_charts.py
"""
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RES, OUT = ROOT / "results", ROOT / "charts"
OUT.mkdir(exist_ok=True)


def read(name):
    with open(RES / name, newline="") as fh:
        return list(csv.DictReader(fh))


# Chart 1 - Tennessee Part D spend by diabetes drug family (Q09)
rows = [r for r in read("q09_yoy_class_trend.csv") if r["geo_name"] == "Tennessee"]
fig, ax = plt.subplots(figsize=(8, 4.5))
for family, color in [("GLP-1 / GIP", "#1f77b4"), ("SGLT2", "#2ca02c"), ("Insulin", "#d62728")]:
    pts = [(int(r["data_year"]), float(r["drug_cost_millions"])) for r in rows if r["drug_family"] == family]
    ax.plot([p[0] for p in pts], [p[1] for p in pts], marker="o", label=family, color=color, linewidth=2)
ax.set_title("Tennessee Medicare Part D spending by diabetes drug family, 2019-2024")
ax.set_ylabel("Total drug cost ($ millions)")
ax.grid(alpha=0.3)
ax.legend()
fig.text(0.01, 0.01, "Source: CMS Medicare Part D Prescribers by Geography and Drug (query q09)", fontsize=8, color="gray")
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(OUT / "tn_diabetes_spend_trend.png", dpi=130)

# Chart 2 - Medicare Advantage share, TN vs US (Q12)
rows = read("q12_medicare_advantage_share.csv")
years = [int(r["calendar_year"]) for r in rows]
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.plot(years, [float(r["tn_ma_share_pct"]) for r in rows], marker="o", label="Tennessee", linewidth=2)
ax.plot(years, [float(r["us_ma_share_pct"]) for r in rows], marker="o", label="United States", linewidth=2)
ax.axhline(50, color="gray", linestyle="--", linewidth=1)
ax.set_title("Share of Medicare beneficiaries in Medicare Advantage")
ax.set_ylabel("% of all beneficiaries (annual average)")
ax.grid(alpha=0.3)
ax.legend()
fig.text(0.01, 0.01, "Source: CMS Medicare Monthly Enrollment (query q12). 2026 = Jan-Jul.", fontsize=8, color="gray")
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(OUT / "ma_share_tn_vs_us.png", dpi=130)
print("charts written to charts/")
