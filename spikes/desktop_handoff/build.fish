#!/usr/bin/env fish
# Spike 1b build: JS bundles -> build/connect/. Run from anywhere.
set root (realpath (dirname (status filename))/../..)
cd $root/js; or exit 1
npm ci; or exit 1
npm run build; or exit 1
cd $root; or exit 1
mkdir -p build/connect
cp js/connect.html js/dist/connect.js build/connect/; or exit 1
echo "Built. Serve the connect page with:"
echo "  cd $root/build/connect; python3 -m http.server 8061"
echo "Then run the game with:"
echo "  godot --path . res://spikes/desktop_handoff/desktop_handoff.tscn"
