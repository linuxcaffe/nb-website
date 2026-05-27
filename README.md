# nb-website

Wire any [nb](https://xwmx.github.io/nb/) notebook to a [Quartz](https://quartz.jzhao.xyz/) static site on GitHub Pages, with a custom domain. Manage content in nb-web; the site rebuilds automatically.

```
nb-web (write/edit)
    ↓
~/.nb/<notebook>/   (plain markdown files)
    ↓  nb sync
GitHub repo: <user>/<notebook>
    ↓  GitHub Actions (every 30 min or manual trigger)
Quartz builds static HTML
    ↓
GitHub Pages → your-domain.com
```

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | v22+ | Check: `node --version`. Upgrade via nvm (see below). |
| npm | v10.9.2+ | Comes with Node |
| git | any recent | |
| gh | any | [GitHub CLI](https://cli.github.com) — `gh auth login` before running |
| nb | any | Notebook must exist: `nb notebooks add <name>` |

### Upgrading Node.js with nvm

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
source ~/.bashrc   # or restart your shell
nvm install 22
nvm use 22
node --version     # should show v22.x.x
```

---

## Setup

```bash
cd ~/dev/nb-website
chmod +x nb-website-setup.sh
./nb-website-setup.sh
```

The script walks you through everything interactively, confirms before touching anything, then:

1. Ensures the nb notebook has a public GitHub remote (creates one if not)
2. Clones Quartz v4 into `~/dev/quartz-<notebook>/`
3. Patches `quartz.config.ts` with your site title and domain
4. Writes a custom GitHub Actions workflow that fetches notebook content at build time
5. Creates the Quartz config repo on GitHub and pushes
6. Enables GitHub Pages (source: GitHub Actions)
7. Sets the custom domain if provided

---

## What gets created

### Two GitHub repos

**`<user>/<notebook>`** — notebook content (public markdown files)
- Managed entirely by `nb sync` / nb-web Sync button
- The GitHub Action reads this repo at build time
- Never push to this repo manually

**`<user>/<notebook>-site`** (or your chosen name) — Quartz config
- Contains `quartz.config.ts`, `.github/workflows/deploy.yml`, and any static assets
- Push changes here to update theme, plugins, or site config
- Does **not** contain your notes — those come from the notebook repo

### Local Quartz installation

`~/dev/quartz-<notebook>/` — the Quartz v4 clone with your config applied.

---

## Ongoing workflow

Your day-to-day is just two steps:

1. **Write** in nb-web (notebook: `<notebook>`)
2. **Sync** — Menu → Sync (or `nb sync <notebook>`)

The site rebuilds from GitHub Actions within 30 minutes. For an immediate rebuild:

```bash
gh workflow run deploy.yml --repo <user>/<notebook>-site
```

Or use the GitHub web UI: repo → Actions → Deploy to GitHub Pages → Run workflow.

---

## DNS setup (custom domain, one-time)

At your domain registrar, add four A records pointing the apex (`@`) to GitHub Pages:

```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

Or if you prefer `www`:

```
CNAME  www  →  <user>.github.io
```

DNS propagation takes minutes to hours. GitHub will verify the domain and issue an HTTPS certificate automatically once DNS is live.

---

## Customizing the site

### Theme and configuration

Edit `~/dev/quartz-<notebook>/quartz.config.ts`, then push:

```bash
cd ~/dev/quartz-<notebook>
git add quartz.config.ts
git commit -m "theme: ..."
git push
```

Key fields:

```typescript
configuration: {
  pageTitle: "Your Site Title",
  baseUrl: "your-domain.com",
  theme: {
    // Light/dark color palette
    colors: { light: { ... }, dark: { ... } },
    // Font choices (Google Fonts names)
    typography: { header: "Playfair Display", body: "Source Serif 4", code: "Fira Code" },
  },
  analytics: null,  // disable analytics
}
```

Full reference: [quartz.jzhao.xyz/configuration](https://quartz.jzhao.xyz/configuration)

### Static assets (images, favicon)

Drop files in `~/dev/quartz-<notebook>/quartz/static/` and push. They appear at `/static/filename` on your site.

---

## Notebook structure tips

Quartz renders all `.md` files it finds. A few conventions that work well:

- `index.md` — becomes the home page (use a `title` frontmatter field)
- `about.md`, `shop.md` etc. — top-level pages
- Subdirectories become URL segments: `items/pyrex-dish.md` → `/items/pyrex-dish`
- Tag pages are generated automatically from `#tag` usage in notes
- Wikilinks (`[[note title]]`) work and become hyperlinks

### Frontmatter

```yaml
---
title: Vintage Pyrex Finds
tags: [pyrex, kitchen, ceramics]
date: 2026-05-27
---
```

Quartz uses `title` as the page title and `date` for the "last updated" display. Tags generate tag index pages automatically.

### Keeping drafts off the live site

Add `draft: true` to any note's frontmatter. Quartz's `RemoveDrafts` plugin (enabled by default) excludes them from the build.

---

## Instant updates (optional)

The default 30-minute schedule is fine for most use cases. If you want nb sync to trigger a rebuild immediately, add a dispatch workflow to the notebook repo:

**`~/.nb/<notebook>/.github/workflows/notify-site.yml`**

```yaml
name: Notify site to rebuild
on:
  push:
    branches: [main]
jobs:
  dispatch:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.SITE_DISPATCH_TOKEN }}
          script: |
            await github.rest.repos.createDispatchEvent({
              owner: context.repo.owner,
              repo: '<notebook>-site',
              event_type: 'content-update'
            })
```

And in the site repo's `deploy.yml`, add `repository_dispatch` to the `on:` triggers:

```yaml
on:
  push:
    branches: [main]
  repository_dispatch:
    types: [content-update]
  workflow_dispatch:
```

You'll need to create a [Personal Access Token](https://github.com/settings/tokens) with `repo` scope and add it as a secret named `SITE_DISPATCH_TOKEN` in the notebook repo settings.

---

## Troubleshooting

**Build fails with "content directory not found"**
The notebook repo might be empty or have no committed files. Add at least an `index.md` and run `nb sync <notebook>`.

**Site shows 404 after DNS change**
Wait for DNS propagation (up to 24h). Check: `dig your-domain.com` should return GitHub Pages IPs. Also confirm the domain is set in repo Settings → Pages.

**`gh api` errors during setup**
Your `gh` version may be too old for some API calls. The script prints manual fallback instructions. Key manual step: repo Settings → Pages → Source: GitHub Actions.

**`npx quartz build` fails locally**
```bash
cd ~/dev/quartz-<notebook>
npx quartz build --directory ~/.nb/<notebook>/ --verbose
```
Common causes: Node version too low, or `npm ci` not run after cloning.

---

*Built on [nb](https://xwmx.github.io/nb/) + [Quartz](https://quartz.jzhao.xyz/) + [GitHub Pages](https://pages.github.com/). Zero recurring cost.*
