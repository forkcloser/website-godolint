# website-godolint

The website for [godolint](https://github.com/forkcloser/godolint), a pure-Go port of
hadolint. Two pages, static, no build step, served at https://godolint.forkcloser.org/.

## Layout

| Path | What |
|------|------|
| `site/` | The site as served. `forkcloser.css` and `forkcloser.js` are the shared Forkcloser identity (tokens, chrome, light and dark themes, the theme switch); `style.css` is what is particular to godolint. No build step, no web fonts, no third-party requests. |
| `site/_headers`, `site/_redirects` | Read by Cloudflare Pages: the response headers (a same-origin Content-Security-Policy, HSTS, and friends) and the redirect from the `pages.dev` hostname to the real one. |
| `demo/` | The sample Dockerfile the landing page annotates, and the output the pinned `godolint` produces for it. |

## Working on it

Open `site/index.html` in a browser; the pages are plain files and need no server.

```bash
just lint    # the shared limen baseline: limen, just, links, yaml, shell, dockerfile, commits
just test    # hero: re-lint the sample and diff against demo/hero-expected.json
             # external: fail if any page loads a resource from another host
             # pin: fail if the install commands name a godolint other than tools/go.mod's
just regen   # rewrite demo/hero-expected.json after editing the sample
```

The findings shown on the landing page are copied from `demo/hero-expected.json`. When
`just test` fails after a `godolint` bump, run `just regen`, read the diff, and update the
annotations in `site/index.html` to match; the install commands on the page name the same
version as `tools/go.mod` and follow each bump too.

## The Forkcloser identity

`site/forkcloser.css` is the visual identity every Forkcloser project site inherits unless it
has one of its own: colour tokens for a light and a dark theme, system typefaces, an 8px
rhythm, the header and footer with the mark, and the styling of ordinary content. The
palette comes from the Forkcloser picture, a steel fork on an oak table: warm grounds, steel
ink, the wood as the one accent. Farcloser's identity is its twin, the same structure with
the temperature flipped. Every text colour is verified against WCAG AA on each ground it
appears on. `site/forkcloser.js` wires the theme switch; the pages follow the system theme
until the reader chooses, and a three-line inline script in each head applies that choice
before first paint. The project's own stylesheet comes after and only adds what is specific
to it. It lives here for now and will be split out once a second site uses it.

## Publishing

The site is deployed by Cloudflare Pages from this repository: a push to `main` deploys
`site/` as committed, and every other branch gets a preview at
`<branch>.website-godolint.pages.dev`. There is no build step and no deploy workflow here.
The Pages project, the custom domain and the DNS record are declared in
[forkcloser/infra](https://github.com/forkcloser/infra), not configured by hand: the zone
`forkcloser.org` is served by deSEC, delegated from Gandi, where the registration stays.
