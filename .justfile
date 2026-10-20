# This file is the project's own — add recipes below. Keep the import: it
# mounts every shared limen task under `just do ...`.
import '.limen/just/main.just'

lint: do::lint::default
fix: do::fix::default
test: hero rules external pin
# The security workflow runs `just security`.
security: do::security::default

# The landing page shows godolint's findings for a sample Dockerfile, and the
# claim is that they are real. Re-run the aqua-pinned godolint over the sample
# and fail if the committed output — the one the page was written from — has
# drifted. The sample is named so the `lint dockerfile` recipe does not pick
# it up: its violations are the point, not a defect.
hero:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "test: hero" >&2
    # mktemp gets an explicit template because macOS mktemp ignores $TMPDIR.
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/hero.XXXXXX")
    trap 'rm -rf "$tmpdir"' EXIT
    # godolint is a tool directive in limen's .limen/tools/go.mod, not an aqua
    # package: build it the way limen's own recipes do, into .build/tools/,
    # with cgo off (the tool is pure Go; `net` would otherwise call a C compiler).
    GOOS='' GOARCH='' CGO_ENABLED=0 go -C .limen/tools build -o '../../.build/tools/' github.com/forkcloser/godolint/cmd/godolint
    # Exit status 1 means findings, which is what the sample is for; any other
    # failure leaves an empty or partial file and jq or the diff catches it.
    .build/tools/godolint --without-shellcheck demo/hero-dockerfile.txt > "$tmpdir/actual.raw" || [ $? -eq 1 ]
    # Plain files rather than process substitution: sandboxes may deny /dev/fd.
    jq -S . "$tmpdir/actual.raw" > "$tmpdir/actual.json"
    jq -S . demo/hero-expected.json > "$tmpdir/expected.json"
    diff -u "$tmpdir/expected.json" "$tmpdir/actual.json"
    echo "test: hero output matches demo/hero-expected.json" >&2

# Regenerate the committed expectation after changing the sample. Review the
# diff and update the annotations in site/index.html to match.
regen:
    #!/usr/bin/env bash
    set -euo pipefail
    GOOS='' GOARCH='' CGO_ENABLED=0 go -C .limen/tools build -o '../../.build/tools/' github.com/forkcloser/godolint/cmd/godolint
    .build/tools/godolint --without-shellcheck demo/hero-dockerfile.txt | jq . > demo/hero-expected.json || [ $? -eq 1 ]
    cat demo/hero-expected.json

# The install commands on the landing page name a version, as DL3062 on the
# same page asks of everyone else, and it is the version the site is written
# against: the godolint pinned in .limen/tools/go.mod, the one the hero recipe runs.
# Renovate bumps the pin; this fails until the page follows.
pin:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "test: pin" >&2
    want=$(grep -E '^\s*github.com/forkcloser/godolint v' .limen/tools/go.mod | awk '{print $2}')
    [ -n "$want" ] || { echo "test: .limen/tools/go.mod does not pin github.com/forkcloser/godolint" >&2; exit 1; }
    shown=$(grep -oE 'github.com/forkcloser/godolint(/cmd/godolint)?@[^<[:space:]]+' site/index.html | sed 's/.*@//')
    [ "$(printf '%s\n' "$shown" | wc -l)" -eq 2 ] || { echo "test: expected two install commands in site/index.html, found:" >&2; printf '%s\n' "$shown" >&2; exit 1; }
    for v in $shown; do
        [ "$v" = "$want" ] || { echo "test: site/index.html installs godolint@$v, .limen/tools/go.mod pins $want" >&2; exit 1; }
    done
    echo "test: install commands pin godolint $want" >&2

# The rules page is the pinned godolint's rule list, and the claim is that
# it is complete and exact. List the module's rules (hack/rules/main.go,
# run inside limen's tools module so the pin is the one .limen/tools/go.mod
# holds) and diff them against the page's rows: code, severity, message.
# The landing page's excerpt must be rows of that list, and the tally on
# each page must count what the list counts. A godolint bump that adds,
# drops or reclassifies a rule fails here until the pages follow.
rules:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "test: rules" >&2
    # mktemp gets an explicit template because macOS mktemp ignores $TMPDIR.
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/rules.XXXXXX")
    trap 'rm -rf "$tmpdir"' EXIT
    tab=$(printf '\t')
    # Both sides squeeze runs of spaces, as a browser does when it renders
    # the page, and sort by code: the order of the rows is the page's own.
    GOOS='' GOARCH='' CGO_ENABLED=0 go -C .limen/tools run "$PWD/hack/rules/main.go" | tr -s ' ' | tr -d '\r' | LC_ALL=C sort > "$tmpdir/module.tsv"
    [ -s "$tmpdir/module.tsv" ] || { echo "test: the pinned godolint listed no rules" >&2; exit 1; }
    # A page row, reduced to the same three fields: the code from the row's
    # link, the severity cell ("off by default" is hadolint's ignore), and
    # the message cell with its code spans back to the backticks the module
    # carries, any other markup dropped, and its entities decoded.
    rows() {
        sed -nE "s~^[[:space:]]*<tr[^>]*role=\"row\"><td role=\"cell\"><a href=\"[^\"]*(DL[0-9]+)\">[^<]*</a></td><td role=\"cell\">([^<]*)</td><td role=\"cell\">(.*)</td></tr>[[:space:]]*\$~\\1${tab}\\2${tab}\\3~p" "$1" \
            | sed -E 's~</?code>~`~g; s~<[^>]+>~~g; s~&lt;~<~g; s~&gt;~>~g; s~&quot;~"~g; s~&#39;~'"'"'~g; s~&amp;~\&~g' \
            | sed -E "s~${tab}off by default${tab}~${tab}ignore${tab}~" \
            | tr -s ' ' | tr -d '\r' | LC_ALL=C sort
    }
    # The label rules (DL3049, DL3051 to DL3056, DL3058) complete their
    # message per violation with the label's name, and the module's metadata
    # holds only the prefix, up to an open backtick; the page's wording of
    # those ("Label `<label>` is missing.") is the page's, so for them only
    # the code and the severity are compared.
    awk -F'\t' '$3 ~ /`$/ { print $1 }' "$tmpdir/module.tsv" > "$tmpdir/templated"
    mask() {
        awk -F'\t' -v OFS='\t' 'NR == FNR { t[$1] = 1; next } ($1 in t) { $3 = "(completed per violation)" } { print }' "$tmpdir/templated" "$1"
    }
    mask "$tmpdir/module.tsv" > "$tmpdir/module.masked"
    rows site/rules.html | mask /dev/stdin > "$tmpdir/page.tsv"
    if ! diff -u "$tmpdir/module.masked" "$tmpdir/page.tsv" >&2; then
        echo "test: site/rules.html does not list the pinned godolint's rules (- module, + page)" >&2
        exit 1
    fi
    rows site/index.html | mask /dev/stdin > "$tmpdir/excerpt.tsv"
    [ -s "$tmpdir/excerpt.tsv" ] || { echo "test: site/index.html shows no rule rows" >&2; exit 1; }
    if grep -vxF -f "$tmpdir/module.masked" "$tmpdir/excerpt.tsv" > "$tmpdir/stray.tsv"; then
        cat "$tmpdir/stray.tsv" >&2
        echo "test: site/index.html shows rows that are not the pinned godolint's (listed above)" >&2
        exit 1
    fi
    for page in site/index.html site/rules.html; do
        for sev in error warning info style ignore; do
            want=$(awk -F'\t' -v s="$sev" '$2 == s' "$tmpdir/module.tsv" | wc -l | tr -d ' ')
            shown=$(grep -oE "<li class=\"sev-$sev\"><strong>[0-9]+" "$page" | grep -oE '[0-9]+$' || true)
            [ "$shown" = "$want" ] || { echo "test: $page tallies $sev as '$shown', the pinned godolint has $want" >&2; exit 1; }
        done
    done
    echo "test: site/rules.html lists the pinned godolint's $(wc -l < "$tmpdir/module.tsv" | tr -d ' ') rules; the excerpt and both tallies agree" >&2

# The pages must load nothing from elsewhere: no web fonts, no CDN scripts,
# no hotlinked images. Every load is a request to a third party on each
# visit, and an unpinned dependency on that party's continued behaviour —
# the same objection the projects these sites describe make about binaries.
# Matched per line, which is how these pages are written; a `canonical` or
# `og:` link is a declaration, not a load, and is not matched.
external:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "test: external" >&2
    shopt -s nullglob
    files=(site/*.html site/*.css)
    [ ${#files[@]} -gt 0 ] || { echo "test: nothing under site/ to check" >&2; exit 1; }
    pattern='<link[^>]*rel="(stylesheet|preconnect|preload|modulepreload|icon|manifest)"[^>]*href="https?://'
    pattern="$pattern"'|<link[^>]*href="https?://[^>]*rel="(stylesheet|preconnect|preload|modulepreload|icon|manifest)"'
    pattern="$pattern"'|<(script|img|iframe|source|video|audio|object|embed)[^>]*src="https?://'
    pattern="$pattern"'|@import[^;]*https?://|url\(["'"'"']?https?://'
    # grep exits 1 on no match (the pass) and 2 on a read error (a failure).
    status=0
    grep -nE "$pattern" "${files[@]}" > "${TMPDIR:-/tmp}/external.$$" || status=$?
    hits="${TMPDIR:-/tmp}/external.$$"
    if [ "$status" -eq 0 ]; then
        cat "$hits" >&2
        rm -f "$hits"
        echo "test: the site loads resources from elsewhere (listed above)" >&2
        exit 1
    fi
    rm -f "$hits"
    [ "$status" -eq 1 ] || exit "$status"
    echo "test: no external resource loads" >&2
