#!/usr/bin/env bash
# Unit-tests the OPA policies against sample inputs. Needs conftest on PATH.
# Usage: ./scripts/test-policies.sh
set -uo pipefail
cd "$(dirname "$0")/.."
T=policy/testdata
fail=0

expect() {  # expect <pass|fail> <label> -- <conftest args...>
  local want=$1 label=$2; shift 3
  if conftest test --no-color --policy "$1" --data policy/data.json "$2" >/tmp/policy-out.txt 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$want" ]; then echo "PASS  $label (expected $want)"; else echo "FAIL  $label (expected $want, got $got)"; cat /tmp/policy-out.txt; fail=1; fi
}

expect pass "good plan"                    -- policy/plan $T/tfplan-good.json
expect fail "missing cost_center tag"      -- policy/plan $T/tfplan-missing-tags.json
expect fail "oversized VM (D8s_v5)"        -- policy/plan $T/tfplan-big-vm.json
expect pass "cost within budget"           -- policy/cost $T/infracost-ok.json
expect pass "cost near budget (warns)"     -- policy/cost $T/infracost-near-budget.json
expect fail "cost over budget"             -- policy/cost $T/infracost-over-budget.json

exit $fail
