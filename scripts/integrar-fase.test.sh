#!/usr/bin/env bash
# Testa a integração das fases (R-003 e R-004): o resolver e o fragmento contra cópias dos ledgers
# e a integração serial em repositório descartável. Imprime `ok`.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "${AQUI}/.." && pwd)"
# shellcheck source=lib/integracao.sh
source "${AQUI}/lib/integracao.sh"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

# O gh falso e o ambiente do fecho comum (o `base` dele, apagado no trap dele, é o nosso TMP).
aqui="$AQUI"
# shellcheck source=fecho-teste-comum.sh
. "${AQUI}/fecho-teste-comum.sh"
TMP="$(cd "$base" && pwd -P)"
export FECHO_WT_TRILHA="${TMP}/wt-trilha"

# Quantas vezes o arquivo tem duas linhas em branco seguidas.
brancas_dobradas() { awk 'prev == "" && NR > 1 && $0 == "" { n++ } { prev = $0 } END { print n + 0 }' "$1"; }
# As linhas não vazias, sem as que contêm o texto (pra comparar o que não é da fase).
sem() { grep -v '^$' "$1" | grep -vF -- "$2" || true; }
# A linha imediatamente antes e depois da que contém o texto fixo.
vizinhas_brancas() { # <arquivo> <texto> — 0 se a linha tem branca antes e (se não for a última) depois
  awk -v t="$2" '{ L[NR] = $0 } END { for (i = 1; i <= NR; i++) if (index(L[i], t) > 0) {
    if (i > 1 && L[i - 1] != "") exit 1; if (i < NR && L[i + 1] != "") exit 1; achou = 1 }
    exit achou ? 0 : 1 }' "$1"
}

# --- resolver: duas fases acrescentam parágrafo no CHANGELOG real ---

base="${TMP}/base" mainf="${TMP}/main" fase="${TMP}/fase" out="${TMP}/out"
cp "${RAIZ}/docs/CHANGELOG.md" "$base"
cp "$base" "$mainf"; _integracao_acrescentar_se_falta "$mainf" '**F-901** — a primeira — 2026-11-15'
cp "$base" "$fase"; _integracao_acrescentar_se_falta "$fase" '**F-900** — a segunda — 2026-11-15'
integracao_resolver_ledger "$base" "$mainf" "$fase" F-900 > "$out"
if grep -qF '**F-901**' "$out" && grep -qF '**F-900**' "$out" \
  && [[ "$(grep -n 'F-901' "$out" | cut -d: -f1)" -lt "$(grep -n 'F-900' "$out" | cut -d: -f1)" ]]; then
  teste_ok "CHANGELOG fica com os dois parágrafos, o da fase depois do que a main já tinha"
else
  teste_falha "CHANGELOG sem os dois parágrafos em ordem"
fi
if vizinhas_brancas "$out" '**F-900**' && vizinhas_brancas "$out" '**F-901**' \
  && [[ "$(brancas_dobradas "$out")" == "$(brancas_dobradas "$base")" ]]; then
  teste_ok "CHANGELOG combinado mantém uma linha em branco entre parágrafos"
else
  teste_falha "CHANGELOG combinado perdeu ou dobrou a linha em branco"
  tail -6 "$out" >&2
fi
if [[ "$(sem "$out" 'F-90')" == "$(sem "$base" 'F-90')" ]]; then
  teste_ok "CHANGELOG combinado não toca parágrafo de outra fase"
else
  teste_falha "CHANGELOG combinado mexeu em parágrafo alheio"
fi

# --- resolver: o ledger em lista (`- **F-xxx** — …`) fica colado, sem linha em branco entre os itens ---

printf '%s\n' '# CHANGELOG' '' '- **F-001** — base — 2026-01-01' > "$base"
cp "$base" "$mainf"; _integracao_acrescentar_se_falta "$mainf" '- **F-901** — a primeira — 2026-11-15'
cp "$base" "$fase"; _integracao_acrescentar_se_falta "$fase" '- **F-900** — a segunda — 2026-11-15'
integracao_resolver_ledger "$base" "$mainf" "$fase" F-900 > "$out"
if [[ "$(cat "$out")" == "$(printf '%s\n' '# CHANGELOG' '' '- **F-001** — base — 2026-01-01' '- **F-901** — a primeira — 2026-11-15' '- **F-900** — a segunda — 2026-11-15')" ]]; then
  teste_ok "CHANGELOG em lista fica com os dois itens colados, o da fase por último"
else
  teste_falha "CHANGELOG em lista saiu errado"
  cat "$out" >&2
fi
_integracao_tirar_paragrafo "$out" '**F-901**'
if [[ "$(cat "$out")" == "$(printf '%s\n' '# CHANGELOG' '' '- **F-001** — base — 2026-01-01' '- **F-900** — a segunda — 2026-11-15')" ]]; then
  teste_ok "item de lista sai sem deixar linha em branco"
else
  teste_falha "tirar item de lista deixou sobra"
  cat "$out" >&2
fi

# --- acrescentar: o ledger em lista que termina com linha em branco (o CHANGELOG real deste template) ---

printf '%s\n' '# CHANGELOG' '' '- **F-001** — base — 2026-01-01' '' > "$out"
_integracao_acrescentar_se_falta "$out" '- **F-900** — a fase — 2026-11-15'
if [[ "$(cat "$out")" == "$(printf '%s\n' '# CHANGELOG' '' '- **F-001** — base — 2026-01-01' '- **F-900** — a fase — 2026-11-15')" ]]; then
  teste_ok "item de lista entra colado no anterior, mesmo com linha em branco no fim do ledger"
else
  teste_falha "item de lista ficou separado por linha em branco"
  cat -e "$out" >&2
fi
printf '%s\n' '# CHANGELOG' '' > "$out"
_integracao_acrescentar_se_falta "$out" '- **F-900** — a fase — 2026-11-15'
if [[ "$(cat "$out")" == "$(printf '%s\n' '# CHANGELOG' '' '- **F-900** — a fase — 2026-11-15')" ]]; then
  teste_ok "primeiro item da lista mantém a linha em branco depois do título"
else
  teste_falha "primeiro item da lista colou no título"
  cat -e "$out" >&2
fi

# --- resolver: a fase tira a si do ROADMAP real enquanto a main acrescenta outra ---

cp "${RAIZ}/docs/ROADMAP.md" "$base"
integracao_anexar_na_secao "$base" "Próximas" '**F-900** — a fase — depende de F-001'
cp "$base" "$mainf"; integracao_anexar_na_secao "$mainf" "Próximas" '**F-902** — a da main'
cp "$base" "$fase"; _integracao_tirar_paragrafo "$fase" '**F-900**'
integracao_resolver_ledger "$base" "$mainf" "$fase" F-900 > "$out"
if ! grep -qF '**F-900**' "$out" && grep -qF '**F-902**' "$out" && vizinhas_brancas "$out" '**F-902**' \
  && [[ "$(brancas_dobradas "$out")" == "$(brancas_dobradas "$base")" ]] \
  && [[ "$(sem "$out" 'F-90')" == "$(sem "$base" 'F-90')" ]]; then
  teste_ok "ROADMAP tira a linha da fase, fica com a da main e não dobra branca"
else
  teste_falha "ROADMAP combinado errado"
  diff "$base" "$out" >&2 || true
fi

# --- resolver: o que não é trivial para ---

printf '%s\n' '# ROADMAP' '' '## Próximas' '' '**F-010** — alfa' '' '**F-011** — beta' > "$base"
printf '%s\n' '# ROADMAP' '' '## Próximas' '' '**F-011** — beta' '' '**F-012** — nova' > "$mainf"
printf '%s\n' '# ROADMAP editado' '' '## Próximas' '' '**F-010** — alfa' > "$fase"
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-011 >"$out" 2>/dev/null; then
  teste_falha "reescrever o título do roadmap deveria ser conflito não trivial"
else
  teste_ok "reescrever linha que não é da fase para o resolver"
fi
printf '%s\n' '# CHANGELOG' '' '**F-001** — base — 2026-01-01' > "$base"
printf '%s\n' '# CHANGELOG' '' '**F-001** — editada na main — 2026-01-01' > "$mainf"
printf '%s\n' '# CHANGELOG' '' '**F-001** — editada na fase — 2026-01-01' > "$fase"
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-010 >"$out" 2>/dev/null; then
  teste_falha "os dois lados reescreverem linha alheia deveria ser conflito não trivial"
else
  teste_ok "os dois lados reescrevem linha alheia e o resolver para"
fi
printf '%s\n' '# ROADMAP' '' '## Próximas' '' '**F-020** — gama — depende de F-010' > "$base"
cp "$base" "$mainf"
printf '%s\n' '# ROADMAP' '' '## Próximas' > "$fase"
if integracao_resolver_ledger "$base" "$mainf" "$fase" F-010 >"$out" 2>/dev/null; then
  teste_falha "menção 'depende de' não autoriza apagar a linha de outra fase"
else
  teste_ok "menção depende-de não é linha da fase"
fi

if integracao_sobrepoe "src/notas/" "src/notas/tags.ts" && ! integracao_sobrepoe "src/notas" "src/notas/tags.ts"; then
  teste_ok "diretório com barra cobre o arquivo; arquivo sem barra não cobre"
else
  teste_falha "integracao_sobrepoe errado"
fi

# --- fragmento aplicado nos ledgers reais ---

repo="${TMP}/frag"
mkdir -p "$repo/docs/history" "$repo/docs/fases-ativas" "$repo/docs/changes"
for f in CHANGELOG.md ROADMAP.md DECISOES.md DEBITO-TECNICO.md history/SETUP-HISTORICO.md history/DEBITO-RESOLVIDO.md; do
  cp "${RAIZ}/docs/${f}" "${repo}/docs/${f}"
done
integracao_anexar_na_secao "$repo/docs/ROADMAP.md" "Próximas" '**F-900** — a fase'
integracao_anexar_na_secao "$repo/docs/ROADMAP.md" "Próximas" '**F-910** — velho — depende de F-900'
_integracao_acrescentar_se_falta "$repo/docs/DEBITO-TECNICO.md" '**D-900** — um débito — 🔵 baixo. Correção: nenhuma.'
for f in CHANGELOG.md ROADMAP.md DEBITO-TECNICO.md; do cp "$repo/docs/$f" "${TMP}/antes-$f"; done
echo registro > "$repo/docs/fases-ativas/F-900.md"
frag="$repo/docs/changes/F-900.md"
integracao_escrever_fragmento_vazio "$frag" F-900
integracao_anexar_na_secao "$frag" changelog '**F-900** — a fase entrou — 2026-11-15'
# shellcheck disable=SC2016 # o crase é markdown, não expansão
integracao_anexar_na_secao "$frag" historico '- F-900 — a fase → [`fases/F-900.md`](fases/F-900.md)'
integracao_anexar_na_secao "$frag" roadmap-remove 'F-900'
integracao_enfileirar_no_fragmento "$frag" '**F-910** — novo — depende de F-900'
integracao_anexar_na_secao "$frag" decisoes 'secao: Método'
integracao_anexar_na_secao "$frag" decisoes '| ADR-900 | Paralela | accepted |'
integracao_anexar_na_secao "$frag" debito-resolve 'D-900'
integracao_anexar_na_secao "$frag" debito-resolvido '**D-900** — um débito — 🔵 baixo. Correção: nenhuma.'
integracao_anexar_na_secao "$frag" debito-resolvido '> Resolvido na F-900 (2026-11-15): teste.'
integracao_aplicar_fragmento "$repo" "$frag" F-900 > "${TMP}/tocados"

c="$repo/docs/CHANGELOG.md" r="$repo/docs/ROADMAP.md"
if [[ "$(tail -n 1 "$c")" == '**F-900** — a fase entrou — 2026-11-15' ]] && vizinhas_brancas "$c" '**F-900**' \
  && [[ "$(sem "$c" 'F-900')" == "$(sem "${TMP}/antes-CHANGELOG.md" 'F-900')" ]] \
  && [[ "$(brancas_dobradas "$c")" == "$(brancas_dobradas "${TMP}/antes-CHANGELOG.md")" ]]; then
  teste_ok "fragmento no CHANGELOG real: parágrafo no fim, uma branca antes, nada alheio tocado"
else
  teste_falha "fragmento no CHANGELOG real errado"
  tail -4 "$c" >&2
fi
if ! grep -qF '**F-900**' "$r" && grep -qxF '**F-910** — novo — depende de F-900' "$r" && ! grep -qF 'velho' "$r" \
  && vizinhas_brancas "$r" '**F-910**' \
  && [[ "$(sem "$r" 'F-9')" == "$(sem "${TMP}/antes-ROADMAP.md" 'F-9')" ]] \
  && [[ "$(brancas_dobradas "$r")" == "$(brancas_dobradas "${TMP}/antes-ROADMAP.md")" ]]; then
  teste_ok "fragmento no ROADMAP real: tira a fase, troca a enfileirada, uma branca entre parágrafos"
else
  teste_falha "fragmento no ROADMAP real errado"
  diff "${TMP}/antes-ROADMAP.md" "$r" >&2 || true
fi
metodo="$(awk '/^## Método$/,/^## Plataforma$/' "$repo/docs/DECISOES.md")"
if [[ "$metodo" == *'| ADR-900 | Paralela | accepted |'* ]] && ! awk '/^## Plataforma$/,0' "$repo/docs/DECISOES.md" | grep -q 'ADR-900'; then
  teste_ok "ADR entra na tabela da seção Método e não vaza"
else
  teste_falha "ADR-900 fora da seção Método"
fi
d="$repo/docs/DEBITO-TECNICO.md"
if ! grep -q 'D-900' "$d" && [[ "$(brancas_dobradas "$d")" == "$(brancas_dobradas "${TMP}/antes-DEBITO-TECNICO.md")" ]] \
  && [[ "$(tail -n 3 "$repo/docs/history/DEBITO-RESOLVIDO.md" | head -n 1)" == '**D-900**'* ]] \
  && vizinhas_brancas "$repo/docs/history/DEBITO-RESOLVIDO.md" '> Resolvido na F-900'; then
  teste_ok "débito sai do vivo e entra no resolvido com a nota em parágrafo"
else
  teste_falha "débito mal movido"
fi
if [[ "$(tail -n 1 "$repo/docs/history/SETUP-HISTORICO.md")" == '- F-900 — a fase'* ]] \
  && [[ -n "$(tail -n 2 "$repo/docs/history/SETUP-HISTORICO.md" | head -n 1)" ]]; then
  teste_ok "histórico entra como item da lista, colado no anterior"
else
  teste_falha "histórico mal anexado"
fi
if [[ ! -e "$frag" && ! -e "$repo/docs/fases-ativas/F-900.md" ]] && grep -qx 'docs/changes/F-900.md' "${TMP}/tocados"; then
  teste_ok "consolidação apaga fragmento e registro e lista os caminhos"
else
  teste_falha "fragmento ou registro sobreviveram à consolidação"
fi

# --- integração serial, com o fecho comum e o gh falso ---

estado_gh() { # um GitHub falso novo: nenhum PR, checks verdes, a issue aberta
  export GH_ESTADO="${TMP}/gh-$1"
  mkdir -p "$GH_ESTADO"
  echo 0 > "$GH_ESTADO/checks_rc"; echo abc > "$GH_ESTADO/head"; echo OPEN > "$GH_ESTADO/issue_state"
  : > "$GH_ESTADO/log"
}
abrir() { # <clone> <id> <slug> <arquivos>
  local out
  out="$(cd "$1" && bash "${AQUI}/abrir-fase.sh" --id "$2" --slug "$3" --spec "${TMP}/spec.md" --arquivos "$4" --destino "${TMP}/wt-$(basename "$1")-$2" 2>"${TMP}/abrir.err")"
  printf '%s\n' "$out" | sed -n 's/^worktree: //p' | tail -n 1
}
# O fecho da fase paralela: a entrega, o SETUP vazio de volta e o fragmento com a linha do changelog.
fechar_paralela() { # <wt> <id> <arquivo> <texto> [sem-changelog]
  local wt="$1" id="$2"
  mkdir -p "$(dirname "${wt}/$3")"
  printf '%s\n' "$4" > "${wt}/$3"
  git -C "$wt" show origin/main:docs/SETUP.md > "${wt}/docs/SETUP.md"
  if [[ "${5:-}" != sem-changelog ]]; then
    integracao_anexar_na_secao "${wt}/docs/changes/${id}.md" changelog "**${id}** — ${id} entrou — 2026-11-15"
  fi
  integracao_anexar_na_secao "${wt}/docs/changes/${id}.md" roadmap-remove "$id"
  git -C "$wt" add -- "$3" docs/SETUP.md "docs/changes/${id}.md"
  git -C "$wt" commit -q -m "feat: entrega ${id}"
}
integrar() { # <wt> <id> [args…] — o rc em $rc, a saída em $TMP/int.out e .err
  local wt="$1" id="$2"
  shift 2
  set +e
  (cd "$wt" && env -u INTEGRACAO_VERSAO_MAIN INTEGRACAO_VALIDAR="${VALIDAR:-true}" bash "${AQUI}/integrar-fase.sh" --id "$id" "$@") >"${TMP}/int.out" 2>"${TMP}/int.err"
  rc=$?
  set -e
}
# Uma solitária ainda em curso no checkout principal (branch `fase/*` sem registro) é pendência do
# conferir-fecho que a integração roda no fim (Amplug F-110): integrada, sai 1. Aceita esse 1 como 0.
solitaria_em_curso() { # <branch da solitária> — rc em $rc
  if [[ $rc -eq 1 ]] && grep -qF "pendente: git branch tem mais que o main: $1" "${TMP}/int.err"; then
    rc=0
  fi
}
trava() { # a mensagem da trava no remoto, ou vazio
  git -C "$1" fetch -q origin refs/integracao/lock:refs/integracao/lock-vista 2>/dev/null || return 0
  git -C "$1" log -1 --format=%s refs/integracao/lock-vista
  git -C "$1" update-ref -d refs/integracao/lock-vista
}
sumiu() { # <clone> <wt> <branch> — 0 se o worktree, o branch local e o remoto da fase sumiram
  [[ ! -d "$2" ]] && ! git -C "$1" worktree list --porcelain | grep -qxF "worktree $2" \
    && ! git -C "$1" show-ref --verify -q "refs/heads/$3" && [[ -z "$(git -C "$1" ls-remote --heads origin "refs/heads/$3")" ]]
}
printf '%s\n' '# SETUP — fase atual' '' '# F-0xx — a spec' > "${TMP}/spec.md"

# Duas paralelas acrescentam parágrafo no CHANGELOG pelo fragmento: entram as duas, uma depois da outra.
bare="${TMP}/um.git" clone="${TMP}/um"
teste_bare "$bare" "$clone"
estado_gh um
wt10="$(abrir "$clone" F-010 alfa 'src/alfa/')"
wt11="$(abrir "$clone" F-011 beta 'src/beta/')"
fechar_paralela "$wt10" F-010 src/alfa/nota.txt alfa
fechar_paralela "$wt11" F-011 src/beta/nota.txt beta
integrar "$wt10" F-010 --issue 9
if [[ $rc -eq 0 ]] && grep -qxF '**F-010** — F-010 entrou — 2026-11-15' "$clone/docs/CHANGELOG.md" \
  && ! grep -qF '**F-010**' "$clone/docs/ROADMAP.md" && [[ -f "$clone/src/alfa/nota.txt" && ! -e "$clone/docs/fases-ativas/F-010.md" ]]; then
  teste_ok "a primeira paralela integra pelo fecho comum: changelog, roadmap, código, sem registro no main"
else
  teste_falha "a primeira paralela não integrou (rc ${rc})"
  cat "${TMP}/int.err" >&2
fi
if grep -q 'gh pr merge 7 --rebase --delete-branch' "$GH_ESTADO/log" && grep -q 'gh issue close 9' "$GH_ESTADO/log"; then
  teste_ok "o merge foi do fechar-pr.sh, com a issue fechada"
else
  teste_falha "o merge não passou pelo fechar-pr.sh"
fi
if sumiu "$clone" "$wt10" fase/F-010-alfa && [[ "$(git -C "$clone" rev-parse main)" == "$(git -C "$clone" rev-parse origin/main)" ]]; then
  teste_ok "depois do 0, o worktree e o branch da fase sumiram e o main local está em dia"
else
  teste_falha "sobrou worktree ou branch da F-010, ou o main local ficou atrás"
fi
# O conferir-fecho roda dentro da integração, do checkout principal (Amplug F-110).
saida="$(cd "$clone" && bash "${AQUI}/conferir-fecho.sh" 7 --issue 9 || true)"
if [[ "$saida" == ok ]] && grep -qxF 'integrada: F-010 (PR #7); conferir-fecho: ok' "${TMP}/int.out"; then
  teste_ok "conferir-fecho dá ok com a outra paralela (com registro) ainda aberta, e a integração já o rodou"
else
  teste_falha "conferir-fecho depois da F-010: ${saida}"
fi
integrar "$wt11" F-011
c="$clone/docs/CHANGELOG.md"
if [[ $rc -eq 0 ]] && grep -qF 'F-010 entrou' "$c" && grep -qF 'F-011 entrou' "$c" && vizinhas_brancas "$c" '**F-010**' \
  && vizinhas_brancas "$c" '**F-011**' && [[ -f "$clone/src/alfa/nota.txt" && -f "$clone/src/beta/nota.txt" ]] \
  && sumiu "$clone" "$wt11" fase/F-011-beta; then
  teste_ok "a segunda paralela integra: os dois parágrafos, uma branca entre eles"
else
  teste_falha "a segunda paralela não integrou (rc ${rc})"
  cat "${TMP}/int.err" >&2
fi
if [[ "$(git -C "$clone" rev-list --merges main | wc -l | tr -d ' ')" == 0 && -z "$(trava "$clone")" ]]; then
  teste_ok "main linear, sem merge commit, e a trava solta"
else
  teste_falha "merge commit no main ou trava presa"
fi

# Duas solitárias editam o CHANGELOG direto: o conflito trivial se resolve no rebase.
bare="${TMP}/dois.git" clone="${TMP}/dois"
teste_bare "$bare" "$clone"
estado_gh dois
wt15="${TMP}/wt-F-015"
git -C "$clone" worktree add -q -b fase/F-015-x "$wt15" main
_integracao_acrescentar_se_falta "$wt15/docs/CHANGELOG.md" '**F-015** — x — 2026-11-15'
git -C "$wt15" add -- docs/CHANGELOG.md
git -C "$wt15" commit -q -m "feat: F-015"
git -C "$clone" switch -q -c fase/F-016-y
_integracao_acrescentar_se_falta "$clone/docs/CHANGELOG.md" '**F-016** — y — 2026-11-15'
git -C "$clone" add -- docs/CHANGELOG.md
git -C "$clone" commit -q -m "feat: F-016"
integrar "$wt15" F-015
solitaria_em_curso fase/F-016-y
rc15=$rc
integrar "$clone" F-016
c="$clone/docs/CHANGELOG.md"
if [[ $rc15 -eq 0 && $rc -eq 0 ]] && vizinhas_brancas "$c" '**F-015**' && vizinhas_brancas "$c" '**F-016**' \
  && [[ "$(tail -n 1 "$c")" == '**F-016**'* && "$(git -C "$clone" branch --show-current)" == main ]] \
  && sumiu "$clone" "$wt15" fase/F-015-x && ! git -C "$clone" show-ref -q --verify refs/heads/fase/F-016-y; then
  teste_ok "duas solitárias no CHANGELOG: o conflito trivial junta os parágrafos e o checkout principal volta ao main"
else
  teste_falha "as solitárias não integraram (rc ${rc15} e ${rc})"
  cat "${TMP}/int.err" >&2
fi

# Conflito de lógica para; trava ocupada recusa; validação que falha e fragmento sem changelog não integram.
bare="${TMP}/tres.git" clone="${TMP}/tres"
teste_bare "$bare" "$clone"
estado_gh tres
wt10="$(abrir "$clone" F-010 alfa 'src/alfa/')"
wt11="$(abrir "$clone" F-011 beta 'src/beta/')"
wt12="$(abrir "$clone" F-012 gama 'src/gama/')"
wt13="$(abrir "$clone" F-013 delta 'src/delta/')"
fechar_paralela "$wt10" F-010 src/compartilhado.txt versao-alfa
fechar_paralela "$wt11" F-011 src/compartilhado.txt versao-beta
fechar_paralela "$wt12" F-012 src/gama/nota.txt gama
fechar_paralela "$wt13" F-013 src/delta/nota.txt delta sem-changelog
integrar "$wt10" F-010
antes="$(git -C "$bare" rev-parse main)"
integrar "$wt11" F-011
if [[ $rc -eq 4 ]] && grep -q 'conflito de lógica: src/compartilhado.txt' "${TMP}/int.err" \
  && [[ "$(git -C "$bare" rev-parse main)" == "$antes" && "$(git -C "$bare" show main:src/compartilhado.txt)" == versao-alfa \
  && "$(trava "$clone")" == 'lock F-011' ]]; then
  teste_ok "conflito fora dos ledgers sai 4, main intacto, trava com a fase parada"
else
  teste_falha "conflito de lógica: rc ${rc}"
  cat "${TMP}/int.err" >&2
fi
integrar "$wt12" F-012
if [[ $rc -eq 3 ]] && grep -q 'trava ocupada' "${TMP}/int.err" && [[ "$(git -C "$bare" rev-parse main)" == "$antes" ]]; then
  teste_ok "segunda fase com a trava ocupada sai 3"
else
  teste_falha "trava ocupada: rc ${rc}"
fi
integrar "$wt11" F-011 --abortar
if [[ $rc -eq 0 && -z "$(trava "$clone")" ]] && ! git -C "$wt11" status | grep -q rebase; then
  teste_ok "abortar desfaz o rebase e solta a trava"
else
  teste_falha "abortar: rc ${rc}"
fi
: > "$GH_ESTADO/log"
VALIDAR='exit 1' integrar "$wt12" F-012
if [[ $rc -eq 5 && "$(git -C "$bare" rev-parse main)" == "$antes" ]] && ! grep -q 'gh pr' "$GH_ESTADO/log"; then
  teste_ok "validação que falha sai 5 sem merge"
else
  teste_falha "validação: rc ${rc}"
fi
integrar "$wt12" F-012 --abortar
integrar "$wt13" F-013
if [[ $rc -eq 6 && "$(git -C "$bare" rev-parse main)" == "$antes" && "$(trava "$clone")" == 'lock F-013' ]]; then
  teste_ok "fragmento sem changelog sai 6 e segura a trava"
else
  teste_falha "fragmento sem changelog: rc ${rc}"
fi
integrar "$wt13" F-013 --abortar
# O fecho comum vermelho: sai 5, sem merge, a trava presa.
: > "$GH_ESTADO/log"; echo 1 > "$GH_ESTADO/checks_rc"
integrar "$wt12" F-012
if [[ $rc -eq 5 && "$(git -C "$bare" rev-parse main)" == "$antes" && "$(trava "$clone")" == 'lock F-012' ]] \
  && ! grep -q 'gh pr merge' "$GH_ESTADO/log" && [[ -d "$wt12" ]]; then
  teste_ok "checks vermelhos no fechar-pr.sh saem 5, sem merge, trava e worktree ficam"
else
  teste_falha "fechar-pr vermelho: rc ${rc}"
  cat "${TMP}/int.err" >&2
fi

# O fecho comum falha depois do merge (o checkout principal com mudança sem commit no CHANGELOG, como o
# plan mode deixa): a fase entrou, então a trava solta e a limpeza corre; sai 1 com a pendência do main.
bare="${TMP}/quatro.git" clone="${TMP}/quatro"
teste_bare "$bare" "$clone"
estado_gh quatro
wt10="$(abrir "$clone" F-010 alfa 'src/alfa/')"
fechar_paralela "$wt10" F-010 src/alfa/nota.txt alfa
echo 'linha do plan mode, sem commit' >> "$clone/docs/CHANGELOG.md"
integrar "$wt10" F-010
if [[ $rc -eq 1 && "$(cat "$GH_ESTADO/pr_state")" == MERGED && -z "$(trava "$clone")" ]] && sumiu "$clone" "$wt10" fase/F-010-alfa \
  && grep -q 'falhou depois do merge' "${TMP}/int.err"; then
  teste_ok "fecho comum que falha depois do merge: sai 1, trava solta, worktree e branch fora"
else
  teste_falha "fecho comum depois do merge: rc ${rc}, trava '$(trava "$clone")'"
  cat "${TMP}/int.err" >&2
fi

# O gh tira o worktree da fase no `pr merge --delete-branch` (o fecho da Amplug F-101 e da Amplug F-099): a integração
# segue do checkout principal, solta a trava e limpa (Amplug F-104). O script antigo caía com a pasta apagada.
bare="${TMP}/cinco.git" clone="${TMP}/cinco"
teste_bare "$bare" "$clone"
estado_gh cinco
wt20="$(abrir "$clone" F-020 eta 'src/eta/')"
fechar_paralela "$wt20" F-020 src/eta/nota.txt eta
echo "$wt20" > "$GH_ESTADO/tira_worktree"
integrar "$wt20" F-020
if [[ $rc -eq 0 && "$(cat "$GH_ESTADO/pr_state")" == MERGED && -z "$(trava "$clone")" ]] && sumiu "$clone" "$wt20" fase/F-020-eta; then
  teste_ok "worktree tirado pelo gh no merge: trava solta, branch fora, sai 0"
else
  teste_falha "worktree tirado no merge: rc ${rc}, trava '$(trava "$clone")'"
  cat "${TMP}/int.err" >&2
fi

# O --abortar do checkout principal (sem branch da fase): solta a trava da própria fase, recusa a alheia.
wt21="$(abrir "$clone" F-021 teta 'src/teta/')"
fechar_paralela "$wt21" F-021 src/teta/nota.txt teta
VALIDAR='exit 1' integrar "$wt21" F-021
set +e
(cd "$clone" && bash "${AQUI}/integrar-fase.sh" --id F-022 --abortar) >"${TMP}/int.out" 2>"${TMP}/int.err"; rc_alheia=$?
(cd "$clone" && bash "${AQUI}/integrar-fase.sh" --id F-021 --abortar) >"${TMP}/int.out" 2>"${TMP}/int.err"; rc=$?
set -e
if [[ $rc_alheia -ne 0 && $rc -eq 0 && -z "$(trava "$clone")" ]]; then
  teste_ok "abortar no main solta só a trava da própria fase"
else
  teste_falha "abortar no main: alheia rc ${rc_alheia}, própria rc ${rc}, trava '$(trava "$clone")'"
  cat "${TMP}/int.err" >&2
fi

# O atritos.md é ledger (Amplug F-104): duas solitárias acrescentam linha na tabela; o rebase da segunda junta
# as duas (sai 0), em vez de parar como conflito de lógica (sai 4).
bare="${TMP}/seis.git" clone="${TMP}/seis"
teste_bare "$bare" "$clone"
estado_gh seis
mkdir -p "$clone/docs/reference"
printf '%s\n' '# Atritos' '' '| Atrito | Fases | Destino |' '|---|---|---|' '| um atrito antigo | F-001 | nada |' > "$clone/docs/reference/atritos.md"
git -C "$clone" add -- docs/reference/atritos.md
git -C "$clone" commit -q -m "docs: atritos"
git -C "$clone" push -q origin main
wt23="${TMP}/wt-F-023"
git -C "$clone" worktree add -q -b fase/F-023-x "$wt23" main
echo '| atrito da F-023 | F-023 | nada |' >> "$wt23/docs/reference/atritos.md"
git -C "$wt23" commit -q -am "docs: atrito da F-023"
git -C "$clone" switch -q -c fase/F-024-y
echo '| atrito da F-024 | F-024 | nada |' >> "$clone/docs/reference/atritos.md"
git -C "$clone" commit -q -am "docs: atrito da F-024"
integrar "$wt23" F-023
solitaria_em_curso fase/F-024-y
rc23=$rc
integrar "$clone" F-024
a="$clone/docs/reference/atritos.md"
if [[ $rc23 -eq 0 && $rc -eq 0 ]] && grep -qF 'atrito da F-023' "$a" && grep -qF 'atrito da F-024' "$a" \
  && grep -qF 'um atrito antigo' "$a"; then
  teste_ok "atritos.md com linha nova das duas fases: conflito trivial, entram as duas"
else
  teste_falha "atritos.md: rc ${rc23} e ${rc}"
  cat "${TMP}/int.err" >&2
fi

# A branch da fase com o script antigo integra pela versão do main (Amplug F-106): o rebase não troca o
# código que o processo já roda, e foi assim que a trava da Amplug F-105 ficou presa.
bare="${TMP}/sete.git" clone="${TMP}/sete"
teste_bare "$bare" "$clone"
estado_gh sete
mkdir -p "$clone/scripts/lib"
sed 's|^set -euo pipefail$|set -euo pipefail\necho "MARCA-DO-MAIN-F106" >\&2|' "${AQUI}/integrar-fase.sh" > "$clone/scripts/integrar-fase.sh"
for f in lib/integracao.sh fechar-pr.sh fases-ativas.sh abrir-fase.sh conferir-fecho.sh; do cp "${AQUI}/$f" "$clone/scripts/$f"; done
git -C "$clone" add -- scripts
git -C "$clone" commit -q -m "chore: os scripts no main"
git -C "$clone" push -q origin main
wt25="$(abrir "$clone" F-025 iota 'src/iota/')"
fechar_paralela "$wt25" F-025 src/iota/nota.txt iota
# A validação falha se a marca do desvio vazar pra ela (o validar.sh roda este teste, que desvia de novo).
# shellcheck disable=SC2016 # o $ é da validação, não daqui
VALIDAR='[ -z "${INTEGRACAO_VERSAO_MAIN:-}" ]' integrar "$wt25" F-025
if [[ $rc -eq 0 && -z "$(trava "$clone")" ]] && grep -q 'rodo a versão do main' "${TMP}/int.err" \
  && grep -q 'MARCA-DO-MAIN-F106' "${TMP}/int.err" && sumiu "$clone" "$wt25" fase/F-025-iota; then
  teste_ok "a fase com o script antigo integra pela versão do main e solta a trava"
else
  teste_falha "versão do main: rc ${rc}, trava '$(trava "$clone")'"
  cat "${TMP}/int.err" >&2
fi

# Pendência no conferir-fecho depois do merge (Amplug F-110): a integração sai 1, já integrada e com a trava solta.
# Aqui, um branch que sobrou no checkout principal.
bare="${TMP}/oito.git" clone="${TMP}/oito"
teste_bare "$bare" "$clone"
estado_gh oito
git -C "$clone" branch sobra
wt26="$(abrir "$clone" F-026 kapa 'src/kapa/')"
fechar_paralela "$wt26" F-026 src/kapa/nota.txt kapa
integrar "$wt26" F-026
if [[ $rc -eq 1 && "$(cat "$GH_ESTADO/pr_state")" == MERGED && -z "$(trava "$clone")" ]] \
  && grep -qF 'pendente: git branch tem mais que o main: sobra' "${TMP}/int.err" && grep -qF 'conferir-fecho.sh acusou' "${TMP}/int.err"; then
  teste_ok "pendência do conferir-fecho depois do merge sai 1, com a trava solta"
else
  teste_falha "pendência do conferir-fecho: rc ${rc}, trava '$(trava "$clone")'"
  cat "${TMP}/int.err" >&2
fi

if [[ "$teste_falhou" -ne 0 || "$falhou" -ne 0 ]]; then
  echo "integrar-fase.test.sh falhou" >&2
  exit 1
fi
echo ok
