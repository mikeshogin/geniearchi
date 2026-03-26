#!/bin/bash
# Persistent daily budget tracker for GenieArchi ecosystem
# Usage:
#   budget.sh status                    - show current budget
#   budget.sh add TYPE TOKENS COST      - record transaction
#   budget.sh reset                     - reset for new day
#   budget.sh check                     - check if over 80%, return exit code 1 if over budget

BUDGET_FILE="/home/assistant/projects/geniearchi/daily-budget.json"
MAX_USD=5.00
TODAY=$(date '+%Y-%m-%d')

# Initialize budget file if it doesn't exist
init_budget_file() {
    python3 -c "
import json
data = {
    'date': '${TODAY}',
    'max_usd': ${MAX_USD},
    'used_usd': 0.00,
    'transaction_count': 0,
    'transactions': []
}
with open('${BUDGET_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
print('Budget initialized for ${TODAY}')
"
}

# Auto-reset if date changed
auto_reset_if_new_day() {
    if [ ! -f "$BUDGET_FILE" ]; then
        init_budget_file
        return
    fi

    python3 -c "
import json, sys
with open('${BUDGET_FILE}', 'r') as f:
    data = json.load(f)

if data.get('date') != '${TODAY}':
    data = {
        'date': '${TODAY}',
        'max_usd': ${MAX_USD},
        'used_usd': 0.00,
        'transaction_count': 0,
        'transactions': []
    }
    with open('${BUDGET_FILE}', 'w') as f:
        json.dump(data, f, indent=2)
    print('Budget auto-reset for new day: ${TODAY}')
"
}

cmd_status() {
    auto_reset_if_new_day
    python3 -c "
import json
with open('${BUDGET_FILE}', 'r') as f:
    data = json.load(f)

used = data.get('used_usd', 0.0)
max_usd = data.get('max_usd', ${MAX_USD})
remaining = max_usd - used
pct_used = (used / max_usd * 100) if max_usd > 0 else 0
count = data.get('transaction_count', 0)

print(f'Date:          {data[\"date\"]}')
print(f'Max budget:    \${max_usd:.2f}')
print(f'Used:          \${used:.4f}')
print(f'Remaining:     \${remaining:.4f}')
print(f'Percent used:  {pct_used:.1f}%')
print(f'Transactions:  {count}')

if pct_used >= 100:
    print('STATUS: OVER BUDGET')
elif pct_used >= 80:
    print('STATUS: WARNING - over 80%')
else:
    print('STATUS: OK')
"
}

cmd_add() {
    local tx_type="$1"
    local tokens="$2"
    local cost="$3"

    if [ -z "$tx_type" ] || [ -z "$tokens" ] || [ -z "$cost" ]; then
        echo "Usage: budget.sh add TYPE TOKENS COST"
        echo "Example: budget.sh add moldbook_comment 150 0.003"
        exit 1
    fi

    auto_reset_if_new_day

    python3 -c "
import json
from datetime import datetime, timezone

with open('${BUDGET_FILE}', 'r') as f:
    data = json.load(f)

tx = {
    'type': '${tx_type}',
    'tokens': ${tokens},
    'cost_usd': ${cost},
    'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
}

data['transactions'].append(tx)
data['used_usd'] = round(data.get('used_usd', 0.0) + ${cost}, 6)
data['transaction_count'] = len(data['transactions'])

with open('${BUDGET_FILE}', 'w') as f:
    json.dump(data, f, indent=2)

used = data['used_usd']
max_usd = data['max_usd']
remaining = max_usd - used
pct_used = (used / max_usd * 100) if max_usd > 0 else 0

print(f'Transaction recorded: {tx[\"type\"]} | tokens={tx[\"tokens\"]} | cost=\${tx[\"cost_usd\"]:.4f}')
print(f'Budget: \${used:.4f} / \${max_usd:.2f} ({pct_used:.1f}% used, \${remaining:.4f} remaining)')
"
}

cmd_reset() {
    python3 -c "
import json
data = {
    'date': '${TODAY}',
    'max_usd': ${MAX_USD},
    'used_usd': 0.00,
    'transaction_count': 0,
    'transactions': []
}
with open('${BUDGET_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
print('Budget reset for ${TODAY}')
"
}

cmd_check() {
    auto_reset_if_new_day
    python3 - <<'PYEOF'
import json, sys

BUDGET_FILE = "/home/assistant/projects/geniearchi/daily-budget.json"

with open(BUDGET_FILE, 'r') as f:
    data = json.load(f)

used = data.get('used_usd', 0.0)
max_usd = data.get('max_usd', 5.0)
remaining = max_usd - used
pct_used = (used / max_usd * 100) if max_usd > 0 else 0

if pct_used >= 100:
    print(f"OVER BUDGET: ${used:.4f} / ${max_usd:.2f} ({pct_used:.1f}% used)")
    sys.exit(2)
elif pct_used >= 80:
    print(f"WARNING: Budget at {pct_used:.1f}% (${used:.4f} / ${max_usd:.2f}, ${remaining:.4f} remaining)")
    sys.exit(1)
else:
    print(f"OK: Budget at {pct_used:.1f}% (${used:.4f} / ${max_usd:.2f}, ${remaining:.4f} remaining)")
    sys.exit(0)
PYEOF
}

# Main dispatch
case "$1" in
    status)
        cmd_status
        ;;
    add)
        cmd_add "$2" "$3" "$4"
        ;;
    reset)
        cmd_reset
        ;;
    check)
        cmd_check
        ;;
    *)
        echo "Usage: budget.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  status                    Show current budget status"
        echo "  add TYPE TOKENS COST      Record a transaction"
        echo "  reset                     Reset budget for new day"
        echo "  check                     Check budget health (exit 0=ok, 1=warning, 2=over)"
        echo ""
        echo "Examples:"
        echo "  budget.sh status"
        echo "  budget.sh add moldbook_comment 150 0.003"
        echo "  budget.sh check"
        exit 1
        ;;
esac
