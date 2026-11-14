#!/usr/bin/env bash
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bare="${TMP}/bare.git"
clone="${TMP}/clone"
teste_bare "$bare" "$clone"

lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'(nenhuma)'* && "$lista" == *'depende de F-099'* ]]; then
  teste_ok "sem fase ativa, a fila do roadmap aparece"
else
  teste_falha "lista inicial inesperada"
  printf '%s\n' "$lista" >&2
fi

spec="${TMP}/spec.md"
printf '%s\n' '# F-010 — alfa' > "$spec"
(
  cd "$clone"
  bash "${AQUI}/abrir-fase.sh" --id F-010 --slug alfa --spec "$spec" --arquivos 'src/alfa/' --sem-push --destino "${TMP}/wt-010" --titulo 'alfa' --escopo 'fase alfa'
) >/dev/null

if (cd "$clone" && bash "${AQUI}/fases-ativas.sh" --sobrepor src/alfa/nota.txt) >/dev/null 2>"${TMP}/err"; then
  teste_falha "src/alfa/nota.txt deveria sobrepor a fase"
else
  grep -q 'sobrepõe F-010' "${TMP}/err"
  teste_ok "sobreposição acusa o caminho reivindicado"
fi
if (cd "$clone" && bash "${AQUI}/fases-ativas.sh" --sobrepor src/beta/nota.txt) >/dev/null; then
  teste_ok "caminho fora da reivindicação passa"
else
  teste_falha "src/beta não deveria sobrepor src/alfa/"
fi

git -C "$clone" checkout -b fase/F-030-solta >/dev/null
echo solta >> "$clone/README.md"
git -C "$clone" add -- README.md
git -C "$clone" commit -m "feat: solta" >/dev/null
git -C "$clone" checkout main >/dev/null

lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'repo-inteiro'* && "$lista" == *'fase/F-030-solta'* ]]; then
  teste_ok "branch sem registro reivindica o repo inteiro"
else
  teste_falha "solitária implícita não apareceu"
  printf '%s\n' "$lista" >&2
fi
if (cd "$clone" && bash "${AQUI}/fases-ativas.sh" --sobrepor README.md) >/dev/null 2>&1; then
  teste_falha "repo inteiro deveria bloquear qualquer caminho"
else
  teste_ok "repo inteiro bloqueia o caminho"
fi

printf '%s\n' '# F-040 — local' > "$clone/docs/SETUP.md"
lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'## F-040'* && "$lista" == *'working tree'* ]]; then
  teste_ok "spec solitária no SETUP da main aparece como ativa"
else
  teste_falha "spec no SETUP da main não entrou na lista"
  printf '%s\n' "$lista" >&2
fi

if [[ "$teste_falhou" -ne 0 ]]; then
  echo "fases-ativas.test.sh falhou" >&2
  exit 1
fi
echo "fases-ativas.test.sh passou"
