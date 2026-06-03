#!/usr/bin/env bash
# Apply the warm-vintage theme to a Quartz v4 installation.
# Usage: ./apply.sh <quartz-dir>
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
info() { echo -e "${BLUE}→ $*${NC}"; }

QUARTZ_DIR="${1:?Usage: apply.sh <quartz-dir>}"
THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "$QUARTZ_DIR/quartz.config.ts" ]] || { echo "Error: $QUARTZ_DIR does not look like a Quartz installation." >&2; exit 1; }

# ── Fonts (quartz.config.ts) ──────────────────────────────────────────────────
info "Patching fonts in quartz.config.ts..."
sed -i 's/header: "[^"]*"/header: "Playfair Display"/' "$QUARTZ_DIR/quartz.config.ts"
sed -i 's/body: "[^"]*"/body: "Lora"/'                 "$QUARTZ_DIR/quartz.config.ts"
ok "Fonts: Playfair Display + Lora"

# ── Colors (quartz.config.ts) ─────────────────────────────────────────────────
info "Patching colors in quartz.config.ts..."
python3 - "$QUARTZ_DIR/quartz.config.ts" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
colors = {
    'light':         '"#faf7f0"',
    'lightgray':     '"#d9cdbf"',
    'gray':          '"#a08c7e"',
    'darkgray':      '"#4a3728"',
    'dark':          '"#2c1a0e"',
    'secondary':     '"#8b3a52"',
    'tertiary':      '"#b8704a"',
    'highlight':     '"rgba(201, 163, 82, 0.15)"',
    'textHighlight': '"rgba(139, 58, 82, 0.2)"',
}
for key, val in colors.items():
    text = re.sub(rf'{key}:\s*"[^"]*"', f'{key}: {val}', text)
open(path, 'w').write(text)
PYEOF
ok "Colors patched"

# ── UnderscoreFiles filter (quartz.config.ts) ─────────────────────────────────
info "Adding UnderscoreFiles filter to quartz.config.ts..."
# Add export to quartz/plugins/filters/index.ts
FILTERS_INDEX="$QUARTZ_DIR/quartz/plugins/filters/index.ts"
if ! grep -q 'UnderscoreFiles' "$FILTERS_INDEX"; then
  echo 'export { UnderscoreFiles } from "./underscoreFiles"' >> "$FILTERS_INDEX"
fi
# Add to filters array in quartz.config.ts (after RemoveDrafts)
if ! grep -q 'UnderscoreFiles' "$QUARTZ_DIR/quartz.config.ts"; then
  sed -i 's/Plugin\.RemoveDrafts()/Plugin.RemoveDrafts(), Plugin.UnderscoreFiles()/' \
    "$QUARTZ_DIR/quartz.config.ts"
fi
ok "UnderscoreFiles filter added"

# ── SiteHeader + SiteFooter components ───────────────────────────────────────
info "Installing SiteHeader and SiteFooter components..."
COMP_DIR="$QUARTZ_DIR/quartz/components"
mkdir -p "$COMP_DIR/styles"
cp "$THEME_DIR/components/SiteHeader.tsx"          "$COMP_DIR/SiteHeader.tsx"
cp "$THEME_DIR/components/SiteFooter.tsx"          "$COMP_DIR/SiteFooter.tsx"
cp "$THEME_DIR/components/styles/siteHeader.scss"  "$COMP_DIR/styles/siteHeader.scss"
cp "$THEME_DIR/components/styles/siteFooter.scss"  "$COMP_DIR/styles/siteFooter.scss"

# Patch components/index.ts — add exports if not already present
COMP_INDEX="$COMP_DIR/index.ts"
if ! grep -q 'SiteHeader' "$COMP_INDEX"; then
  # Append after last export line
  cat >> "$COMP_INDEX" <<'EOF'

// nb-website: generic site components
export { default as SiteHeader } from "./SiteHeader"
export { default as SiteFooter } from "./SiteFooter"
EOF
fi
ok "SiteHeader + SiteFooter installed"

# ── siteConfig utility ────────────────────────────────────────────────────────
info "Installing siteConfig.ts utility..."
mkdir -p "$QUARTZ_DIR/quartz/util"
cp "$THEME_DIR/util/siteConfig.ts" "$QUARTZ_DIR/quartz/util/siteConfig.ts"
ok "siteConfig.ts installed"

# ── UnderscoreFiles filter source ─────────────────────────────────────────────
info "Installing UnderscoreFiles filter source..."
cp "$THEME_DIR/filters/underscoreFiles.ts" \
   "$QUARTZ_DIR/quartz/plugins/filters/underscoreFiles.ts"
ok "underscoreFiles.ts installed"

# ── Layout ────────────────────────────────────────────────────────────────────
info "Installing quartz.layout.ts..."
cp "$THEME_DIR/quartz.layout.ts" "$QUARTZ_DIR/quartz.layout.ts"
ok "quartz.layout.ts installed"

# ── Custom SCSS ───────────────────────────────────────────────────────────────
info "Installing custom.scss..."
cp "$THEME_DIR/custom.scss" "$QUARTZ_DIR/quartz/styles/custom.scss"
ok "custom.scss installed"

echo ""
echo "warm-vintage theme applied to: $QUARTZ_DIR"
echo ""
echo "Manual follow-up:"
echo "  1. Edit content/_meta.md: set tagline, copyright, social links"
echo "  2. Edit quartz.config.ts: set pageTitle and baseUrl"
echo "  3. git add -A && git commit -m 'theme: warm-vintage' && git push"
