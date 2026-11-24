#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/lib/deps.js"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

check_has() {
  local name="$1" haystack="$2" needle="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    printf 'ok   %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'FAIL %s (esperava: %s)\n' "$name" "$needle"
    printf '%s\n' "$haystack"
    failed=$((failed + 1))
  fi
}

check_missing() {
  local name="$1" haystack="$2" needle="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    printf 'FAIL %s (nao esperava: %s)\n' "$name" "$needle"
    failed=$((failed + 1))
  else
    printf 'ok   %s\n' "$name"
    passed=$((passed + 1))
  fi
}

run_bash_completion() {
  local dir="$1"
  shift
  (
    cd "$dir"
    # shellcheck source=/dev/null
    source "$ROOT/completions/bash"
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMP_LINE="${COMP_WORDS[*]}"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    _pnpm_deps_completion "${COMP_WORDS[0]}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[1]:-}"
    printf '%s\n' "${COMPREPLY[@]}"
  )
}

mkdir -p "$TMP/proj/src/deep" "$TMP/proj/node_modules/.bin" "$TMP/isolated"
cat > "$TMP/proj/package.json" <<'JSON'
{
  "dependencies": { "react": "^18.0.0", "@babel/core": "^7.0.0" },
  "devDependencies": { "vitest": "^1.0.0", "@types/node": "^20.0.0" },
  "optionalDependencies": { "fsevents": "^2.0.0" },
  "peerDependencies": { "react-dom": "^18.0.0" }
}
JSON
touch "$TMP/proj/node_modules/.bin/vitest" "$TMP/proj/node_modules/.bin/tsc"

deps="$(cd "$TMP/proj/src/deep" && node "$HELPER" --kind deps)"
check_has "deps: scoped de dependencies" "$deps" "@babel/core"
check_has "deps: devDependency" "$deps" "vitest"
check_has "deps: optionalDependency" "$deps" "fsevents"
check_has "deps: peerDependency" "$deps" "react-dom"
check_missing "deps: nao inventa pacote" "$deps" "nao-instalado"

described="$(cd "$TMP/proj" && node "$HELPER" --kind deps --describe)"
check_has "deps --describe" "$described" "@types/node:devDependencies"

bins="$(cd "$TMP/proj" && node "$HELPER" --kind bins)"
check_has "bins: node_modules/.bin" "$bins" "vitest"
check_has "bins: segundo binario" "$bins" "tsc"

explicit="$(cd "$TMP/isolated" && node "$HELPER" --kind deps --cwd "$TMP/proj")"
check_has "deps --cwd" "$explicit" "react"

no_manifest="$(cd "$TMP/isolated" && node "$HELPER" --kind deps)"
check_missing "deps: sem package.json" "$no_manifest" "react"
no_bins="$(cd "$TMP/isolated" && node "$HELPER" --kind bins)"
check_missing "bins: sem node_modules" "$no_bins" "vitest"

export PNPM_DEPS_COMPLETION_HELPER="$HELPER"

bash_scoped="$(run_bash_completion "$TMP/proj" pnpm update '@')"
check_has "bash: pnpm update @<TAB>" "$bash_scoped" "@babel/core"
check_has "bash: pnpm update @<TAB> (scoped dev)" "$bash_scoped" "@types/node"

bash_remove="$(run_bash_completion "$TMP/proj" pnpm rm '')"
check_has "bash: pnpm rm <TAB>" "$bash_remove" "react"

bash_exec="$(run_bash_completion "$TMP/proj" pnpm exec '')"
check_has "bash: pnpm exec <TAB>" "$bash_exec" "tsc"

bash_dir="$(run_bash_completion "$TMP/isolated" pnpm -C "$TMP/proj" why '')"
check_has "bash: pnpm -C <dir> why <TAB>" "$bash_dir" "react-dom"

# shellcheck source=/dev/null
source "$ROOT/completions/bash"
_pnpm_completion() { COMPREPLY=(fallback_official); }
COMP_WORDS=(pnpm install '')
COMP_CWORD=2
COMP_LINE='pnpm install '
COMP_POINT=13
COMPREPLY=()
_pnpm_deps_completion pnpm '' install
check_has "bash: fallback para completion oficial" "${COMPREPLY[*]}" "fallback_official"
unset -f _pnpm_completion

check_missing "instalador: sem placeholder de repo" \
  "$(grep '^REPO=' "$ROOT/install.sh")" "SEU-USUARIO"

lib_version="$(node -p "require('$ROOT/lib/deps.js').VERSION")"
installer_version="$(grep -m1 '^VERSION=' "$ROOT/install.sh" | cut -d'"' -f2)"
control_version="$(awk '/^Version:/ {print $2}' "$ROOT/packaging/deb/DEBIAN/control")"
if [[ "$lib_version" == "$installer_version" && "$lib_version" == "$control_version" ]]; then
  printf 'ok   versao consistente (%s)\n' "$lib_version"
  passed=$((passed + 1))
else
  printf 'FAIL versao divergente: lib=%s installer=%s control=%s\n' \
    "$lib_version" "$installer_version" "$control_version"
  failed=$((failed + 1))
fi

if command -v dpkg-deb >/dev/null 2>&1; then
  deb="$("$ROOT/build-deb.sh")"
  check_has "deb: pacote gerado" "$deb" "pnpm-deps-completion_"
  listing="$(dpkg-deb -c "$deb")"
  check_has "deb: CLI em /usr/bin" "$listing" "./usr/bin/pnpm-deps"
  check_has "deb: completion bash" "$listing" "bash-completion/completions/pnpm"
  check_has "deb: completion zsh" "$listing" "vendor-completions/_pnpm_deps"

  mkdir -p "$TMP/deb-root"
  dpkg-deb -x "$deb" "$TMP/deb-root"
  cli_dir="$TMP/deb-root/usr/share/pnpm-deps-completion/bin"
  cli_deps="$(cd "$TMP/proj" && node "$cli_dir/pnpm-deps" deps)"
  check_has "CLI: lista dependencias" "$cli_deps" "react"
  cli_doctor="$(cd "$TMP/proj" && node "$cli_dir/pnpm-deps" doctor)"
  check_has "CLI: doctor" "$cli_doctor" "pnpm-deps 1.0.0"

  installer_dry="$(bash "$ROOT/install.sh" --dry-run 2>&1)"
  check_has "instalador: dry-run chama apt" "$installer_dry" "apt-get install -y"
else
  printf 'skip testes de pacote (dpkg-deb nao encontrado)\n'
fi

if command -v zsh >/dev/null 2>&1; then
  if ZSH_TEST_ROOT="$ROOT" ZSH_TEST_TMP="$TMP" zsh "$ROOT/test/test.zsh" > "$TMP/zsh-out" 2>&1; then
    while IFS= read -r line; do printf '%s\n' "$line"; done < "$TMP/zsh-out"
    passed=$((passed + 1))
  else
    cat "$TMP/zsh-out"
    failed=$((failed + 1))
  fi
else
  printf 'skip teste zsh (zsh nao instalado)\n'
fi

printf '\n%d passaram, %d falharam\n' "$passed" "$failed"
(( failed == 0 ))
