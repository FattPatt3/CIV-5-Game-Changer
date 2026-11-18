#!/usr/bin/env bash
# Full offline test suite: syntax, database validation, simulated runs.
set -e
cd "$(dirname "$0")/.."
echo "== Lua syntax (Lua 5.1, same as Civ V)"
luac5.1 -p "Ascension Roguelite (v 1)"/Lua/*.lua "Ascension Roguelite (v 1)"/UI/*.lua && echo OK
echo "== XML well-formedness"
xmllint --noout "Ascension Roguelite (v 1)"/UI/*.xml "Ascension Roguelite (v 1)"/*.modinfo && echo OK
echo "== Database"
python3 tools/validate_db.py --export tools/sim/gameinfo_gen.lua
echo "== Simulated runs"
for sc in standard asc10 asc5life colonstore quick marathon lose short; do
  for seed in 1 2 3 4 5; do
    lua5.1 tools/sim/run_sim.lua $sc $seed
  done
done
echo "ALL TESTS PASSED"
