#!/usr/bin/env python3
"""mentat: estimate Claude Code cost from local logs. Output: first line = menu bar title,
then '---' and detail lines ('--' prefix = indented). Config: config.json next to this file."""
import calendar, glob, json, os, sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

here = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "config.json")))
PRICES = cfg["prices"]
W5M = cfg.get("cache_write_5m_multiplier", 1.25)
W1H = cfg.get("cache_write_1h_multiplier", 2.0)
LIMIT = float(cfg.get("monthly_limit", 0))


def price_for(model):
    best = max((p for p in PRICES if model.startswith(p)), key=len, default=None)
    return PRICES.get(best)


now = datetime.now(timezone.utc)
starts = {
    "5h": now - timedelta(hours=5),
    "today": now.astimezone().replace(hour=0, minute=0, second=0, microsecond=0).astimezone(timezone.utc),
    "7d": now - timedelta(days=7),
    "month": now.replace(day=1, hour=0, minute=0, second=0, microsecond=0),
}
wanted = [w for w in cfg.get("windows", list(starts)) if w in starts]
needed = set(wanted) | {"month", "today", "5h", "7d"}
oldest = min(starts[w] for w in needed).timestamp()
cost = {w: defaultdict(float) for w in starts}
unknown, seen = set(), set()

for f in glob.glob(os.path.expanduser("~/.claude/projects/**/*.jsonl"), recursive=True):
    if os.path.getmtime(f) < oldest:
        continue
    for line in open(f, errors="ignore"):
        try:
            d = json.loads(line)
            m = d.get("message")
            u = m["usage"] if isinstance(m, dict) else None
            if not u:
                continue
            key = (m.get("id"), d.get("requestId"))
            if key in seen:
                continue
            seen.add(key)
            ts = datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00"))
            model = m.get("model", "")
        except (ValueError, KeyError, TypeError):
            continue
        p = price_for(model)
        if not p:
            if model and not model.startswith("<"):
                unknown.add(model)
            continue
        cc = u.get("cache_creation") or {}
        w1h, w5m = cc.get("ephemeral_1h_input_tokens", 0), cc.get("ephemeral_5m_input_tokens", 0)
        if not cc:
            w5m = u.get("cache_creation_input_tokens", 0)
        usd = (u.get("input_tokens", 0) * p[0] + u.get("output_tokens", 0) * p[1]
               + u.get("cache_read_input_tokens", 0) * p[2]
               + w5m * p[0] * W5M + w1h * p[0] * W1H) / 1e6
        for w, s in starts.items():
            if ts >= s:
                cost[w][model] += usd

tot = {w: sum(cost[w].values()) for w in starts}

# Alerts: percent of budget. Month budget = monthly_limit. Day budget = monthly_limit / working days (Mon-Fri) this month.
LEVELS = ["yellow", "orange", "red"]
PCT = cfg.get("alert_percent") or {"yellow": 70, "orange": 80, "red": 90}
mdays = calendar.monthrange(now.year, now.month)[1]
local_now = datetime.now()
WORKDAYS = sum(1 for d in range(1, mdays + 1) if datetime(local_now.year, local_now.month, d).weekday() < 5) or 1
budgets = {"day": LIMIT / WORKDAYS, "month": LIMIT}
alert_lines, worst, scope_level = [], -1, {}
for scope, window in (("day", "today"), ("month", "month")):
    hit = -1
    if budgets[scope] > 0:
        used = tot[window] / budgets[scope] * 100
        for i, name in enumerate(LEVELS):
            try:
                if name in PCT and used >= float(PCT[name]):
                    hit = i
            except (TypeError, ValueError):
                pass
        if hit >= 0:
            alert_lines.append(f"ALERT {scope}: {LEVELS[hit].upper()} (${tot[window]:.0f} is {used:.0f}% of ${budgets[scope]:.0f} budget)")
            worst = max(worst, hit)
            scope_level[scope] = hit
fields = {w: f"{tot[w]:.0f}" for w in starts}
fields["limit"] = f"{LIMIT:.0f}"
fields["pct"] = f"{tot['month'] / LIMIT:.0%}" if LIMIT else "-"


def paint(level, text):
    # Colour span for the menu bar app: RS level US text GS
    return f"\x1e{LEVELS[level]}\x1f{text}\x1d"


# A day alert colours only the today value. A month alert colours the month value and percent.
colored = {"today": scope_level.get("day", -1), "month": scope_level.get("month", -1),
           "pct": scope_level.get("month", -1)}
title = cfg.get("title", "${month}")
for k, v in fields.items():
    if colored.get(k, -1) >= 0:
        title = title.replace("${" + k + "}", paint(colored[k], "$" + v))  # keep the dollar sign in the span
        title = title.replace("{" + k + "}", paint(colored[k], v))
    else:
        title = title.replace("{" + k + "}", v)
if worst >= 0 and "\x1e" not in title:
    title = paint(worst, title)  # template shows no alerting value: colour the whole title
print(title)
print("---")
for line in alert_lines:
    print(line)
if alert_lines:
    print("---")
for w in wanted:
    print(f"{w}: ${tot[w]:.2f}")
    for model, usd in sorted(cost[w].items(), key=lambda x: -x[1]):
        print(f"--{model}: ${usd:.2f}")
print("---")
print(f"Budget: ${LIMIT:.0f}/month, ${budgets['day']:.0f}/day ({WORKDAYS} working days)")
print("Estimate at API list prices, this Mac only")
if unknown:
    print(f"No price for: {', '.join(sorted(unknown))}")
