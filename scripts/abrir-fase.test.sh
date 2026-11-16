#!/usr/bin/env bash
# Testa o `abrir-fase.sh` e o `enfileirar.sh` (R-001 e R-005) contra um repositório descartável. Imprime `ok`.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

bare="${TMP}/bare.git"
clone="${TMP}/clone"
teste_bare "$bare" "$clone"
# Os ganchos do projeto derivado: o preparo do worktree versionado, dois arquivos fora do git no checkout
# principal (um deles pedido por `ABRIR_FASE_LINKS`) e os caminhos que só fase solitária toca.
printf '%s\n' '.env' 'node_modules/' '.claude/settings.local.json' > "$clone/.gitignore"
mkdir -p "$clone/scripts"
printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p node_modules && touch node_modules/.instalado' > "$clone/scripts/preparar-worktree.sh"
git -C "$clone" add -- .gitignore scripts/preparar-worktree.sh
git -C "$clone" commit -q -m "chore: preparo do worktree"
git -C "$clone" push -q origin main 2>/dev/null
mkdir -p "$clone/infra" "$clone/.claude"
echo 'SEGREDO=dev' > "$clone/infra/.env"
echo '{}' > "$clone/.claude/settings.local.json"
export ABRIR_FASE_LINKS='infra/.env .claude/settings.local.json'
export ABRIR_FASE_SO_SOLITARIA='db/src/schema.ts, db/migrations/'

spec="${TMP}/spec.md"
printf '%s\n' '# SETUP — fase atual' '' '# F-010 — alfa' > "$spec"
abrir() { (cd "$clone" && bash "${AQUI}/abrir-fase.sh" --spec "$spec" --sem-push "$@"); }

teste_rc "id inválido" 1 abrir --id 'fase-10' --slug alfa --arquivos 'src/alfa/'
teste_rc "slug inválido" 1 abrir --id F-010 --slug 'Alfa' --arquivos 'src/alfa/'
teste_rc "caminho só de solitária recusa a paralela" 1 abrir --id F-013 --slug banco --arquivos 'src/x/, db/migrations/' --destino "${TMP}/wt-banco"
teste_rc "o schema também" 1 abrir --id F-013 --slug banco --arquivos 'db/src/schema.ts' --destino "${TMP}/wt-banco"
teste_rc "db/ inteiro cruza as migrations" 1 abrir --id F-013 --slug banco --arquivos 'db/' --destino "${TMP}/wt-banco"
if [[ -d "${TMP}/wt-banco" ]] || ! grep -q 'sempre solitária' "${TMP}/teste-err"; then
  teste_falha "a recusa de db/ criou worktree ou não disse por quê"
else
  teste_ok "a recusa de db/ não cria worktree e diz por quê"
fi
ABRIR_FASE_SO_SOLITARIA='' teste_rc "sem a lista, db/ abre como qualquer caminho" 0 abrir --id F-013 --slug banco --arquivos 'db/' --destino "${TMP}/wt-banco"
git -C "$clone" worktree remove --force "${TMP}/wt-banco"
git -C "$clone" update-ref -d refs/heads/fase/F-013-banco

out="$(abrir --id F-010 --slug alfa --arquivos 'src/alfa/' --destino "${TMP}/wt-010" --titulo 'alfa' --escopo 'fase alfa' --enfileirar '**F-021** — depois — depende de F-010' 2>"${TMP}/abrir.err")"
wt="$(printf '%s\n' "$out" | sed -n 's/^worktree: //p' | tail -n 1)"
if [[ -f "${wt}/docs/fases-ativas/F-010.md" && -f "${wt}/docs/changes/F-010.md" ]] && grep -q '^# F-010' "${wt}/docs/SETUP.md" \
  && grep -qx 'modo: paralela' "${wt}/docs/fases-ativas/F-010.md" && [[ "$(git -C "$wt" log -1 --format=%s)" == 'docs: abre F-010' ]]; then
  teste_ok "abertura grava spec, registro e fragmento num commit"
else
  teste_falha "abertura não gravou os três arquivos"
fi
if [[ -f "${wt}/node_modules/.instalado" && -L "${wt}/infra/.env" && "$(readlink "${wt}/infra/.env")" == "${clone}/infra/.env" \
  && -L "${wt}/.claude/settings.local.json" && -z "$(git -C "$wt" status --porcelain)" ]]; then
  teste_ok "o worktree nasce preparado e com os links pedidos, limpo"
else
  teste_falha "o worktree não nasceu pronto"
  ls -la "$wt" "${wt}/infra" >&2 || true
fi
# A sessão da fase nasce no checkout principal (Amplug F-110): a abertura imprime o prompt com o caminho do worktree
# e avisa, com a linha pronta, quando a pasta dos worktrees não está no additionalDirectories (só leitura).
if [[ "$out" == *"sessão: abra no checkout principal (${clone})"* && "$out" == *"prompt: Executa a fase F-010 do SETUP em ${TMP}/wt-010/docs/SETUP.md"* ]] \
  && grep -qF "\"${TMP}\"" "${TMP}/abrir.err" && grep -q 'additionalDirectories' "${TMP}/abrir.err" \
  && [[ "$(cat "$clone/.claude/settings.local.json")" == '{}' ]]; then
  teste_ok "a abertura imprime o prompt da sessão no principal e avisa do additionalDirectories sem editar"
else
  teste_falha "a abertura não imprimiu o prompt ou não avisou do additionalDirectories"
  printf '%s\n' "$out" >&2; cat "${TMP}/abrir.err" >&2 || true
fi
if [[ "$out" == *"Termine todo turno com a placa de estado (\`AGENTS.md\` §Placa de estado)"* ]]; then
  teste_ok "o prompt da fase pede a placa de estado (F-120)"
else
  teste_falha "o prompt da fase não pede a placa de estado"
fi
lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'F-021'* && "$lista" == *'depende de F-010'* ]]; then
  teste_ok "enfileirar na abertura aparece na fila"
else
  teste_falha "fila da abertura não apareceu"
  printf '%s\n' "$lista" >&2
fi

printf '%s\n' '# F-011 — beta' > "${TMP}/spec011.md"
teste_rc "sobreposição recusa a segunda fase" 1 abrir --id F-011 --slug beta --arquivos 'src/alfa/mais.ts' --destino "${TMP}/wt-ruim"
if [[ -d "${TMP}/wt-ruim" ]]; then
  teste_falha "worktree nasceu mesmo com sobreposição"
else
  teste_ok "sobreposição não cria worktree"
fi
printf '%s\n' "{\"permissions\":{\"additionalDirectories\":[\"${TMP}\"]}}" > "$clone/.claude/settings.local.json"
teste_rc "fase sem sobreposição abre" 0 abrir --id F-011 --slug beta --arquivos 'src/beta/' --destino "${TMP}/wt-011"
if grep -q 'additionalDirectories' "${TMP}/teste-err"; then
  teste_falha "avisou do additionalDirectories com a pasta já lá"
else
  teste_ok "com a pasta no additionalDirectories, a abertura não avisa"
fi
teste_rc "dependência fora do CHANGELOG sai 2" 2 abrir --id F-012 --slug gama --arquivos 'src/gama/' --depende-de F-099 --destino "${TMP}/wt-012"
teste_rc "dependência no CHANGELOG abre" 0 abrir --id F-014 --slug delta --arquivos 'src/delta/' --depende-de F-001 --destino "${TMP}/wt-014"
teste_rc "id já no CHANGELOG não abre" 1 abrir --id F-001 --slug base --arquivos 'src/base/' --destino "${TMP}/wt-001"

teste_rc "enfileirar numa fase já aberta" 0 bash -c "cd '$clone' && bash '${AQUI}/enfileirar.sh' --na F-011 --linha '**F-022** — fila tardia — depende de F-011' --sem-push"
if [[ "$(git -C "${TMP}/wt-011" log -1 --format=%s)" == 'docs: enfileira depois de F-011' ]] \
  && grep -qxF '**F-022** — fila tardia — depende de F-011' "${TMP}/wt-011/docs/changes/F-011.md"; then
  teste_ok "enfileirar commita no fragmento"
else
  teste_falha "enfileirar não commitou"
fi
echo sujo >> "${TMP}/wt-011/README.md"
teste_rc "worktree sujo recusa enfileirar" 1 bash -c "cd '$clone' && bash '${AQUI}/enfileirar.sh' --na F-011 --linha '**F-023** — nao — depende de F-011' --sem-push"

if [[ "$teste_falhou" -ne 0 ]]; then
  echo "abrir-fase.test.sh falhou" >&2
  exit 1
fi
echo ok
