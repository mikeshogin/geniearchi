#!/bin/bash
# Generates ecosystem health dashboard HTML
# Usage: health-dashboard.sh [output_path]

ARCHLINT=/home/assistant/projects/archlint-repo/archlint-rs/target/release/archlint
OUTPUT=${1:-/home/assistant/projects/geniearchi/public/health/index.html}
GH=/home/assistant/bin/gh

mkdir -p "$(dirname "$OUTPUT")"

# Scan each repo and collect results as JSON array
REPOS="promptlint costlint seclint"
RESULTS="["

for repo in $REPOS; do
    REPORT=$(bash /home/assistant/projects/archlint-repo/scripts/agent-report.sh "/home/assistant/projects/$repo" 2>/dev/null)
    if [ -z "$REPORT" ] || [ "$REPORT" = "null" ]; then
        REPORT='{"components":0,"violations":0,"cycles":0,"health_score":0,"action_items":[],"summary":"scan failed"}'
    fi

    # Get CI status from GitHub API
    CI_RAW=$($GH api "repos/mikeshogin/$repo/actions/runs" --jq '.workflow_runs[:1] | .[] | {name: .name, status: .status, conclusion: .conclusion}' 2>/dev/null)
    if [ -z "$CI_RAW" ]; then
        CI_RAW='{"name":"unknown","status":"unknown","conclusion":"unknown"}'
    fi

    RESULTS="${RESULTS}{\"name\":\"$repo\",\"report\":$REPORT,\"ci\":$CI_RAW},"
done

# Remove trailing comma and close array
RESULTS="${RESULTS%,}]"

# Generate HTML with python3 and write to output file
python3 - "$RESULTS" > "$OUTPUT" << 'PYEOF'
import sys
import json
from datetime import datetime

data = json.loads(sys.argv[1])
generated = datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')

def score_color(score):
    if score >= 80:
        return '#16a34a'   # green
    elif score >= 60:
        return '#d97706'   # amber
    else:
        return '#dc2626'   # red

def score_label(score):
    if score >= 80:
        return 'Healthy'
    elif score >= 60:
        return 'Warning'
    else:
        return 'Critical'

def ci_color(conclusion):
    if conclusion == 'success':
        return '#16a34a'
    elif conclusion in ('failure', 'cancelled'):
        return '#dc2626'
    else:
        return '#64748b'

def ci_label(conclusion, status):
    if status == 'in_progress':
        return 'Running'
    if conclusion == 'success':
        return 'Passing'
    elif conclusion == 'failure':
        return 'Failing'
    elif conclusion == 'cancelled':
        return 'Cancelled'
    elif conclusion == 'unknown':
        return 'Unknown'
    else:
        return conclusion.capitalize() if conclusion else 'Unknown'

rows = ''
for item in data:
    name = item['name']
    r = item['report']
    ci = item['ci']
    score = max(0, r.get('health_score', 0))
    color = score_color(score)
    label = score_label(score)
    ci_conclusion = ci.get('conclusion', 'unknown')
    ci_status = ci.get('status', 'unknown')
    ci_c = ci_color(ci_conclusion)
    ci_l = ci_label(ci_conclusion, ci_status)
    components = r.get('components', 0)
    violations = r.get('violations', 0)
    cycles = r.get('cycles', 0)
    repo_url = f'https://github.com/mikeshogin/{name}'
    ci_url = f'https://github.com/mikeshogin/{name}/actions'

    rows += f'''
        <tr>
            <td><a href="{repo_url}" target="_blank">{name}</a></td>
            <td style="color:{color}; font-weight:600;">{score}/100 — {label}</td>
            <td>{components}</td>
            <td>{violations}</td>
            <td>{cycles}</td>
            <td><a href="{ci_url}" target="_blank" style="color:{ci_c}; font-weight:600;">{ci_l}</a></td>
        </tr>'''

html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GenieArchi - Ecosystem Health</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            max-width: 900px;
            margin: 0 auto;
            padding: 2rem;
            line-height: 1.6;
            color: #1e293b;
            background: #f8fafc;
        }}
        h1 {{
            text-align: center;
            font-size: 2rem;
            margin-bottom: 0.5rem;
            color: #0f172a;
        }}
        .subtitle {{
            text-align: center;
            color: #64748b;
            margin-bottom: 2rem;
            font-size: 1rem;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            background: #fff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 1px 4px rgba(0,0,0,0.08);
            margin: 1.5rem 0;
        }}
        th, td {{
            padding: 0.85rem 1rem;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
            font-size: 0.95rem;
        }}
        th {{
            background: #f1f5f9;
            font-weight: 600;
            color: #475569;
            font-size: 0.85rem;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }}
        tr:last-child td {{ border-bottom: none; }}
        tr:hover td {{ background: #f8fafc; }}
        a {{ color: #2563eb; text-decoration: none; }}
        a:hover {{ text-decoration: underline; }}
        .back {{
            text-align: center;
            margin-top: 2rem;
        }}
        .updated {{
            text-align: center;
            color: #94a3b8;
            font-size: 0.82rem;
            margin-top: 1.5rem;
        }}
        .legend {{
            display: flex;
            gap: 1.5rem;
            justify-content: center;
            margin-bottom: 1rem;
            font-size: 0.85rem;
        }}
        .legend-item {{ display: flex; align-items: center; gap: 0.4rem; }}
        .dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            display: inline-block;
        }}
    </style>
</head>
<body>
    <h1>Ecosystem Health Dashboard</h1>
    <p class="subtitle">Architecture scores and CI status for GenieArchi repos</p>

    <div class="legend">
        <span class="legend-item"><span class="dot" style="background:#16a34a"></span> Healthy (80-100)</span>
        <span class="legend-item"><span class="dot" style="background:#d97706"></span> Warning (60-79)</span>
        <span class="legend-item"><span class="dot" style="background:#dc2626"></span> Critical (&lt;60)</span>
    </div>

    <table>
        <thead>
            <tr>
                <th>Repo</th>
                <th>Health Score</th>
                <th>Components</th>
                <th>Violations</th>
                <th>Cycles</th>
                <th>CI Status</th>
            </tr>
        </thead>
        <tbody>{rows}
        </tbody>
    </table>

    <div class="back">
        <a href="/">&larr; Back to GenieArchi</a>
        &nbsp;&nbsp;|&nbsp;&nbsp;
        <a href="/status/">Ecosystem Status</a>
    </div>
    <p class="updated">Generated: {generated}</p>
</body>
</html>'''

print(html)
PYEOF
