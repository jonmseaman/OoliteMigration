#!/usr/bin/env bash
# Probe tools/check-selector-types.py on synthetic trees (--root): the called-by-name rule and
# its typed-IMP exemption (bead oo-bzjh), and the dispatchers' C++ signatures and
# --strict-called-by-name (bead oo-qps.34). Runs the REAL tool; nothing here re-implements it.
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

F='upstream/oolite/src/Core/Filters.mm'
A='((Filter)filterIMP)'
both() { printf 'filterA: %s %s\nfilterB: %s %s\n' "$F" "$1" "$F" "$1" >"$2/tools/typed-imp-selectors.txt"; }

# 1. Nothing listed: both typed @selector filters are called-by-name violations.
t="$work/none"; make_tree "$t" 'const oo::PList &'
expect 'unlisted typed @selector fails' 1 'CALLED BY NAME -filterA:' '' "$t"

# 2. Only filterA listed: filterA exempt, filterB (unlisted) still fails.
t="$work/one"; make_tree "$t" 'const oo::PList &'
printf 'filterA: %s %s\n' "$F" "$A" >"$t/tools/typed-imp-selectors.txt"
expect 'listed one passes, unlisted one still fails' 1 'CALLED BY NAME -filterB:' 'CALLED BY NAME -filterA:' "$t"

# 3. Both listed, anchored on the cast call: clean.
t="$work/both"; make_tree "$t" 'const oo::PList &'; both "$A" "$t"
expect 'listed typed @selectors pass' 0 'typed IMP -filterA:' 'CALLED BY NAME' "$t"

# 4. The call moved (lines inserted above it) but is intact: still passes (oo-x3t6).
t="$work/moved"; make_tree "$t" 'const oo::PList &'; both "$A" "$t"
{ printf '// moved\n// down\n// by\n// five\n// lines\n'; cat "$t/$F"; } >"$t/$F.new" && mv "$t/$F.new" "$t/$F"
expect 'a moved but intact call still passes' 0 'typed IMP -filterA:.*Filters.mm:17' 'CALLED BY NAME|TYPED-IMP' "$t"

# 5. The call was removed (the anchor is gone): not verified, fails.
t="$work/removed"; make_tree "$t" 'const oo::PList &'; both "$A" "$t"
sed -i 's|return ((Filter)filterIMP)(self, filterSelector, manifest);|return NO;|' "$t/$F"
expect 'a removed call is not verified' 1 'TYPED-IMP -filterA: not verified' 'typed IMP -filterA:' "$t"

# 5b. The listed anchor no longer matches any line (the call was rewritten): fails.
t="$work/stale"; make_tree "$t" 'const oo::PList &'; both '((Filter)oldIMP)' "$t"
expect 'a stale anchor is not verified' 1 'TYPED-IMP -filterA: not verified: anchor .* is on 0 lines' '' "$t"

# 6. The anchor names a line that does not call through the typedef: not verified, fails.
t="$work/wrongline"; make_tree "$t" 'const oo::PList &'; both 'IMP filterIMP =' "$t"
expect 'an anchor off the cast call is not verified' 1 'TYPED-IMP -filterA: not verified: .*does not call through Filter' '' "$t"

# 7. An anchor on two lines is ambiguous: not verified, fails.
t="$work/twice"; make_tree "$t" 'const oo::PList &'; both 'manifest' "$t"
expect 'an ambiguous anchor is not verified' 1 'TYPED-IMP -filterA: not verified: anchor .* is on [2-9] lines' '' "$t"

# 8. The call was retyped (the typedef's types no longer match the declarations): fails.
t="$work/sig"; make_tree "$t" 'const std::string &'; both "$A" "$t"
expect 'a retyped call is not verified' 1 'TYPED-IMP -filterA: not verified: .*has no .typedef BOOL' '' "$t"

# 9. Also sent by name from dynamic-selectors.txt: never exempt.
t="$work/dyn"; make_tree "$t" 'const oo::PList &'; both "$A" "$t"
echo 'filterA:' >"$t/tools/dynamic-selectors.txt"
expect 'a by-name source defeats the exemption' 1 'TYPED-IMP -filterA: not verified: also sent by name' '' "$t"

# make_dispatch_tree <dir> <declarations> <@selector literals> — a class whose methods a
# dispatcher calls by name (OOCallByName, ADR-0055 item 5).
make_dispatch_tree() {
	local root="$1" decls="$2" sels="$3"
	mkdir -p "$root/upstream/oolite/src/Core" "$root/tools"
	: >"$root/tools/dynamic-selectors.txt"
	printf '@interface Actions: OOObject\n%s\n@end\n\nstatic SEL kActions[] = { %s };\n' "$decls" "$sels" >"$root/upstream/oolite/src/Core/Actions.mm"
}

# expect_strict: as expect, with --strict-called-by-name.
expect_strict() {
	local label="$1" want="$2" has="$3" root="$4" out rc
	out=$(python3 "$tool" --strict-called-by-name --no-foundation --root "$root" 2>&1); rc=$?
	if [ "$rc" = "$want" ] && { [ -z "$has" ] || printf '%s\n' "$out" | grep -qE "$has"; }; then
		pass=$((pass+1)); printf 'ok   %s\n' "$label"
	else failn=$((failn+1)); printf 'FAIL %s (rc=%s)\n%s\n' "$label" "$rc" "$out"; fi
}

# 10. The dispatchers' C++ signatures pass --check (bead oo-qps.34).
t="$work/dispatch"; make_dispatch_tree "$t" '- (void) act;
- (oo::PList) query;
- (void) actWith:(const std::string &)argument;
- (oo::PList) queryWith:(const std::string &)argument;
- (void) dial:(const oo::PList &)argument;' '@selector(act), @selector(query), @selector(actWith:), @selector(queryWith:), @selector(dial:)'
expect 'the dispatcher signatures pass' 0 '' 'CALLED BY NAME' "$t"
expect_strict 'and pass --strict-called-by-name' 0 '' "$t"

# 11. Any other C++ type on a called-by-name selector still fails.
t="$work/otherc"; make_dispatch_tree "$t" '- (int) countWith:(const std::string &)argument;
- (oo::PList) dialResult:(const oo::PList &)argument;' '@selector(countWith:), @selector(dialResult:)'
expect 'a scalar result with a C++ argument fails' 1 'CALLED BY NAME -countWith:' '' "$t"
expect 'a PList argument with a PList result fails' 1 'CALLED BY NAME -dialResult:' '' "$t"

# 12. The transitional id form passes --check and fails --strict-called-by-name.
t="$work/legacy"; make_dispatch_tree "$t" '- (void) legacyAction:(id)argument;
- (id) legacyQuery;' '@selector(legacyAction:), @selector(legacyQuery)'
expect 'the id form passes --check' 0 '' 'CALLED BY NAME' "$t"
expect_strict 'the id form fails --strict-called-by-name' 1 'CALLED BY NAME -legacyAction: .*still typed id' "$t"
expect_strict 'an id result fails it too' 1 'CALLED BY NAME -legacyQuery .*still typed id' "$t"

# 13. ADR-0055 Amendment 2 (oo-qps.72): an OOObject result passes --strict-called-by-name (it is
# ignored), an NS* result does not, and a literal handed to an object dispatcher is not checked.
t="$work/objresult"; make_dispatch_tree "$t" '- (Ship *) launchShip;
- (NSString *) oldQuery;' '@selector(launchShip), @selector(oldQuery)'
expect_strict 'an NS* result fails --strict-called-by-name' 1 'CALLED BY NAME -oldQuery .*still typed id' "$t"
if python3 "$tool" --strict-called-by-name --no-foundation --root "$t" 2>&1 | grep -q 'launchShip'; then
	failn=$((failn+1)); printf 'FAIL an OOObject result is accepted
'
else pass=$((pass+1)); printf 'ok   an OOObject result is accepted
'; fi
t="$work/objdispatch"; make_dispatch_tree "$t" '- (void) fire:(Timer *)timer;
- (int) compareTo:(Timer *)other;' 'nil }; static BOOL k = (s == @selector(fire:)); static void f(id q) { [q initWithComparator:@selector(compareTo:)]; }'
expect_strict 'object-dispatched literals are not checked' 0 '' "$t"

echo
echo "probes: pass=$pass fail=$failn"
[ "$failn" -eq 0 ]
