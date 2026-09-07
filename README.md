# website-godolint

The website for [godolint](https://github.com/farcloser/godolint), a pure-Go port of
hadolint. Two pages, static, no build step, served at https://godolint.farcloser.world/.

## Layout

| Path | What |
|------|------|
| `site/` | The site as served. `farcloser.css` and `farcloser.js` are the shared Farcloser identity (tokens, chrome, light and dark themes, the theme switch); `style.css` is what is particular to godolint. No build step, no web fonts, no third-party requests. |
| `site/_headers`, `site/_redirects` | Read by Cloudflare Pages: the response headers (a same-origin Content-Security-Policy, HSTS, and friends) and the redirect from the `pages.dev` hostname to the real one. |
| `demo/` | The sample Dockerfile the landing page annotates, and the output the pinned `godolint` produces for it. |

## Working on it

Open `site/index.html` in a browser; the pages are plain files and need no server.

```bash
just lint    # the shared limen baseline: limen, just, links, yaml, shell, dockerfile, commits
just test    # hero: re-lint the sample and diff against demo/hero-expected.json
             # external: fail if any page loads a resource from another host
just regen   # rewrite demo/hero-expected.json after editing the sample
```

The findings shown on the landing page are copied from `demo/hero-expected.json`. When
`just test` fails after a `godolint` bump, run `just regen`, read the diff, and update the
annotations in `site/index.html` to match.

## The Farcloser identity

`site/farcloser.css` is the visual identity every Farcloser project site inherits unless it
has one of its own: colour tokens for a light and a dark theme, system typefaces, an 8px
rhythm, the header and footer with the mark, and the styling of ordinary content. Every
text colour is verified against WCAG AA on each ground it appears on. `site/farcloser.js`
wires the theme switch; the pages follow the system theme until the reader chooses, and
a three-line inline script in each head applies that choice before first paint. The
project's own stylesheet comes after and only adds what is specific to it. It lives here
for now and will be split out once a second site uses it.

The rules table in `site/rules.html` is written from the rule metadata in godolint's
`internal/rules/dl*.go` files (code, severity, message), one row per rule. It is updated by
hand when godolint gains or changes rules.

## Publishing

Cloudflare Pages is connected to this repository: a push to `main` deploys `site/` as
committed, and every other branch gets a preview at `<branch>.website-godolint.pages.dev`.
There is no build step and no deploy workflow here. DNS for `farcloser.world` stays at
Gandi, where `godolint` is a CNAME to `website-godolint.pages.dev`.
