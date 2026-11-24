#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(node -p "require('$ROOT/lib/deps.js').VERSION")"
BUILD="$ROOT/.build-deb"
STAGE="$BUILD/stage"
OUT="$ROOT/dist"
DEB="$OUT/pnpm-deps-completion_${VERSION}_all.deb"

command -v dpkg-deb >/dev/null 2>&1 || {
  echo "erro: dpkg-deb e necessario para gerar o .deb" >&2
  exit 1
}

rm -rf -- "$BUILD"
mkdir -p "$STAGE" "$OUT"
cp -a "$ROOT/packaging/deb/." "$STAGE/"

install -D -m 0644 "$ROOT/lib/deps.js" "$STAGE/usr/share/pnpm-deps-completion/lib/deps.js"
install -D -m 0755 "$ROOT/bin/pnpm-deps" "$STAGE/usr/share/pnpm-deps-completion/bin/pnpm-deps"
install -D -m 0644 "$ROOT/completions/bash" "$STAGE/usr/share/pnpm-deps-completion/completions/bash"
install -D -m 0644 "$ROOT/completions/zsh" "$STAGE/usr/share/pnpm-deps-completion/completions/zsh"
install -D -m 0644 "$ROOT/README.md" "$STAGE/usr/share/doc/pnpm-deps-completion/README.md"

mkdir -p "$STAGE/usr/bin" \
  "$STAGE/usr/share/bash-completion/completions" \
  "$STAGE/usr/share/zsh/vendor-completions"
ln -sf ../share/pnpm-deps-completion/bin/pnpm-deps "$STAGE/usr/bin/pnpm-deps"
ln -sf ../../pnpm-deps-completion/completions/bash "$STAGE/usr/share/bash-completion/completions/pnpm"
ln -sf pnpm "$STAGE/usr/share/bash-completion/completions/pn"
ln -sf pnpm "$STAGE/usr/share/bash-completion/completions/pnx"
ln -sf ../../pnpm-deps-completion/completions/zsh "$STAGE/usr/share/zsh/vendor-completions/_pnpm_deps"

sed -i "s/^Version: .*/Version: $VERSION/" "$STAGE/DEBIAN/control"

dpkg-deb --build --root-owner-group "$STAGE" "$DEB" >/dev/null
rm -rf -- "$BUILD"
echo "$DEB"
