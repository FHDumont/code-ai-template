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
spec="${TMP}/spec.md"
printf '%s\n' '# F-010 — alfa' > "$spec"

teste_rc "id inválido" 1 bash -c "cd '$clone' && bash '${AQUI}/abrir-fase.sh' --id 'fase-10' --slug alfa --spec '$spec' --arquivos 'src/alfa/' --sem-push"
teste_rc "slug inválido" 1 bash -c "cd '$clone' && bash '${AQUI}/abrir-fase.sh' --id F-010 --slug 'Alfa' --spec '$spec' --arquivos 'src/alfa/' --sem-push"

out="$(cd "$clone" && bash "${AQUI}/abrir-fase.sh" --id F-010 --slug alfa --spec "$spec" --arquivos 'src/alfa/' --sem-push --destino "${TMP}/wt-010" --titulo 'alfa' --escopo 'fase alfa' --enfileirar '- **F-021** — depois — depende de F-010')"
wt="$(printf '%s\n' "$out" | sed -n 's/^worktree: //p' | tail -n 1)"
if [[ -f "${wt}/docs/fases-ativas/F-010.md" && -f "${wt}/docs/changes/F-010.md" && -f "${wt}/docs/SETUP.md" ]]; then
  teste_ok "abertura grava spec, registro e fragmento"
else
  teste_falha "abertura não gravou os três arquivos"
fi
grep -q 'modo: paralela' "${wt}/docs/fases-ativas/F-010.md"
lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'F-021'* && "$lista" == *'depende de F-010'* ]]; then
  teste_ok "enfileirar na abertura aparece na fila"
else
  teste_falha "fila da abertura não apareceu"
  printf '%s\n' "$lista" >&2
fi

printf '%s\n' '# F-011 — beta' > "${TMP}/spec011.md"
teste_rc "sobreposição recusa a segunda fase" 1 bash -c "cd '$clone' && bash '${AQUI}/abrir-fase.sh' --id F-011 --slug beta --spec '${TMP}/spec011.md' --arquivos 'src/alfa/mais.ts' --sem-push --destino '${TMP}/wt-ruim'"
if [[ -d "${TMP}/wt-ruim" ]]; then
  teste_falha "worktree nasceu mesmo com sobreposição"
else
  teste_ok "sobreposição não cria worktree"
fi

(
  cd "$clone"
  bash "${AQUI}/abrir-fase.sh" --id F-011 --slug beta --spec "${TMP}/spec011.md" --arquivos 'src/beta/' --sem-push --destino "${TMP}/wt-011"
) >/dev/null
teste_ok "fase sem sobreposição abre"

teste_rc "dependência não integrada" 2 bash -c "cd '$clone' && bash '${AQUI}/abrir-fase.sh' --id F-012 --slug gama --spec '$spec' --arquivos 'src/gama/' --depende-de F-099 --sem-push --destino '${TMP}/wt-012'"

(
  cd "$clone"
  bash "${AQUI}/enfileirar.sh" --na F-011 --linha '- **F-022** — fila tardia — depende de F-011' --sem-push
) >/dev/null
if git -C "${TMP}/wt-011" log -1 --format=%s | grep -q 'enfileira'; then
  teste_ok "enfileirar numa fase já aberta commita no fragmento"
else
  teste_falha "enfileirar não commitou"
fi

echo sujo >> "${TMP}/wt-011/README.md"
teste_rc "worktree sujo recusa enfileirar" 1 bash -c "cd '$clone' && bash '${AQUI}/enfileirar.sh' --na F-011 --linha '- **F-023** — nao — depende de F-011' --sem-push"

if [[ "$teste_falhou" -ne 0 ]]; then
  echo "abrir-fase.test.sh falhou" >&2
  exit 1
fi
echo "abrir-fase.test.sh passou"
