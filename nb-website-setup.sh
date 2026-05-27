#!/usr/bin/env bash
# nb-website-setup.sh
# Wire an nb notebook to a Quartz static site on GitHub Pages.
#
# Usage: ./nb-website-setup.sh
#
# What this creates:
#   <gh-user>/<notebook>       GitHub repo for nb notebook content (managed by nb sync)
#   <gh-user>/<notebook>-site  GitHub repo for Quartz config + Actions workflow
#   ~/dev/quartz-<notebook>/   Local Quartz installation

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

die()  { echo -e "\n${RED}Error: $*${NC}" >&2; exit 1; }
info() { echo -e "${BLUE}→ $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
ask()  { echo -en "${BOLD}$* ${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prerequisites ─────────────────────────────────────────────────────────────

check_prereqs() {
  local node_major errors=0

  command -v git &>/dev/null || { warn "git not found."; (( errors++ )); }
  command -v npm &>/dev/null || { warn "npm not found."; (( errors++ )); }

  if ! command -v node &>/dev/null; then
    warn "Node.js not found."
    (( errors++ ))
  else
    node_major=$(node --version | sed 's/v//' | cut -d. -f1)
    if (( node_major < 22 )); then
      warn "Node.js v22+ required (found v${node_major})."
      echo "    Install nvm then upgrade:"
      echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash"
      echo "    source ~/.bashrc  # or restart your shell"
      echo "    nvm install 22 && nvm use 22"
      (( errors++ ))
    fi
  fi

  if ! command -v gh &>/dev/null; then
    warn "gh (GitHub CLI) not found. https://cli.github.com"
    (( errors++ ))
  elif ! gh auth status &>/dev/null 2>&1; then
    warn "gh not authenticated — run: gh auth login"
    (( errors++ ))
  fi

  (( errors == 0 )) || die "${errors} prerequisite(s) not met. Fix above, then re-run."
  ok "Prerequisites satisfied"
}

# ── Inputs ────────────────────────────────────────────────────────────────────

gather_inputs() {
  echo ""
  echo -e "${BOLD}nb-website setup${NC} — nb notebook → Quartz → GitHub Pages"
  echo ""

  ask "nb notebook name (e.g. preciousfinds):"; read -r NOTEBOOK
  [[ -n "$NOTEBOOK" ]] || die "Notebook name is required."

  NB_DIR="${HOME}/.nb/${NOTEBOOK}"
  [[ -d "$NB_DIR" ]] || die "Notebook '${NOTEBOOK}' not found at ${NB_DIR}.
  Create it first: nb notebooks add ${NOTEBOOK}"

  GH_USER=$(gh api user --jq .login 2>/dev/null) || die "Could not get GitHub username — is gh authenticated?"
  echo "  GitHub user: ${GH_USER}"

  local default_site_repo="${NOTEBOOK}-site"
  ask "Quartz config repo name [${default_site_repo}]:"; read -r _input
  SITE_REPO="${_input:-$default_site_repo}"

  ask "Site title (e.g. Precious Finds):"; read -r SITE_TITLE
  [[ -n "$SITE_TITLE" ]] || die "Site title is required."

  ask "Custom domain (blank for ${GH_USER}.github.io/${SITE_REPO}):"; read -r CUSTOM_DOMAIN

  BASE_URL="${CUSTOM_DOMAIN:-${GH_USER}.github.io/${SITE_REPO}}"
  QUARTZ_DIR="${HOME}/dev/quartz-${NOTEBOOK}"

  echo ""
  echo "  Notebook dir:   ${NB_DIR}"
  echo "  Quartz dir:     ${QUARTZ_DIR}"
  echo "  Content repo:   https://github.com/${GH_USER}/${NOTEBOOK}"
  echo "  Quartz repo:    https://github.com/${GH_USER}/${SITE_REPO}"
  echo "  Site URL:       https://${BASE_URL}"
  echo ""
  ask "Proceed? [y/N]:"; read -r _yn
  [[ "$_yn" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  echo ""
}

# ── Notebook remote ────────────────────────────────────────────────────────────

ensure_notebook_remote() {
  info "Checking notebook GitHub remote..."
  local remote
  remote=$(git -C "$NB_DIR" remote get-url origin 2>/dev/null || echo "")

  if [[ -z "$remote" ]]; then
    warn "No remote set for notebook '${NOTEBOOK}'."
    info "Creating public GitHub repo ${GH_USER}/${NOTEBOOK}..."
    gh repo create "${GH_USER}/${NOTEBOOK}" --public \
      --description "${SITE_TITLE} — nb notebook content"
    git -C "$NB_DIR" remote add origin "git@github.com:${GH_USER}/${NOTEBOOK}.git"
    git -C "$NB_DIR" push -u origin HEAD
    ok "Notebook repo created: github.com/${GH_USER}/${NOTEBOOK}"
  else
    ok "Notebook remote: ${remote}"
    # Push current state so the Actions workflow can check it out immediately
    git -C "$NB_DIR" push -u origin HEAD 2>/dev/null || true
  fi

  NOTEBOOK_REPO="${GH_USER}/${NOTEBOOK}"
}

# ── Quartz setup ──────────────────────────────────────────────────────────────

setup_quartz() {
  if [[ -d "$QUARTZ_DIR" ]]; then
    warn "${QUARTZ_DIR} already exists — skipping clone."
  else
    info "Cloning Quartz v4 (shallow)..."
    git clone --branch v4 --single-branch --depth 1 \
      https://github.com/jackyzha0/quartz.git "$QUARTZ_DIR"
  fi

  cd "$QUARTZ_DIR"

  info "Installing Quartz dependencies (this takes a minute)..."
  npm ci --quiet

  info "Patching quartz.config.ts..."
  # Match Quartz v4's default placeholders exactly
  sed -i "s|pageTitle: \".*\"|pageTitle: \"${SITE_TITLE}\"|" quartz.config.ts
  sed -i "s|baseUrl: \".*\"|baseUrl: \"${BASE_URL}\"|" quartz.config.ts

  # Remove the bundled example content — our notebook repo supplies it at build time
  rm -rf content/

  ok "Quartz configured"
}

# ── Theme ──────────────────────────────────────────────────────────────────────

apply_theme() {
  local theme="${1:-warm-vintage}"
  local apply_script="${SCRIPT_DIR}/themes/${theme}/apply.sh"

  if [[ -x "$apply_script" ]]; then
    info "Applying theme: ${theme}..."
    bash "$apply_script" "$QUARTZ_DIR"
    ok "Theme applied"
  else
    warn "Theme '${theme}' not found at ${apply_script} — skipping."
  fi
}

# ── Deploy workflow ────────────────────────────────────────────────────────────

write_deploy_workflow() {
  info "Writing GitHub Actions workflow..."

  mkdir -p "${QUARTZ_DIR}/.github/workflows"
  sed "s|NOTEBOOK_REPO|${NOTEBOOK_REPO}|g" \
    "${SCRIPT_DIR}/templates/deploy.yml" \
    > "${QUARTZ_DIR}/.github/workflows/deploy.yml"

  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    # Quartz copies quartz/static/ into the output root — CNAME goes here
    mkdir -p "${QUARTZ_DIR}/quartz/static"
    echo "$CUSTOM_DOMAIN" > "${QUARTZ_DIR}/quartz/static/CNAME"
    info "CNAME file written for ${CUSTOM_DOMAIN}"
  fi

  ok "Workflow written"
}

# ── Push Quartz config to GitHub ──────────────────────────────────────────────

push_quartz_config() {
  cd "$QUARTZ_DIR"

  # Start fresh — we don't want Quartz's own git history in our config repo
  rm -rf .git
  git init -b main
  git add .
  git commit -m "init: Quartz config for ${SITE_TITLE}"

  info "Creating GitHub repo ${GH_USER}/${SITE_REPO}..."
  gh repo create "${GH_USER}/${SITE_REPO}" --public \
    --description "Quartz site config for ${SITE_TITLE}" 2>/dev/null \
    || warn "Repo may already exist — pushing anyway."

  git remote add origin "git@github.com:${GH_USER}/${SITE_REPO}.git"
  git push -u origin main

  ok "Pushed to github.com/${GH_USER}/${SITE_REPO}"
}

# ── Enable GitHub Pages ───────────────────────────────────────────────────────

enable_pages() {
  info "Enabling GitHub Pages (source: GitHub Actions)..."

  if gh api "repos/${GH_USER}/${SITE_REPO}/pages" \
      --method POST \
      --field build_type=workflow 2>/dev/null; then
    ok "GitHub Pages enabled"
  else
    warn "Could not enable Pages via API."
    echo "    Enable manually: github.com/${GH_USER}/${SITE_REPO} → Settings → Pages"
    echo "    Source: GitHub Actions"
  fi

  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    if gh api "repos/${GH_USER}/${SITE_REPO}/pages" \
        --method PATCH \
        --field custom_domain="${CUSTOM_DOMAIN}" 2>/dev/null; then
      ok "Custom domain set: ${CUSTOM_DOMAIN}"
    else
      warn "Set custom domain manually in repo Settings → Pages."
    fi
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}Setup complete!${NC}"
  echo ""
  echo "  Quartz config:  ${QUARTZ_DIR}"
  echo "  Config repo:    https://github.com/${GH_USER}/${SITE_REPO}"
  echo "  Content repo:   https://github.com/${NOTEBOOK_REPO}"
  echo ""
  echo -e "${BOLD}Ongoing workflow:${NC}"
  echo "  1. Write in nb-web  (notebook: ${NOTEBOOK})"
  echo "  2. Menu → Sync      (or: nb sync ${NOTEBOOK})"
  echo "  3. Site rebuilds automatically within 30 minutes"
  echo "     Trigger immediately: gh workflow run deploy.yml --repo ${GH_USER}/${SITE_REPO}"
  echo "  Live at: https://${BASE_URL}"
  echo ""

  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    echo -e "${BOLD}DNS setup (one-time — at your domain registrar):${NC}"
    echo "  Add four A records pointing the apex (@) to GitHub Pages:"
    echo "    185.199.108.153"
    echo "    185.199.109.153"
    echo "    185.199.110.153"
    echo "    185.199.111.153"
    echo "  Or a CNAME:  www → ${GH_USER}.github.io"
    echo "  DNS changes propagate in minutes to hours."
    echo ""
  fi

  echo -e "${BOLD}To customize theme or plugins:${NC}"
  echo "  Edit: ${QUARTZ_DIR}/quartz.config.ts"
  echo "  Docs: https://quartz.jzhao.xyz/configuration"
  echo "  Push changes: cd ${QUARTZ_DIR} && git add -A && git commit -m '...' && git push"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

check_prereqs
gather_inputs
ensure_notebook_remote
setup_quartz
apply_theme "warm-vintage"
write_deploy_workflow
push_quartz_config
enable_pages
print_summary
