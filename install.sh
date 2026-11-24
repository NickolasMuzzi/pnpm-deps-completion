#!/usr/bin/env bash
set -euo pipefail

# Instalador unico: system via apt (.deb) ou --user sem root.
# Pode ser executado direto via curl, sem precisar do resto do repo.
NAME="pnpm-deps-completion"
VERSION="1.0.0"
REPO="${PNPM_DEPS_REPO:-NickolasMuzzi/pnpm-deps-completion}"
BRANCH="${PNPM_DEPS_BRANCH:-main}"
DEB_NAME="${NAME}_${VERSION}_all.deb"
DEB_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/dist/$DEB_NAME"
USER_DIR="${PNPM_DEPS_USER_HOME:-$HOME/.local/share/$NAME}"
USER_BIN="${PNPM_DEPS_USER_BIN:-$HOME/.local/bin}"
MARKER="$NAME"

MODE="system"
UNINSTALL=0
DRY=0
LOCAL=0
PREFIX=""

usage() {
  cat <<EOF
Uso: curl -fsSL .../install.sh | bash [opcoes]

Opcoes:
  --local       constroi o .deb a partir do checkout local
  --user        instala em ~/.local, sem root (completion via .bashrc/.zshrc)
  --uninstall   remove o pacote (apt purge) ou a instalacao --user
  --dry-run     mostra o que faria sem alterar nada
  --repo USER/REPO  repositorio de onde baixar o .deb
  -h, --help

Padrao: baixa o .deb e instala com apt, sem editar arquivos do usuario.
Desinstalacao: sudo apt purge $NAME
EOF
}

while (( $# )); do
  case "$1" in
    --local) LOCAL=1; shift ;;
    --user) MODE="user"; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --repo)
      if (( $# < 2 )); then echo "erro: --repo requer USER/REPO" >&2; exit 2; fi
      REPO="$2"; shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "erro: opcao desconhecida: $1" >&2; usage >&2; exit 2 ;;
  esac
done

REPO="${REPO%/}"
DEB_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/dist/$DEB_NAME"
if (( DRY )); then
  PREFIX="[dry-run] "
fi

run() {
  if (( DRY )); then
    {
      printf '[dry-run]'
      printf ' %q' "$@"
      printf '\n'
    } >&2
  else
    "$@"
  fi
}

fail() {
  printf 'erro: %s\n' "$1" >&2
  exit 1
}

if (( EUID == 0 )); then
  SUDO=()
else
  command -v sudo >/dev/null 2>&1 || fail "sudo e necessario para instalar via apt (ou use --user)"
  SUDO=(sudo)
fi

TMP=""
cleanup() {
  if [[ -n "$TMP" && -d "$TMP" ]]; then
    rm -rf -- "$TMP"
  fi
  return 0
}
trap cleanup EXIT

fetch_deb() {
  if (( LOCAL )); then
    [[ -f ./build-deb.sh ]] || fail "--local precisa ser rodado na raiz do repo"
    if (( DRY )); then
      printf '[dry-run] ./build-deb.sh\n' >&2
      printf '%s\n' "$PWD/dist/$DEB_NAME"
    else
      ./build-deb.sh
    fi
    return
  fi

  command -v curl >/dev/null 2>&1 || fail "curl e necessario para baixar o pacote"
  TMP="$(mktemp -d)"
  if (( DRY )); then
    printf '[dry-run] curl -fsSL %s -o %s\n' "$DEB_URL" "$TMP/$DEB_NAME" >&2
  else
    curl -fsSL "$DEB_URL" -o "$TMP/$DEB_NAME" || fail "falha ao baixar $DEB_URL"
  fi
  printf '%s\n' "$TMP/$DEB_NAME"
}

system_install() {
  local deb
  deb="$(fetch_deb)"
  run "${SUDO[@]}" apt-get install -y "$deb"
  printf '\n%s%s instalado. Abra um terminal novo ou rode: exec bash -l\n' "$PREFIX" "$NAME"
  printf 'Teste: pnpm-deps doctor\n'
}

system_uninstall() {
  run "${SUDO[@]}" apt-get purge -y "$NAME"
}

strip_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v begin="# >>> $MARKER >>>" -v end="# <<< $MARKER <<<" '
    $0 == begin { inside = 1; next }
    $0 == end { inside = 0; next }
    !inside { print }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

add_block() {
  local file="$1"
  shift
  mkdir -p -- "$(dirname -- "$file")"
  [[ -f "$file" ]] || : > "$file"
  {
    printf '\n# >>> %s >>>\n' "$MARKER"
    printf '# gerenciado por pnpm-deps-completion - nao edite\n'
    printf '%s\n' "$@"
    printf '# <<< %s <<<\n' "$MARKER"
  } >> "$file"
}

user_install() {
  local deb root deb_pkg src shell rc
  deb="$(fetch_deb)"
  if [[ -z "$TMP" ]]; then
    TMP="$(mktemp -d)"
  fi
  root="$TMP/root"
  deb_pkg="$root/usr/share/pnpm-deps-completion"

  if (( ! DRY )); then
    rm -rf -- "$root"
    mkdir -p "$root"
    dpkg-deb -x "$deb" "$root" || fail "falha ao extrair $deb"
    src="$deb_pkg"
  else
    src="<deb extraido>/usr/share/$NAME"
    printf '[dry-run] dpkg-deb -x %s %s\n' "$deb" "$root" >&2
  fi

  run mkdir -p "$USER_DIR/lib" "$USER_DIR/completions" "$USER_DIR/bin" "$USER_BIN"
  run cp "$src/lib/deps.js" "$USER_DIR/lib/deps.js"
  run cp "$src/completions/bash" "$USER_DIR/completions/bash"
  run cp "$src/completions/zsh" "$USER_DIR/completions/zsh"
  run cp "$src/bin/pnpm-deps" "$USER_DIR/bin/pnpm-deps"
  run chmod 0755 "$USER_DIR/bin/pnpm-deps"
  run ln -sfn "$USER_DIR/bin/pnpm-deps" "$USER_BIN/pnpm-deps"

  for shell in bash zsh; do
    rc="${HOME}/.${shell}rc"
    if (( DRY )); then
      printf '[dry-run] bloco de completion em %s\n' "$rc" >&2
    else
      strip_block "$rc"
      add_block "$rc" "source \"$USER_DIR/completions/$shell\""
    fi
  done

  if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
    if (( DRY )); then
      printf '[dry-run] bloco de PATH em %s\n' "$HOME/.profile" >&2
    else
      strip_block "$HOME/.profile"
      add_block "$HOME/.profile" "export PATH=\"$USER_BIN:\$PATH\""
    fi
  fi

  printf '\n%s%s instalado em %s\n' "$PREFIX" "$NAME" "$USER_DIR"
  printf 'Abra um terminal novo ou rode: source ~/.bashrc\n'
  printf 'Teste: pnpm-deps doctor\n'
}

user_uninstall() {
  local file
  run rm -f "$USER_BIN/pnpm-deps"
  for file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if (( DRY )); then
      printf '[dry-run] remove bloco de %s\n' "$file" >&2
    else
      strip_block "$file"
    fi
  done
  run rm -rf "$USER_DIR"
}

if (( UNINSTALL )); then
  if [[ "$MODE" == "user" ]]; then
    user_uninstall
    printf '%s%s: instalacao de usuario removida.\n' "$PREFIX" "$NAME"
  else
    system_uninstall
  fi
  exit 0
fi

if [[ "$MODE" == "user" ]]; then
  command -v dpkg-deb >/dev/null 2>&1 || fail "dpkg-deb e necessario para extrair o .deb"
  user_install
else
  system_install
fi
