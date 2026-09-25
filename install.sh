#!/bin/sh
# Install roulette into ~/.local/bin (or the directory given as $1).
set -e
dest=${1:-$HOME/.local/bin}
here=$(cd "$(dirname "$0")" && pwd)

command -v jq >/dev/null 2>&1 || echo "note: roulette needs jq — install it with: brew install jq" >&2

mkdir -p "$dest"
cp "$here/roulette" "$dest/roulette"
chmod +x "$dest/roulette"
ln -sf roulette "$dest/rt"

echo "installed $dest/roulette (shortcut: rt)"
case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "add $dest to your PATH to use it" ;;
esac
