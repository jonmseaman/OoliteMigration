#!/usr/bin/env bash
# Probe tools/check-selector-types.py on synthetic trees (--root): the called-by-name rule and
# its typed-IMP exemption (bead oo-bzjh). Runs the REAL tool; nothing here re-implements it.
#
#     bash tools/check-selector-types-probe.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
tool="$here/check-selector-types.py"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0; failn=0

# make_tree <dir> <typedef param list> — a class with two typed filters picked by @selector and
# called through a typedef'd IMP (the OOOXZManager shape).
make_tree() {
	local root="$1" params="$2"
	mkdir -p "$root/upstream/oolite/src/Core" "$root/tools"
	: >"$root/tools/dynamic-selectors.txt"
	cat >"$root/upstream/oolite/src/Core/Filters.mm" <<EOF
@interface Filters: OOObject
- (BOOL) filterA:(const oo::PList &)manifest;
- (BOOL) filterB:(const oo::PList &)manifest;
@end

@implementation Filters
- (BOOL) run:(BOOL)useA manifest:(const oo::PList &)manifest
{
	SEL filterSelector = useA ? @selector(filterA:) : @selector(filterB:);
	typedef BOOL (*Filter)(id, SEL, $params);
	IMP filterIMP = [self methodForSelector:filterSelector];
	return ((Filter)filterIMP)(self, filterSelector, manifest);
}
@end
EOF
}

# expect <label> <want rc> <must-contain regex or ""> <must-not-contain regex or ""> <root>
expect() {
	local label="$1" want="$2" has="$3" hasnt="$4" root="$5" out rc ok=1
	out=$(python3 "$tool" --check --no-foundation --root "$root" 2>&1); rc=$?
	[ "$rc" = "$want" ] || ok=0
	[ -z "$has" ] || printf '%s\n' "$out" | grep -qE "$has" || ok=0
	[ -z "$hasnt" ] || ! printf '%s\n' "$out" | grep -qE "$hasnt" || ok=0
	if [ "$ok" = 1 ]; then pass=$((pass+1)); printf 'ok   %s\n' "$label"
	else failn=$((failn+1)); printf 'FAIL %s (rc=%s)\n%s\n' "$label" "$rc" "$out"; fi
}

# 1. Nothing listed: both typed @selector filters are called-by-name violations.
t="$work/none"; make_tree "$t" 'const oo::PList &'
expect 'unlisted typed @selector fails' 1 'CALLED BY NAME -filterA:' '' "$t"

# 2. Only filterA listed: filterA exempt, filterB (unlisted) still fails.
t="$work/one"; make_tree "$t" 'const oo::PList &'
echo 'filterA: upstream/oolite/src/Core/Filters.mm:12' >"$t/tools/typed-imp-selectors.txt"
expect 'listed one passes, unlisted one still fails' 1 'CALLED BY NAME -filterB:' 'CALLED BY NAME -filterA:' "$t"

# 3. Both listed with the right cast line: clean.
t="$work/both"; make_tree "$t" 'const oo::PList &'
printf 'filterA: upstream/oolite/src/Core/Filters.mm:12\nfilterB: upstream/oolite/src/Core/Filters.mm:12\n' >"$t/tools/typed-imp-selectors.txt"
expect 'listed typed @selectors pass' 0 'typed IMP -filterA:' 'CALLED BY NAME' "$t"

# 4. Wrong line in the list: not verified, fails.
t="$work/line"; make_tree "$t" 'const oo::PList &'
printf 'filterA: upstream/oolite/src/Core/Filters.mm:3\nfilterB: upstream/oolite/src/Core/Filters.mm:12\n' >"$t/tools/typed-imp-selectors.txt"
expect 'wrong cast line is not verified' 1 'TYPED-IMP -filterA: not verified' '' "$t"

# 5. The typedef's types do not match the declarations: not verified, fails.
t="$work/sig"; make_tree "$t" 'const std::string &'
printf 'filterA: upstream/oolite/src/Core/Filters.mm:12\nfilterB: upstream/oolite/src/Core/Filters.mm:12\n' >"$t/tools/typed-imp-selectors.txt"
expect 'mismatched typedef is not verified' 1 'TYPED-IMP -filterA: not verified: .*has no .typedef BOOL' '' "$t"

# 6. Also sent by name from dynamic-selectors.txt: never exempt.
t="$work/dyn"; make_tree "$t" 'const oo::PList &'
printf 'filterA: upstream/oolite/src/Core/Filters.mm:12\nfilterB: upstream/oolite/src/Core/Filters.mm:12\n' >"$t/tools/typed-imp-selectors.txt"
echo 'filterA:' >"$t/tools/dynamic-selectors.txt"
expect 'a by-name source defeats the exemption' 1 'TYPED-IMP -filterA: not verified: also sent by name' '' "$t"

echo
echo "probes: pass=$pass fail=$failn"
[ "$failn" -eq 0 ]
