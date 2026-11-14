#!/usr/bin/env bash
# Prova o resolver, o fragmento e a integração serial contra um repo temporário.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/integracao.sh
source "${AQUI}/lib/integracao.sh"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- resolver e fragmento, sem remoto ---

base="${TMP}/base" mainf="${TMP}/main" fase="${TMP}/fase"
cat > "$base" <<'EOF'
# CHANGELOG

- **F-001** — base — 2026-01-01
EOF
cat > "$mainf" <<'EOF'
# CHANGELOG

- **F-001** — base — 2026-01-01
- **F-002** — dois — 2026-01-02
EOF
cat > "$fase" <<'EOF'
# CHANGELOG

- **F-001** — base — 2026-01-01
- **F-010** — dez — 2026-01-03
EOF
integracao_resolver_ledger "$base" "$mainf" "$fase" F-010 > "${TMP}/out"
grep -F -q -- '- **F-002** — dois — 2026-01-02' "${TMP}/out"
grep -F -q -- '- **F-010** — dez — 2026-01-03' "${TMP}/out"
teste_ok "ledger junta as duas linhas novas"

cat > "$base" <<'EOF'
# ROADMAP

## Próximas

- **F-010** — alfa
- **F-011** — beta
EOF
cat > "$mainf" <<'EOF'
# ROADMAP

## Próximas

- **F-011** — beta
- **F-012** — nova
EOF
cat > "$fase" <<'EOF'
# ROADMAP

## Próximas

- **F-010** — alfa
EOF
integracao_resolver_ledger "$base" "$mainf" "$fase" F-011 > "${TMP}/out"
grep -F -q -- '- **F-012** — nova' "${TMP}/out"
if grep -F -q -- '**F-011**' "${TMP}/out" || grep -F -q -- '**F-010**' "${TMP}/out"; then
  teste_falha "roadmap não devia ressuscitar F-010 nem manter a linha da fase"
  cat "${TMP}/out" >&2
else
  teste_ok "roadmap tira a linha da fase e não ressuscita a que a main já tirou"
fi

cat > "$fase" <<'EOF'
# ROADMAP editado

## Próximas

- **F-010** — alfa
- **F-011** — beta
EOF
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-011 >"${TMP}/out" 2>"${TMP}/err"; then
  teste_falha "reescrever o título do roadmap deveria ser conflito não trivial"
else
  teste_ok "reescrever linha que não é da fase para o resolver"
fi

cat > "$base" <<'EOF'
# CHANGELOG

- **F-001** — base — 2026-01-01
EOF
cat > "$mainf" <<'EOF'
# CHANGELOG

- **F-001** — editada na main — 2026-01-01
EOF
cat > "$fase" <<'EOF'
# CHANGELOG

- **F-001** — editada na fase — 2026-01-01
EOF
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-010 >"${TMP}/out" 2>"${TMP}/err"; then
  teste_falha "os dois lados reescreverem linha alheia deveria ser conflito não trivial"
  cat "${TMP}/out" >&2
else
  teste_ok "os dois lados reescrevem linha alheia e o resolver para"
fi

cat > "$fase" <<'EOF'
# CHANGELOG
EOF
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-010 >"${TMP}/out" 2>"${TMP}/err"; then
  teste_falha "a fase apagar linha alheia que a main reescreveu deveria parar"
else
  teste_ok "fase que apaga linha alheia para mesmo se a main reescreveu"
fi

cat > "$base" <<'EOF'
# ROADMAP

## Próximas

- **F-020** — gama — depende de F-010
EOF
cp "$base" "$mainf"
printf '\n' >> "$fase"
cat > "$fase" <<'EOF'
# ROADMAP

## Próximas
EOF
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-010 >"${TMP}/out" 2>"${TMP}/err"; then
  teste_falha "menção 'depende de' não autoriza apagar a linha de outra fase"
else
  teste_ok "menção depende-de não é linha da fase"
fi

if integracao_sobrepoe "src/notas/" "src/notas/tags.ts"; then
  teste_ok "diretório com barra cobre o arquivo"
else
  teste_falha "diretório com barra deveria cobrir o arquivo"
fi
if integracao_sobrepoe "src/notas" "src/notas/tags.ts"; then
  teste_falha "arquivo sem barra não cobre o diretório"
else
  teste_ok "arquivo sem barra não cobre o diretório"
fi

repo="${TMP}/frag"
mkdir -p "$repo/docs/history" "$repo/docs/fases-ativas" "$repo/docs/changes"
cat > "$repo/docs/CHANGELOG.md" <<'EOF'
# CHANGELOG

- **F-001** — base — 2026-01-01
EOF
cat > "$repo/docs/ROADMAP.md" <<'EOF'
# ROADMAP

## Atual

## Próximas

- **F-010** — alfa
- **F-020** — velho
EOF
cat > "$repo/docs/DECISOES.md" <<'EOF'
# DECISÕES

## Método

| ADR | Título | Status |
| --- | ------ | ------ |
| ADR-001 | Canal | accepted |

## Plataforma

| ADR | Título | Status |
| --- | ------ | ------ |
EOF
printf '%s\n' '# DÉBITO TÉCNICO' '' '**D-001** — um débito — baixa' > "$repo/docs/DEBITO-TECNICO.md"
printf '%s\n' '# DÉBITO RESOLVIDO' '' > "$repo/docs/history/DEBITO-RESOLVIDO.md"
printf '%s\n' '# SETUP — histórico' '' '- F-001 — base' > "$repo/docs/history/SETUP-HISTORICO.md"
echo registro > "$repo/docs/fases-ativas/F-010.md"
integracao_escrever_fragmento_vazio "$repo/docs/changes/F-010.md" F-010
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" changelog '- **F-010** — alfa — 2026-11-14'
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" historico '- F-010 — alfa'
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" roadmap-remove 'F-010'
integracao_enfileirar_no_fragmento "$repo/docs/changes/F-010.md" '- **F-020** — novo — depende de F-010'
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" decisoes 'secao: Método'
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" decisoes '| ADR-002 | Paralela | accepted |'
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" debito-resolve 'D-001'
integracao_anexar_na_secao "$repo/docs/changes/F-010.md" debito-resolvido '**D-001** — resolvido na F-010'
integracao_aplicar_fragmento "$repo" "$repo/docs/changes/F-010.md" F-010 >/dev/null
grep -F -q -- '- **F-010** — alfa — 2026-11-14' "$repo/docs/CHANGELOG.md"
grep -F -q -- '- F-010 — alfa' "$repo/docs/history/SETUP-HISTORICO.md"
if grep -F -q -- '**F-010**' "$repo/docs/ROADMAP.md"; then
  teste_falha "fragmento não removeu F-010 do roadmap"
else
  teste_ok "fragmento remove a fase do roadmap"
fi
grep -F -q -- '- **F-020** — novo — depende de F-010' "$repo/docs/ROADMAP.md"
if grep -F -q -- 'velho' "$repo/docs/ROADMAP.md"; then
  teste_falha "linha velha de F-020 deveria sair quando a nova entra"
else
  teste_ok "fragmento troca a linha enfileirada"
fi
metodo="$(awk '/^## Método$/,/^## Plataforma$/' "$repo/docs/DECISOES.md")"
if [[ "$metodo" == *'ADR-002'* ]]; then
  teste_ok "ADR entra na seção Método"
else
  teste_falha "ADR-002 não caiu na seção Método"
  echo "$metodo" >&2
fi
plataforma="$(awk '/^## Plataforma$/,0' "$repo/docs/DECISOES.md")"
if [[ "$plataforma" == *'ADR-002'* ]]; then
  teste_falha "ADR-002 vazou para Plataforma"
else
  teste_ok "ADR não vaza da seção"
fi
if grep -q 'D-001' "$repo/docs/DEBITO-TECNICO.md"; then
  teste_falha "débito resolvido ainda está no vivo"
else
  teste_ok "débito sai do vivo"
fi
grep -F -q -- 'resolvido na F-010' "$repo/docs/history/DEBITO-RESOLVIDO.md"
if [[ -e "$repo/docs/changes/F-010.md" || -e "$repo/docs/fases-ativas/F-010.md" ]]; then
  teste_falha "fragmento ou registro sobreviveram à consolidação"
else
  teste_ok "consolidação apaga fragmento e registro"
fi

# --- duas fases paralelas entram uma depois da outra ---

bare="${TMP}/bare.git"
clone="${TMP}/clone"
teste_bare "$bare" "$clone"
spec010="${TMP}/spec010.md"
spec011="${TMP}/spec011.md"
printf '%s\n' '# F-010 — alfa' > "$spec010"
printf '%s\n' '# F-011 — beta' > "$spec011"

out010="$(cd "$clone" && bash "${AQUI}/abrir-fase.sh" --id F-010 --slug alfa --spec "$spec010" --arquivos 'src/alfa/' --titulo 'alfa' --escopo 'fase alfa' --destino "${TMP}/wt-010")"
wt010="$(printf '%s\n' "$out010" | sed -n 's/^worktree: //p' | tail -n 1)"
out011="$(cd "$clone" && bash "${AQUI}/abrir-fase.sh" --id F-011 --slug beta --spec "$spec011" --arquivos 'src/beta/' --titulo 'beta' --escopo 'fase beta' --destino "${TMP}/wt-011")"
wt011="$(printf '%s\n' "$out011" | sed -n 's/^worktree: //p' | tail -n 1)"

fechar_no_worktree() {
  local wt="$1" id="$2" arquivo="$3" texto="$4"
  mkdir -p "$(dirname "${wt}/${arquivo}")"
  printf '%s\n' "$texto" > "${wt}/${arquivo}"
  git -C "$wt" show origin/main:docs/SETUP.md > "${wt}/docs/SETUP.md"
  integracao_anexar_na_secao "${wt}/docs/changes/${id}.md" changelog "- **${id}** — ${id} entrou — 2026-11-14"
  integracao_anexar_na_secao "${wt}/docs/changes/${id}.md" roadmap-remove "$id"
  git -C "$wt" add -- "$arquivo" docs/SETUP.md "docs/changes/${id}.md"
  git -C "$wt" commit -m "feat: entrega ${id}" >/dev/null
}

fechar_no_worktree "$wt010" F-010 src/alfa/nota.txt 'alfa'
fechar_no_worktree "$wt011" F-011 src/beta/nota.txt 'beta'

(
  cd "$wt010"
  INTEGRACAO_SEM_GITHUB=1 INTEGRACAO_VALIDAR=true bash "${AQUI}/integrar-fase.sh" --id F-010
) >"${TMP}/int010" 2>"${TMP}/int010.err"

grep -F -q -- '- **F-010** — F-010 entrou — 2026-11-14' "$clone/docs/CHANGELOG.md"
if grep -F -q -- '**F-010**' "$clone/docs/ROADMAP.md"; then
  teste_falha "main ainda lista F-010 depois da integração"
else
  teste_ok "primeira fase sai do roadmap e entra no changelog"
fi
grep -F -q -- 'alfa' "$clone/src/alfa/nota.txt"
if [[ -e "$clone/docs/fases-ativas/F-010.md" ]]; then
  teste_falha "registro da F-010 ficou no main"
else
  teste_ok "main não fica com o registro"
fi

(
  cd "$wt011"
  INTEGRACAO_SEM_GITHUB=1 INTEGRACAO_VALIDAR=true bash "${AQUI}/integrar-fase.sh" --id F-011
) >"${TMP}/int011" 2>"${TMP}/int011.err"

grep -F -q -- 'F-010 entrou' "$clone/docs/CHANGELOG.md"
grep -F -q -- 'F-011 entrou' "$clone/docs/CHANGELOG.md"
grep -F -q -- 'beta' "$clone/src/beta/nota.txt"
grep -F -q -- 'alfa' "$clone/src/alfa/nota.txt"
if grep -F -q -- '**F-011**' "$clone/docs/ROADMAP.md"; then
  teste_falha "main ainda lista F-011"
else
  teste_ok "segunda fase também sai do roadmap"
fi
merges="$(git -C "$clone" rev-list --merges main | wc -l | tr -d ' ')"
if [[ "$merges" != 0 ]]; then
  teste_falha "histórico da main ganhou merge commit (${merges})"
else
  teste_ok "histórico da main continua sem merge commit"
fi
if git -C "$clone" rev-parse --verify --quiet refs/integracao/lock >/dev/null; then
  teste_falha "trava ficou presa depois das duas integrações"
else
  teste_ok "trava solta no fim"
fi

# --- conflito de lógica para; validação que falha não faz merge; trava serializa ---

bare2="${TMP}/bare2.git"
clone2="${TMP}/clone2"
teste_bare "$bare2" "$clone2"
printf '%s\n' '# F-010 — alfa' > "$spec010"
printf '%s\n' '# F-011 — beta' > "$spec011"
out010="$(cd "$clone2" && bash "${AQUI}/abrir-fase.sh" --id F-010 --slug alfa --spec "$spec010" --arquivos 'src/alfa/' --destino "${TMP}/wt2-010")"
wt010="$(printf '%s\n' "$out010" | sed -n 's/^worktree: //p' | tail -n 1)"
out011="$(cd "$clone2" && bash "${AQUI}/abrir-fase.sh" --id F-011 --slug beta --spec "$spec011" --arquivos 'src/beta/' --destino "${TMP}/wt2-011")"
wt011="$(printf '%s\n' "$out011" | sed -n 's/^worktree: //p' | tail -n 1)"
fechar_no_worktree "$wt010" F-010 src/compartilhado.txt 'versao-alfa'
fechar_no_worktree "$wt011" F-011 src/compartilhado.txt 'versao-beta'

(
  cd "$wt010"
  INTEGRACAO_SEM_GITHUB=1 INTEGRACAO_VALIDAR=true bash "${AQUI}/integrar-fase.sh" --id F-010
) >/dev/null

set +e
(
  cd "$wt011"
  INTEGRACAO_SEM_GITHUB=1 INTEGRACAO_VALIDAR=true bash "${AQUI}/integrar-fase.sh" --id F-011
) >"${TMP}/logica" 2>"${TMP}/logica.err"
rc=$?
set -e
if [[ "$rc" != 4 ]]; then
  teste_falha "conflito de lógica deveria sair 4, veio ${rc}"
  cat "${TMP}/logica.err" >&2
else
  teste_ok "conflito de lógica sai 4 e não mergeia"
fi
if grep -q 'versao-beta' "$clone2/src/compartilhado.txt" 2>/dev/null; then
  teste_falha "a versão da fase em conflito entrou no main"
else
  grep -q 'versao-alfa' "$clone2/src/compartilhado.txt"
  teste_ok "main ficou na fase que já tinha integrado"
fi
msg="$(git -C "$wt011" fetch origin refs/integracao/lock:refs/integracao/lock-vista >/dev/null 2>&1 && git -C "$wt011" log -1 --format=%s refs/integracao/lock-vista || true)"
git -C "$wt011" update-ref -d refs/integracao/lock-vista >/dev/null 2>&1 || true
if [[ "$msg" == "lock F-011" ]]; then
  teste_ok "trava continua com a fase parada no conflito"
else
  teste_falha "trava deveria ser 'lock F-011', veio '${msg}'"
fi

# a outra fase não passa por cima da trava
printf '%s\n' '# F-012 — gama' > "${TMP}/spec012.md"
# F-012 não abre: a trava é da integração, não da abertura. Seguramos a trava
# e tentamos integrar uma branch que ainda nem existe — usamos a F-010 já integrada
# só para ver o exit 3 a partir de um worktree fase/*. A F-011 está no meio do rebase.
set +e
(
  cd "$wt010"
  INTEGRACAO_SEM_GITHUB=1 INTEGRACAO_VALIDAR=true bash "${AQUI}/integrar-fase.sh" --id F-010
) >"${TMP}/trava" 2>"${TMP}/trava.err"
rc=$?
set -e
if [[ "$rc" != 3 ]]; then
  teste_falha "segunda integração com trava alheia deveria sair 3, veio ${rc}"
  cat "${TMP}/trava.err" >&2
else
  teste_ok "trava ocupada recusa a outra fase"
fi

(
  cd "$wt011"
  INTEGRACAO_SEM_GITHUB=1 bash "${AQUI}/integrar-fase.sh" --id F-011 --abortar
) >/dev/null
if git -C "$clone2" fetch origin refs/integracao/lock >/dev/null 2>&1; then
  teste_falha "abortar não soltou a trava"
else
  teste_ok "abortar solta a trava e o rebase"
fi

# validação que falha não anda o main
bare3="${TMP}/bare3.git"
clone3="${TMP}/clone3"
teste_bare "$bare3" "$clone3"
antes="$(git -C "$clone3" rev-parse main)"
out010="$(cd "$clone3" && bash "${AQUI}/abrir-fase.sh" --id F-010 --slug alfa --spec "$spec010" --arquivos 'src/alfa/' --destino "${TMP}/wt3-010")"
wt010="$(printf '%s\n' "$out010" | sed -n 's/^worktree: //p' | tail -n 1)"
fechar_no_worktree "$wt010" F-010 src/alfa/nota.txt 'alfa'
set +e
(
  cd "$wt010"
  INTEGRACAO_SEM_GITHUB=1 INTEGRACAO_VALIDAR='exit 1' bash "${AQUI}/integrar-fase.sh" --id F-010
) >"${TMP}/val" 2>"${TMP}/val.err"
rc=$?
set -e
if [[ "$rc" != 5 ]]; then
  teste_falha "validação falha deveria sair 5, veio ${rc}"
  cat "${TMP}/val.err" >&2
else
  teste_ok "validação falha sai 5"
fi
if [[ "$(git -C "$clone3" rev-parse main)" != "$antes" ]]; then
  teste_falha "main andou mesmo com a validação falhando"
else
  teste_ok "main não anda quando a validação falha"
fi
(
  cd "$wt010"
  bash "${AQUI}/integrar-fase.sh" --id F-010 --abortar
) >/dev/null

if [[ "$teste_falhou" -ne 0 ]]; then
  echo "integrar-fase.test.sh falhou" >&2
  exit 1
fi
echo "integrar-fase.test.sh passou"
