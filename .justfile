# This file is the project's own — add recipes below. Keep the import: it
# mounts every shared limen task under `just do ...`.
import '.limen/just/main.just'

lint: do::lint::default
fix: do::fix::default
test: hero external pin
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
