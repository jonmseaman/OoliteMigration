#!/usr/bin/env bash
# tools/check-foundation-free.sh — the ABSOLUTE Foundation check oo-qps needs (bead oo-qps.1).
#
# tools/deny-list.txt is per changed file and relative to the merge base, so it can stop a file
# growing a Foundation use back but can never say "none are left"; and its ERE cannot say "any NS*
# name except the ones oofnd/objc/OOFoundationTypes.h keeps" (no negative lookahead). This script
# says both, over the whole tree, and is the Phase 2 progress meter:
#
#     bash tools/check-foundation-free.sh                  # = --stage sweeps: the census
#     bash tools/check-foundation-free.sh --stage source   # no exemptions (after oo-qps.4-.17)
#     bash tools/check-foundation-free.sh --link <exe>     # PE import table names no gnustep-base
#     bash tools/check-foundation-free.sh --selftest       # proof each check fails and passes
#     ... --root <dir>                                     # scan <dir> instead of upstream/oolite/src
#
# --stage sweeps reports, per file under upstream/oolite/src minus src/oofnd (comment lines ignored;
# the ns and oolog scans read the line with /* ... */, a trailing // and the contents of "...", '...'
# and @"..." removed, ADR-0054 item 2):
#   ns        every NS[A-Z]... identifier not on the OOFoundationTypes.h allow-list below
#   import    a Foundation header import or include
#   bridge    an X+FoundationBridge / X+OODefaultsBridge file, or an include of one
#   oolog     a call of the NSString OOLog API (OOLog, OOLogERR/WARN, OODebugLog, ...); a kOOLog*
#             constant is not one by itself (a const char * class is OO_LOG's own form)
# and exempts the boundary headers oo-qps's own children delete (BOUNDARY below), the post-gate
# owners (ADR-0054 item 3: OOCollectionExtractors in BOUNDARY; the NSLog-hook bridge files and their
# #import, POSTGATE_BRIDGE; the two ADR-0052 NSString declarations/definitions in OOStringExpander,
# POSTGATE_EXPANDER) and, everywhere, the transitional helper spellings (oo::NS*, NSStringFrom).
# In both stages, ns and oolog tokens on a line in an active #if/#elif group whose condition is a
# FENCE macro (alone or as an && conjunct), or in the #else of #if !<FENCE macro>, are Mac-only code
# deferred to Phase 5 (ADR-0043 item 18(b), ADR-0054 item 1): not findings, but counted for
# information as "mac-fenced (Phase 5)". #ifdef, || and other negations are not fences.
# --stage source drops every other exemption and adds:
#   boundary  a boundary header still present, or an include of one, or a helper call
#   build     gnustep-base named in the meson build files or tools/setup-windows.sh
# Exit 0 iff nothing is reported. Output: one line per file ("path: N  kind:token xK ..."), then a
# per-kind and per-token summary. @"..." literals are counted for information only: ADR-0029 keeps
# them (they become OOConstantString), so they are never a finding.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/.." && pwd)"
self="$script_dir/$(basename "${BASH_SOURCE[0]}")"

# The names OOFoundationTypes.h keeps after oo-qps (ADR-0029, oo-3rb.21), plus Oolite's own
# functions that merely start with NS (not Foundation API).
ALLOW='NSInteger NSUInteger NSIntegerMax NSIntegerMin NSUIntegerMax NSNotFound NSTimeInterval
NSPoint NSSize NSRect NSZeroPoint NSZeroSize NSZeroRect NSRange NSMakeRange NSMaxRange
NSLocationInRange NSEqualRanges NSMakePoint NSMakeSize NSMakeRect NSEqualPoints NSEqualSizes
NSEqualRects NSPointToVectorJSValue'
# Deleted or retyped by oo-qps's children, so the sweeps stage does not count them.
BOUNDARY='OOCocoa.h OOCocoa.mm OOFoundationException.h OOStringBridge.h OOFoundationBridge.h
OOPListView.h OOObjectGNUstepBridge.h OOObjectGNUstepBridge.mm OOEnumerationShuffle.h
OOEnumerationShuffle.mm OOManifestProperties.h OOTypes.h OOFunctionAttributes.h OOLogging.h
OOLogging.mm OOCollectionExtractors.h OOCollectionExtractors.mm'
# Post-gate owners (ADR-0054 item 3), exempt at the sweeps stage only. OOCollectionExtractors (oo-snzn)
# is in BOUNDARY above. The NSLog-hook bridge (oo-qps.28) is exempt from bridge and ns findings, and
# so is its one #import in OOLogOutputHandler.h:
POSTGATE_BRIDGE='OOLogOutputHandler+FoundationBridge.h OOLogOutputHandler+FoundationBridge.mm'
# In these files only the declaration/definition lines of the two ADR-0052 functions (oo-qps.29):
POSTGATE_EXPANDER='OOStringExpander.h OOStringExpander.mm'
POSTGATE_EXPANDER_LINE='^NSString [*](OOExpandDescriptionString|OOGenerateSystemDescription)[(]'
# The Mac fence macros (ADR-0043 item 18(b)); adding one is an amendment to ADR-0054.
FENCE='OOLITE_MAC_OS_X OOLITE_USE_APPKIT_LOAD_SAVE'
BUILD_FILES=(upstream/oolite/src/meson upstream/oolite/src/meson.build upstream/oolite/meson.build
	tools/setup-windows.sh)

usage() { sed -n '9,14p' "$self" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# scan <root> <stage> [build files...]: prints the report, returns 1 if anything was found.
scan() {
	local root="$1" stage="$2"; shift 2
	[ -d "$root" ] || { echo "FAIL: no source tree at $root" >&2; return 2; }
	local list
	list="$(cd "$root" && find . -type f \( -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.hpp' \
		-o -name '*.c' -o -name '*.cpp' -o -name '*.inc' \) -not -path './oofnd/*' | sed 's|^\./||' | LC_ALL=C sort)"
	[ -n "$list" ] || { echo "FAIL: no sources under $root (anti-vacuity)" >&2; return 2; }
	local build_hits=""
	if [ "$stage" = source ] && [ $# -gt 0 ]; then
		build_hits="$(grep -rnE 'gnustep[-]base' "$@" 2>/dev/null || true)"
	fi
	# The file list goes in through a file, not argv: one awk process whatever the tree's size
	# (xargs would split a long list into several runs, each with its own summary and exit code).
	local lf; lf="$(mktemp "${TMPDIR:-${TEMP:-/tmp}}/oo-ff-list.XXXXXX")" || return 2
	printf '%s\n' "$list" > "$lf"
	(cd "$root" && awk -v listfile="$lf" \
		-v stage="$stage" -v allow="$ALLOW" -v boundary="$BOUNDARY" \
		-v pgbridge="$POSTGATE_BRIDGE" -v pgexp="$POSTGATE_EXPANDER" -v pgexpline="$POSTGATE_EXPANDER_LINE" \
		-v fence="$FENCE" -v build_hits="$build_hits" '
	BEGIN {
		n = split(allow, a, /[ \n]+/); for (i = 1; i <= n; i++) ok[a[i]] = 1
		n = split(boundary, b, /[ \n]+/); for (i = 1; i <= n; i++) bnd[b[i]] = 1
		n = split(pgbridge, b, /[ \n]+/); for (i = 1; i <= n; i++) pgb[b[i]] = 1
		n = split(pgexp, b, /[ \n]+/); for (i = 1; i <= n; i++) pge[b[i]] = 1
		n = split(fence, b, /[ \n]+/); for (i = 1; i <= n; i++) fmac[b[i]] = 1
		files = 0; found = 0; literals = 0; macfenced = 0
		while ((getline f < listfile) > 0) if (f != "") ARGV[ARGC++] = f
		close(listfile)
	}
	function base(p,   q) { q = p; sub(/.*\//, "", q); return q }
	function hit(kind, tok) {
		if (fenced && (kind == "ns" || kind == "oolog")) { macfenced += 1; return }
		if (pgfile && (kind == "ns" || kind == "bridge")) return
		cnt[FILENAME] += 1; what[FILENAME, kind ":" tok] += 1
		if (!((FILENAME, kind ":" tok) in seen)) { seen[FILENAME, kind ":" tok] = 1; order[FILENAME] = order[FILENAME] " " kind ":" tok }
		bykind[kind] += 1; bytok[kind ":" tok] += 1; found += 1 }
	# strip(l): l with comments removed and literal contents emptied; inblk carries /* across lines.
	function strip(l,   out, q, m) {
		out = ""
		while (l != "") {
			if (inblk) { m = index(l, "*/"); if (!m) return out; inblk = 0; l = substr(l, m + 2); out = out " "; continue }
			if (!match(l, /\/\*|\/\/|["\047]/)) return out l
			out = out substr(l, 1, RSTART - 1); q = substr(l, RSTART, RLENGTH); l = substr(l, RSTART + RLENGTH)
			if (q == "//") return out
			if (q == "/*") { inblk = 1; continue }
			if (q == "\"" && match(l, /^([^"\\]|\\.)*"/)) { out = out q q; l = substr(l, RLENGTH + 1) }
			else if (q == "\"") return out q q          # unterminated: the rest is literal
			else if (match(l, /^([^\047\\]|\\.)*\047/)) { out = out q q; l = substr(l, RLENGTH + 1) }
			else out = out q                            # a lone quote (digit separator): keep scanning
		}
		return out
	}
	# isfence(c): the #if/#elif condition c is a FENCE macro alone or as an && conjunct (no ||).
	function isfence(c,   k, p, i) {
		if (c ~ /\|\|/) return 0
		k = split(c, p, /&&/)
		for (i = 1; i <= k; i++) { gsub(/^[ \t(]+|[ \t)]+$/, "", p[i]); if (p[i] in fmac) return 1 }
		return 0
	}
	# negfence(c): c is exactly !<FENCE macro>, so its #else is fenced.
	function negfence(c) { gsub(/^[ \t(]+|[ \t)]+$/, "", c); if (c !~ /^![ \t]*[A-Za-z_]/) return 0
		sub(/^![ \t]*/, "", c); return (c in fmac) }
	# directive(c): track the #if stack from a comment-stripped line; fenced = any open group fenced.
	function directive(c,   d, rest, i) {
		if (c !~ /^[ \t]*#[ \t]*(if|ifdef|ifndef|elif|else|endif)([^A-Za-z0-9_]|$)/) return
		d = c; sub(/^[ \t]*#[ \t]*/, "", d); rest = d; sub(/^[a-z]+/, "", rest); sub(/[^a-z].*$/, "", d)
		if (d == "if") { depth++; fr[depth] = isfence(rest); neg[depth] = negfence(rest) }
		else if (d == "ifdef" || d == "ifndef") { depth++; fr[depth] = 0; neg[depth] = 0 }
		else if (depth == 0) return
		else if (d == "elif") fr[depth] = isfence(rest)
		else if (d == "else") fr[depth] = neg[depth]
		else depth--
		fenced = 0; for (i = 1; i <= depth; i++) if (fr[i]) fenced = 1
	}
	FNR == 1 {
		files++
		exempt = (stage == "sweeps" && (base(FILENAME) in bnd))
		pgfile = (stage == "sweeps" && (base(FILENAME) in pgb))
		pgexpfile = (stage == "sweeps" && (base(FILENAME) in pge))
		inblk = 0; depth = 0; fenced = 0
		if (FILENAME ~ /\+(FoundationBridge|OODefaultsBridge)\./) hit("bridge", "file")
		else if (stage == "source" && (base(FILENAME) in bnd) && base(FILENAME) !~ /^OO(Cocoa|Logging|Types|FunctionAttributes|CollectionExtractors)\./) hit("boundary", "file")
	}
	{ line = $0; literals += gsub(/@"/, "@\"", line); code = strip($0); directive(code) }
	exempt { next }
	/^[ \t]*(\/\/|\/\*|\*)/ { next }
	{
		line = $0
		if (line ~ /#[ \t]*(import|include)[ \t]*<Foundation\//) hit("import", "Foundation")
		if (line ~ /#[ \t]*(import|include)[ \t]*"[^"]*\+(FoundationBridge|OODefaultsBridge)\.h"/ &&
			!(stage == "sweeps" && line ~ /^[ \t]*#[ \t]*import[ \t]*"OOLogOutputHandler\+FoundationBridge\.h"/)) hit("bridge", "include")
		if (stage == "source" && line ~ /#[ \t]*(import|include)[ \t]*"(OOStringBridge|OOFoundationBridge|OOPListView|OOFoundationException|OOObjectGNUstepBridge|OOEnumerationShuffle)\.h"/) hit("boundary", "include")
		if (stage == "source" && line ~ /OOFoundationException|oo::PListView|(^|[^A-Za-z0-9_])StdString\(/) hit("boundary", "helper")
		if (pgexpfile && line ~ pgexpline) next
		s = code
		while (match(s, /(^|[^A-Za-z0-9_])OOLog(ERR|WARN|WithArguments|IndentIf|OutdentIf)?[ \t]*\(|(^|[^A-Za-z0-9_])OO(Debug|Extra)Log[ \t]*\(/)) {
			t = substr(s, RSTART, RLENGTH); gsub(/^[^A-Za-z]|[ \t(]+$/, "", t); hit("oolog", t); s = substr(s, RSTART + RLENGTH) }
		s = code
		while (match(s, /(oo::)?NS[A-Z][A-Za-z0-9_]*/)) {
			t = substr(s, RSTART, RLENGTH); pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
			s = substr(s, RSTART + RLENGTH)
			if (pre ~ /[A-Za-z0-9_]/) continue          # inside a longer identifier (cxx_NS..., OONS...)
			if (t ~ /^oo::/ || t ~ /^NSStringFrom/) { if (stage == "source") hit("boundary", t); continue }
			if (!(t in ok)) hit("ns", t)
		}
	}
	END {
		for (f in cnt) { printf "%s: %d %s\n", f, cnt[f], order[f] | "LC_ALL=C sort" }
		close("LC_ALL=C sort")
		nb = split(build_hits, bl, "\n")
		for (i = 1; i <= nb; i++) if (bl[i] != "") { print "build: " bl[i]; bykind["build"] += 1; found += 1 }
		printf "== %s stage: %d finding(s) in %d file(s) scanned; @\"...\" literals (information only): %d; mac-fenced (Phase 5, information only): %d\n", stage, found, files, literals, macfenced
		for (k in bykind) printf "   %-9s %6d\n", k, bykind[k] | "LC_ALL=C sort"
		close("LC_ALL=C sort")
		for (k in bytok) printf "%6d  %s\n", bytok[k], k | "LC_ALL=C sort -rn | head -25"
		close("LC_ALL=C sort -rn | head -25")
		exit (found > 0)
	}'); local rc=$?
	rm -f "$lf"
	return $rc
}

# link <exe>: every DLL in the import table of <exe>, and of each DLL beside it that it imports.
link_check() {
	local exe="$1" objdump="${OO_FF_OBJDUMP:-objdump}"
	[ -f "$exe" ] || { echo "FAIL: no executable at $exe" >&2; return 2; }
	local dir; dir="$(dirname "$exe")"
	local -A seen=()
	local queue=("$exe") bad="" all=""
	while [ ${#queue[@]} -gt 0 ]; do
		local f="${queue[0]}"; queue=("${queue[@]:1}")
		[ -n "${seen[$f]:-}" ] && continue; seen[$f]=1
		local imports
		imports="$("$objdump" -p "$f" | sed -n 's/^[[:space:]]*DLL Name:[[:space:]]*//p' | tr -d '\r')" ||
			{ echo "FAIL: $objdump -p $f" >&2; return 2; }
		[ -n "$imports" ] || { echo "FAIL: $f has an empty import table (not a PE image?)" >&2; return 2; }
		local d
		while IFS= read -r d; do
			all="$all $d"
			# case (not `printf | grep -q`): under pipefail a successful grep -q can
			# SIGPIPE the producer and report 141 (oo-kw6r / test_guardrails_pipefail).
			case "${d,,}" in
				*gnustep-base*) bad="$bad $(basename "$f")->$d" ;;
			esac
			[ -f "$dir/$d" ] && queue+=("$dir/$d")
		done <<<"$imports"
	done
	if [ -n "$bad" ]; then echo "FAIL: gnustep-base in the import table:$bad"; return 1; fi
	echo "OK: $(basename "$exe") and its local DLLs import no gnustep-base ($(printf '%s\n' $all | sort -u | grep -vci '^api-ms-win') DLLs)"
}

selftest() {
	local tmp="${TMPDIR:-${TEMP:-/tmp}}"
	local t; t="$(mktemp -d "$tmp/oo-foundation-free-selftest.XXXXXX")" || exit 1
	trap 'rm -rf "$t"' RETURN
	local fail=0 cases=0
	expect() {   # expect <rc> <name> <cmd...>
		local want="$1" name="$2"; shift 2; cases=$((cases + 1))
		local out rc; out="$("$@" 2>&1)"; rc=$?
		if [ "$rc" = "$want" ]; then echo "PASS: $name"; else echo "FAIL: $name (rc $rc, want $want)"; printf '%s\n' "$out" | tail -8; fail=1; fi
	}
	# Forbidden spellings are assembled so this file never contains them (the deny-list scans it).
	local imp="#im""port <Found""ation/Found""ation.h>" gs="gnustep""-base"
	mk() { mkdir -p "$t/$1/Core"; printf '%s\n' "${@:2}" > "$t/$1/Core/X.mm"; }
	mk clean '#import "OOCocoa.h"' 'static NSInteger a; NSRange r = NSMakeRange(0, 1); NSPoint p;' \
		'// an NSString in a comment is not a use' 'id s = @"literal"; OO_LOG("x", "{}", 1); cxx_NSStringy();' \
		'static const char *const kOOLogThing = "thing"; OO_LOG(kOOLogThing, "{}", 2);'
	expect 0 "allow-list names, comments, literals and OO_LOG pass" scan "$t/clean" sweeps
	mk ns 'NSString *s = nil;'
	expect 1 "an NSString use fails" scan "$t/ns" sweeps
	mk assert 'NSAssert(x, @"y");'
	expect 1 "an NSAssert fails (not in the core-six grep)" scan "$t/assert" sweeps
	mk imp "$imp"
	expect 1 "a Foundation import fails" scan "$t/imp" sweeps
	mk oolog 'OOLog(@"a", @"b %@", x);'
	expect 1 "an OOLog call fails" scan "$t/oolog" sweeps
	mk ext 'OOExtraLog(kOOLogFileNotFound, @"b");'
	expect 1 "an OOExtraLog call fails" scan "$t/ext" sweeps
	mk br '#import "X+FoundationBridge.h"'
	expect 1 "a bridge include fails" scan "$t/br" sweeps
	mkdir -p "$t/brf/Core"; printf 'int x;\n' > "$t/brf/Core/X+FoundationBridge.mm"
	expect 1 "a bridge file fails" scan "$t/brf" sweeps
	mk help 'std::string s = StdString(x); id y = oo::NSStringFrom(s); oo::PListView v(d);'
	expect 0 "helper calls are exempt in the sweeps stage" scan "$t/help" sweeps
	expect 1 "helper calls fail in the source stage" scan "$t/help" source
	mkdir -p "$t/bnd/Core"; printf 'NSString *OOStr(void);\n' > "$t/bnd/Core/OOStringBridge.h"
	expect 0 "a boundary header is exempt in the sweeps stage" scan "$t/bnd" sweeps
	expect 1 "a boundary header fails in the source stage" scan "$t/bnd" source
	mkdir -p "$t/oofnd/oofnd" "$t/oofnd/Core"; printf 'NSString *s;\n' > "$t/oofnd/oofnd/X.mm"; printf 'int x;\n' > "$t/oofnd/Core/Y.mm"
	expect 0 "src/oofnd is out of scope" scan "$t/oofnd" sweeps
	# ADR-0054 item 1: the Mac fence skips ns/oolog tokens; the same names outside a fence still fail.
	mk mac '#if OOLITE_MAC_OS_X' 'NSString *s; OOLog(@"a", @"b");' '#elif OOLITE_USE_APPKIT_LOAD_SAVE' 'NSSavePanel *p;' \
		'#endif' '#if OOLITE_SPEECH_SYNTH && (OOLITE_MAC_OS_X)' 'NSSpeechSynthesizer *v;' '#endif' \
		'#if !OOLITE_MAC_OS_X' 'int x;' '#else' 'NSApplication *a;' '#endif'
	expect 0 "an OOLITE_MAC_OS_X block is skipped" scan "$t/mac" sweeps
	expect 0 "the source stage skips the Mac fence too" scan "$t/mac" source
	mk macelse '#if OOLITE_MAC_OS_X' 'int x;' '#else' 'NSString *s;' '#endif'
	expect 1 "the #else of an OOLITE_MAC_OS_X block is counted" scan "$t/macelse" sweeps
	mk macneg '#if !OOLITE_MAC_OS_X' 'NSString *s;' '#endif'
	expect 1 "an #if !OOLITE_MAC_OS_X block is counted" scan "$t/macneg" sweeps
	mk macifdef '#ifdef OOLITE_MAC_OS_X' 'NSString *s;' '#endif'
	expect 1 "an #ifdef OOLITE_MAC_OS_X block is counted (not a fence)" scan "$t/macifdef" sweeps
	mk macor '#if OOLITE_MAC_OS_X || OOLITE_WINDOWS' 'NSString *s;' '#endif'
	expect 1 "an OOLITE_MAC_OS_X || ... block is counted (not a fence)" scan "$t/macor" sweeps
	mk macend '#if OOLITE_MAC_OS_X' '#if X' '#endif' '#endif' 'NSString *s;'
	expect 1 "a name after the #endif of an OOLITE_MAC_OS_X block is counted" scan "$t/macend" sweeps
	# ADR-0054 item 2: comments and literals are stripped before the ns and oolog scans.
	mk lit '#import "NSObjectOOExtensions.h"' 'x = 1; /* an NSString here,' 'the NSArray here */ y = 2;' \
		'z = 3; // a trailing NSDictionary' 'const char *m = "NSTimer ignoring"; char c = '"'"'N'"'"';' \
		'id k = @"NSUnderlyingError"; const char *e = "a \"NSString\" in escapes"; w = "OOLog(x)";'
	expect 0 "NS words in comments and string literals are not findings" scan "$t/lit" sweeps
	mk trail 'NSString *s = nil; // a trailing comment'
	expect 1 "code before a trailing comment still fails" scan "$t/trail" sweeps
	mk blkend 'x = 1; /* a comment' 'ends here */ NSString *s;'
	expect 1 "code after the end of a block comment still fails" scan "$t/blkend" sweeps
	# ADR-0054 item 3: post-gate owners move from the sweeps stage to the source stage.
	mkdir -p "$t/pg/Core"
	printf 'NSString *OOStringFromThing(NSNumber *n);\n' > "$t/pg/Core/OOCollectionExtractors.h"
	printf 'void OONSLogPrintfHandler(NSString *message);\n' > "$t/pg/Core/OOLogOutputHandler+FoundationBridge.mm"
	printf '#import "OOLogOutputHandler+FoundationBridge.h"\n' > "$t/pg/Core/OOLogOutputHandler.h"
	printf 'NSString *OOExpandDescriptionString(Random_Seed seed, NSString *string);\nNSString *OOGenerateSystemDescription(Random_Seed seed, NSString *name);\n' \
		> "$t/pg/Core/OOStringExpander.h"
	expect 0 "post-gate owners are exempt in the sweeps stage" scan "$t/pg" sweeps
	expect 1 "post-gate owners fail in the source stage" scan "$t/pg" source
	mkdir -p "$t/pgx/Core"; printf 'NSString *OOOtherFunction(void);\n' > "$t/pgx/Core/OOStringExpander.h"
	expect 1 "another NSString line in OOStringExpander.h still fails the sweeps stage" scan "$t/pgx" sweeps
	mkdir -p "$t/pgi/Core"; printf '#import "OOOther+FoundationBridge.h"\n' > "$t/pgi/Core/OOLogOutputHandler.h"
	expect 1 "another bridge include still fails the sweeps stage" scan "$t/pgi" sweeps
	mkdir -p "$t/empty"
	expect 2 "an empty tree is an error, not a pass" scan "$t/empty" sweeps
	printf "dependencies = ['objc', '%s']\n" "$gs" > "$t/meson.build"
	expect 1 "'$gs' in a build file fails the source stage" scan "$t/clean" source "$t/meson.build"
	printf "dependencies = ['objc']\n" > "$t/meson.build"
	expect 0 "a clean build file passes the source stage" scan "$t/clean" source "$t/meson.build"
	# --link: a real PE (objdump itself) passes; a stub import table naming the DLL fails.
	local od; od="$(command -v objdump || true)"
	[ -n "$od" ] && [ -f "$od.exe" ] && od="$od.exe"   # a native objdump needs the real file name
	if [ -n "$od" ]; then
		expect 0 "a real PE with no $gs import passes" link_check "$od"
	else
		echo "FAIL: objdump not found (MSYS2 binutils)"; fail=1
	fi
	printf 'MZ' > "$t/fake.exe"
	printf '#!/bin/sh\nprintf "\\tDLL Name: libobjc-4.dll\\n\\tDLL Name: lib%s-1_31.dll\\n"\n' "$gs" > "$t/od-bad"
	printf '#!/bin/sh\nprintf "\\tDLL Name: libobjc-4.dll\\n\\tDLL Name: KERNEL32.dll\\n"\n' > "$t/od-good"
	printf '#!/bin/sh\nexit 0\n' > "$t/od-empty"
	chmod +x "$t/od-bad" "$t/od-good" "$t/od-empty"
	expect 1 "an import table naming lib$gs fails" env OO_FF_OBJDUMP="$t/od-bad" bash "$self" --link "$t/fake.exe"
	expect 0 "an import table without it passes" env OO_FF_OBJDUMP="$t/od-good" bash "$self" --link "$t/fake.exe"
	expect 2 "an empty import table is an error" env OO_FF_OBJDUMP="$t/od-empty" bash "$self" --link "$t/fake.exe"
	expect 2 "a missing executable is an error" bash "$self" --link "$t/missing.exe"
	echo "== selftest: $cases case(s), $([ $fail = 0 ] && echo all behave || echo FAILURES)"
	return $fail
}

stage=sweeps root="" mode=scan exe=""
while [ $# -gt 0 ]; do
	case "$1" in
		--stage) stage="${2:-}"; shift 2 ;;
		--root) root="${2:-}"; shift 2 ;;
		--link) mode=link; exe="${2:-}"; shift 2 ;;
		--selftest) mode=selftest; shift ;;
		-h|--help) usage ;;
		*) echo "unknown argument: $1" >&2; usage ;;
	esac
done
case "$stage" in sweeps|source) ;; *) echo "--stage must be sweeps or source" >&2; exit 2 ;; esac

case "$mode" in
	selftest) selftest ;;
	link) [ -n "$exe" ] || usage; link_check "$exe" ;;
	scan)
		if [ -n "$root" ]; then scan "$root" "$stage"
		else
			cd "$repo" || exit 2
			scan upstream/oolite/src "$stage" "${BUILD_FILES[@]}"
		fi ;;
esac
