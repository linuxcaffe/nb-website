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

# ── Remove Graph component (quartz.layout.ts) ─────────────────────────────────
info "Removing Graph() from quartz.layout.ts..."
sed -i '/Component\.Graph(),/d' "$QUARTZ_DIR/quartz.layout.ts"
ok "Graph() removed"

# ── Custom SCSS ───────────────────────────────────────────────────────────────
info "Installing custom.scss..."
cp "$THEME_DIR/custom.scss" "$QUARTZ_DIR/quartz/styles/custom.scss"
ok "custom.scss installed"

# ── Footer (quartz.layout.ts) — remove Quartz project links ──────────────────
info "Clearing default footer links..."
# Replace the Quartz project links block with an empty links object.
# Edit quartz.layout.ts manually to add your own links (eBay, Etsy, etc.).
python3 - "$QUARTZ_DIR/quartz.layout.ts" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
# Replace the links block inside Footer({...}) with empty links
text = re.sub(
    r'(Component\.Footer\(\{[^}]*links:\s*)\{[^}]*\}',
    r'\1{}',
    text,
    flags=re.DOTALL
)
open(path, 'w').write(text)
PYEOF
ok "Footer links cleared (add yours in quartz.layout.ts)"

echo ""
echo "warm-vintage theme applied to: $QUARTZ_DIR"
echo ""
echo "Manual follow-up:"
echo "  1. Add footer links in quartz.layout.ts (eBay, Etsy store URLs)"
echo "  2. git add -A && git commit -m 'theme: warm-vintage' && git push"
