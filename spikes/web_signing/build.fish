#!/usr/bin/env fish
# Spike 1a build: JS bundle -> web export -> copy bundle. Run from anywhere.
set root (realpath (dirname (status filename))/../..)
cd $root/js; or exit 1
npm ci; or exit 1
npm run build; or exit 1
cd $root; or exit 1
mkdir -p build/web
godot --headless --path . --import; or exit 1
godot --headless --path . --export-release Web build/web/index.html; or exit 1
cp js/dist/sui_bridge.js build/web/sui_bridge.js; or exit 1
echo "Built. Serve with:"
echo "  cd $root/build/web; python3 -m http.server 8060"
echo "Then open http://localhost:8060/ (localhost counts as a secure context)."
