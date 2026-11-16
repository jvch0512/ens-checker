#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 2
BIN=build/ens-checker
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
exp() { local name=$1 want=$2; shift 2; "$BIN" "$@" >/dev/null 2>&1; local got=$?; [ "$got" = "$want" ] && ok "$name" || bad "$name (got $got, want $want)"; }
D="--today 2026-11-16"
exp "default exit 0" 0 examples $D
exp "fail-on high" 1 examples $D --fail-on high
exp "fail-on critical" 0 examples $D --fail-on critical
exp "clean file passes" 0 examples/gov-core.facts $D --fail-on medium
exp "missing path" 2 "$T/none"
exp "bad flag" 2 --bogus
exp "no args" 2
exp "bad fail-on" 2 examples --fail-on low
exp "bad today" 2 examples --today nope
exp "two paths" 2 examples examples
"$BIN" examples $D --tsv | head -1 | grep -q '^# 3 files, 10 findings$' && ok "tsv header" || bad "tsv header"
"$BIN" examples $D --tsv | sed -n 2p | awk -F'\t' 'NF==4{exit 0} {exit 1}' && ok "tsv columns" || bad "tsv columns"
"$BIN" examples $D | head -1 | grep -q '^3 files, 10 findings$' && ok "human header" || bad "human header"
printf 'category: ALTA\nmfa_admin: no\n' > "$T/one.facts"
"$BIN" "$T/one.facts" $D --tsv | grep -q $'\tENS002\tone.facts:2\t' && ok "single file label" || bad "single file label"
head -c 2000 /dev/urandom > "$T/bin.facts"
"$BIN" "$T/bin.facts" $D >/dev/null 2>&1; [ $? -le 1 ] && ok "binary input survives" || bad "binary input"
exit $fail
