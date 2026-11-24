#!/usr/bin/env zsh
set -euo pipefail

ROOT="${ZSH_TEST_ROOT:?}"
TMP="${ZSH_TEST_TMP:?}"

# Permite testar com um zsh extraido, sem instalacao no sistema.
if [[ -n "${ZSH_TEST_MODULE_PATH:-}" ]]; then
  module_path=("$ZSH_TEST_MODULE_PATH" $module_path)
fi

export PNPM_DEPS_COMPLETION_HELPER="$ROOT/lib/deps.js"

# O teste nao precisa do compinit: so verifica a logica de geracao das opcoes.
if (( ! $+functions[compdef] )); then
  compdef() { : }
fi

# shellcheck source=/dev/null
source "$ROOT/completions/zsh"

# Substitui _describe para capturar as opcoes sem um contexto de completion real.
_describe() {
  local name
  shift
  for name in "$@"; do
    print -l -- "${(P)name}"
  done
}

cd "$TMP/proj"

words=(pnpm update '@')
CURRENT=3
out="$(_pnpm_deps_completion pnpm '@' update)"
[[ "$out" == *"@babel/core:dependencies"* ]] || { print -u2 "zsh: faltou @babel/core"; exit 1; }
[[ "$out" == *"@types/node:devDependencies"* ]] || { print -u2 "zsh: faltou @types/node"; exit 1; }
print -r -- 'ok   zsh: pnpm update @<TAB>'

words=(pnpm exec '')
CURRENT=3
out="$(_pnpm_deps_completion pnpm '' exec)"
[[ "$out" == *"tsc:bin"* ]] || { print -u2 "zsh: faltou tsc"; exit 1; }
print -r -- 'ok   zsh: pnpm exec <TAB>'

words=(pnpm -C "$TMP/proj" why '')
CURRENT=5
cd "$TMP"
out="$(_pnpm_deps_completion pnpm '' why)"
[[ "$out" == *"react-dom:peerDependencies"* ]] || { print -u2 "zsh: falhou -C"; exit 1; }
print -r -- 'ok   zsh: pnpm -C <dir> why <TAB>'
