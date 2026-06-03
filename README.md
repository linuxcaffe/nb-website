# nb-website

Wire any [nb](https://xwmx.github.io/nb/) notebook to a [Quartz](https://quartz.jzhao.xyz/) static site on GitHub Pages, with a custom domain. The site rebuilds automatically whenever you sync.

**nb is required. [nb-web](https://github.com/linuxcaffe/nb-web) is recommended** — it gives you a visual editor, template picker, and sync UI, but the pipeline works fine with only the `nb` CLI and a text editor.

**Live example:** [preciousfinds.ca](https://preciousfinds.ca) — built with this package.

```
nb-web or any text editor  (write & edit notes)   ← recommended, not required
    ↓
~/.nb/<notebook>/        plain markdown files, git-managed by nb
    ↓  nb sync  (or git push)
GitHub: <user>/<notebook>    public content repo
    ↓  GitHub Actions  (on push, every 30 min, or manual trigger)
Quartz v4  builds static HTML
    ↓
GitHub Pages  →  your-domain.com
```

Two GitHub repos, zero servers, zero recurring cost.

---

## Prerequisites

| Tool | Version | Check | Install |
|------|---------|-------|---------|
| Node.js | v22+ | `node --version` | via nvm (see below) |
| npm | v10.9.2+ | `npm --version` | comes with Node |
| git | any | `git --version` | system package manager |
| gh | any | `gh auth status` | [cli.github.com](https://cli.github.com) |
| nb | any | `nb --version` | [xwmx.github.io/nb](https://xwmx.github.io/nb/) |
| nb-web | any | — | [github.com/linuxcaffe/nb-web](https://github.com/linuxcaffe/nb-web) — **recommended**, not required |

### Node.js v22 via nvm

The system Node on Ubuntu/Mint is typically v12 — far too old for Quartz. nvm installs v22 alongside it without touching the system Node or any other projects.

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
source ~/.bashrc          # or open a new terminal
nvm install 22
nvm alias default 22      # makes v22 the default for all new shells
node --version            # v22.x.x
```

### GitHub CLI — SSH auth

The setup script uses SSH remote URLs. Confirm gh is configured for SSH:

```bash
gh auth status
# Should show: Git operations configured to use ssh protocol
```

If not: `gh auth login` and select SSH when prompted.

---

## Before you run: scaffold the notebook

Create the nb notebook and stub out your pages before running the setup script. The notebook name can include dots (`preciousfinds.ca` works fine).

```bash
nb notebooks add your-notebook
```

Then add at minimum an `index.md`. Use `--filename` to get clean URLs:

```bash
nb add your-notebook: --filename index.md --title "Your Site" --content $'\n'
nb add your-notebook: --filename about.md --title "About" --content $'\n'
```

Or write the files directly to `~/.nb/your-notebook/` and update `.index`.

### Recommended page structure (4-page brochure site)

| File | Purpose |
|------|---------|
| `index.md` | Home / landing page |
| `shop.md` | Links to your sales platforms |
| `new-arrivals.md` | Regularly updated finds — gives repeat visitors a reason to return |
| `about.md` | Your story — the page that turns browsers into buyers |

### index.md frontmatter note

Quartz renders the `title` frontmatter field as the page `<h1>` via its `ArticleTitle` component. **Don't repeat the title as a `# Heading` in the markdown content** — it will appear twice.

```markdown
---
title: Your Site Name
---

*Your tagline here.*

[Browse the Shop →](shop.md)
```

### Keeping drafts off the live site

```yaml
---
title: Work in Progress
draft: true
---
```

Quartz's `RemoveDrafts` plugin (on by default) excludes any note with `draft: true`.

---

## Setup

```bash
cd ~/dev/nb-website
./nb-website-setup.sh
```

The script is interactive — it confirms the full plan before touching anything. It will ask for:

- nb notebook name (e.g. `preciousfinds.ca`)
- Quartz config repo name (default: `<notebook>-site`)
- Site title (e.g. `Precious Finds`)
- Custom domain (optional — leave blank for `<user>.github.io/<repo>`)

Then it runs end-to-end without further prompts:

1. Ensures the notebook has a public GitHub remote (creates one if not)
2. Clones Quartz v4 into `~/dev/quartz-<notebook>/` and runs `npm ci`
3. Applies the warm-vintage theme (fonts, colours, layout — see below)
4. Patches `quartz.config.ts` with your site title and domain
5. Writes the GitHub Actions deploy workflow
6. Creates the Quartz config repo on GitHub, pushes with a clean history
7. Enables GitHub Pages (source: GitHub Actions)
8. Sets the custom domain if provided

---

## What gets created

### Two GitHub repos

**`<user>/<notebook>`** — notebook content
- Plain markdown files, managed entirely by `nb sync` and nb-web
- The GitHub Action checks this out at build time
- Don't push to it manually — let nb sync handle it

**`<user>/<notebook>-site`** — Quartz config
- `quartz.config.ts`, `quartz.layout.ts`, `.github/workflows/deploy.yml`, `quartz/styles/custom.scss`
- Push changes here when you update the theme, layout, or site config
- Contains no notes — content comes from the notebook repo at build time

### Local Quartz installation

`~/dev/quartz-<notebook>/` — the Quartz v4 clone with your config applied. You can preview the site locally:

```bash
cd ~/dev/quartz-<notebook>
npx quartz build --directory ~/.nb/<notebook>/ --serve
# open http://localhost:8080
```

---

## Ongoing workflow

Day-to-day is two steps:

1. **Write** — in nb-web, or any text editor, or directly with `nb add <notebook>:`
2. **Sync** — `nb sync <notebook>` (or Menu → Sync in nb-web)

GitHub Actions picks up the pushed content and rebuilds within 30 minutes. For an immediate rebuild:

```bash
gh workflow run deploy.yml --repo <user>/<notebook>-site
```

Or: GitHub → your site repo → Actions → Deploy to GitHub Pages → Run workflow.

---

## DNS setup (custom domain, one-time)

At your domain registrar, add four A records pointing the apex (`@`) to GitHub Pages:

```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

Or a CNAME for `www`:

```
www  CNAME  <user>.github.io
```

DNS propagates in minutes to hours. GitHub automatically verifies the domain and issues an HTTPS certificate once DNS is live. You can check progress in the repo: Settings → Pages.

---

## Themes

### warm-vintage (included)

Applied automatically by the setup script. Designed for a boutique or vintage shop aesthetic.

**Palette:** warm cream ground · deep rose accent (`#8b3a52`) · terracotta hover · warm brown text  
**Fonts:** Playfair Display (headings) + Lora (body)  
**Layout changes:**
- Folder explorer hidden (4 pages don't need a tree)
- Graph view removed
- Backlinks hidden
- Images get a warm shadow and rounded corners
- Product photo paragraphs get a subtle card frame

**Page-specific styling** (via Quartz's `body[data-slug]` attribute):
- Home page: centred hero title in rose, tagline muted, "Browse the Shop →" becomes a filled button
- Shop page: platform links (eBay, Etsy, Facebook by URL) styled as bordered rose buttons
- New Arrivals: month headings in rose with breathing room between items

### Applying the theme to an existing Quartz installation

```bash
~/dev/nb-website/themes/warm-vintage/apply.sh ~/dev/quartz-<notebook>
```

Then push:

```bash
cd ~/dev/quartz-<notebook>
git add -A && git commit -m "theme: warm-vintage" && git push
```

### Manual follow-up after apply

The script clears Quartz's default footer links (GitHub/Discord). Add your own in `quartz.layout.ts`:

```typescript
footer: Component.Footer({
  links: {
    eBay: "https://ebay.ca/usr/YOURUSERNAME",
    Etsy: "https://etsy.com/shop/YOURSHOPNAME",
  },
}),
```

### Customising the palette

Override any colour in `quartz/styles/custom.scss`:

```scss
:root {
  --secondary: #4a6741;   // swap rose for sage green
  --tertiary:  #8aad82;
}
```

Push to trigger a rebuild.

### Changing fonts

Edit `quartz.config.ts` — any Google Fonts name works:

```typescript
typography: {
  header: "Cormorant Garamond",
  body:   "Crimson Pro",
  code:   "IBM Plex Mono",
},
```

Full Quartz config reference: [quartz.jzhao.xyz/configuration](https://quartz.jzhao.xyz/configuration)

---

## Dynamic content — the core principle

The site's structure is a live reflection of the notebook's frontmatter. Index pages, category pages, tag pages, and navigation are all **generated at build time from your content** — never maintained by hand alongside it.

Concretely: if an item note has `category: ceramics`, a fully rendered `/category/ceramics` page appears in the next build — populated with every available item in that category, in reverse-chronological order, with a category navigation bar derived from all active items. Remove the last ceramics item and the page disappears. Rename a category across your items and the old page vanishes, the new one appears.

The same principle applies everywhere: tag index pages (`/tags/<tag>`) come from `tags:` frontmatter; the shop navigation populates from `category:` fields on available items; the New Arrivals feed is the `[new]`-tagged item list sorted by date.

**The rule of thumb: if a page can be derived from frontmatter, it should be.** Never create a hand-written index page that duplicates information already in your notes. If you find yourself maintaining a list that mirrors your item data, that list should be a component or an emitter, not a note.

---

## Notebook tips

### Frontmatter fields Quartz uses

```yaml
---
title: Vintage Pyrex Finds
tags: [pyrex, kitchen, ceramics]
date: 2026-05-27
draft: true          # exclude from build
---
```

`title` → page `<h1>` and browser tab. `date` → "last updated" display. Tags generate index pages automatically.

### URL structure

| File | URL |
|------|-----|
| `index.md` | `/` |
| `about.md` | `/about` |
| `items/pyrex-dish.md` | `/items/pyrex-dish` |

Subdirectories become URL segments. Tag pages appear at `/tags/<tag>`.

### Wikilinks

`[[note title]]` in any note becomes a hyperlink. Works for cross-linking item pages, category pages, etc.

### Static assets

Drop images, favicon, etc. in `~/dev/quartz-<notebook>/quartz/static/`. They appear at `/static/filename` on the live site. Push after adding.

---

## Instant updates (optional)

The default 30-minute schedule suits most workflows. For rebuilds triggered the moment you sync, add a dispatch workflow to the notebook repo:

**`~/.nb/<notebook>/.github/workflows/notify-site.yml`**

```yaml
name: Notify site repo to rebuild
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

Add `repository_dispatch` to the site repo's `deploy.yml` triggers:

```yaml
on:
  push:
    branches: [main]
  repository_dispatch:
    types: [content-update]
  schedule:
    - cron: '*/30 * * * *'
  workflow_dispatch:
```

Create a [Personal Access Token](https://github.com/settings/tokens) with `repo` scope and add it as a secret named `SITE_DISPATCH_TOKEN` in the notebook repo's Settings → Secrets.

---

## Troubleshooting

**"content directory not found" in GitHub Actions**  
The notebook repo has no committed files. Add at least an `index.md`, run `nb sync <notebook>`, and re-trigger the workflow.

**Site shows 404 after DNS change**  
Wait for DNS propagation (up to 24h). Verify: `dig your-domain.com` should return GitHub Pages IPs. Confirm the custom domain is set in the site repo: Settings → Pages.

**`gh api` Pages setup fails**  
gh v2.4.x (the Ubuntu 22.04 system package) has limited API support. Enable manually: site repo → Settings → Pages → Source: GitHub Actions.

**Setup script can't push — permission denied (publickey)**  
gh is not configured for SSH. Run `gh auth login` and select SSH, or check that your SSH key is added to GitHub: `ssh -T git@github.com`.

**`npx quartz build` fails locally**  
```bash
cd ~/dev/quartz-<notebook>
npx quartz build --directory ~/.nb/<notebook>/ --verbose
```
Common causes: Node below v22, or `npm ci` not run after cloning.

**Title appears twice on a page**  
You have both `title:` in frontmatter and a `# Heading` in the markdown body. Remove the markdown heading — Quartz's `ArticleTitle` component renders the frontmatter title as `<h1>` already.

---

*Built on [nb](https://xwmx.github.io/nb/) + [Quartz](https://quartz.jzhao.xyz/) + [GitHub Pages](https://pages.github.com/). Proven on [preciousfinds.ca](https://preciousfinds.ca).*
