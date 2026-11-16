#!/usr/bin/env bash
# Testa o `validar.sh`: a lista dele tem todo `.test.sh` versionado (teste que existe e não roda não protege
# nada), o `--plano` não roda nada e argumento desconhecido sai 2. Imprime `ok`.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "${AQUI}/.." && pwd)"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

saida="$(cd "$RAIZ" && bash scripts/validar.sh --plano)"
faltam=""
while IFS= read -r t; do
  [[ -n "$t" ]] || continue
  if [[ "$saida" != *"▶ ${t}"$'\n'* ]]; then
    faltam="${faltam}${t} "
  fi
done < <(cd "$RAIZ" && git ls-files '*.test.sh')
if [[ -z "$faltam" ]]; then
  teste_ok "todo .test.sh versionado está na lista do validar.sh"
else
  teste_falha "fora da lista do validar.sh: ${faltam}"
fi

# O contrário: a lista não aponta teste que não existe.
sobram=""
while IFS= read -r linha; do
  t="${linha#▶ }"
  [[ "$linha" == '▶ '* && "$t" == *.test.sh ]] || continue
  [[ -f "${RAIZ}/${t}" ]] || sobram="${sobram}${t} "
done <<< "$saida"
if [[ -z "$sobram" ]]; then
  teste_ok "a lista do validar.sh só tem teste que existe"
else
  teste_falha "a lista do validar.sh aponta teste ausente: ${sobram}"
fi

if [[ "$saida" == *'validar: plano' && "$saida" != *'shellcheck'* ]]; then
  teste_ok "--plano lista e não roda"
else
  teste_falha "--plano rodou alguma coisa: ${saida}"
fi

teste_rc "argumento desconhecido sai 2" 2 bash -c "cd '$RAIZ' && bash scripts/validar.sh --xyz"

[[ "$teste_falhou" == 0 ]] || exit 1
echo ok
