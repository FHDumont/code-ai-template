# shellcheck shell=bash disable=SC2034 # `teste_falhou` é lido por quem faz o source
# Apoio dos testes dos scripts de fase. Não faz parte do fluxo do agente.
# Os ledgers do repositório descartável usam o formato de parágrafo (`**F-xxx** — …` separados por linha em
# branco no CHANGELOG, ROADMAP e débito), o mais exigente dos dois que a lib aceita; lista no SETUP-HISTORICO
# e tabela por seção no DECISOES. O formato de lista (`- **F-xxx** — …`) tem caso próprio no `integrar-fase.test.sh`.

# Quem faz o source define `TMP` (o diretório descartável do teste, apagado no trap dele).
teste_falhou=0

teste_ok() {
  echo "ok: $1"
}

teste_falha() {
  echo "FALHOU: $*" >&2
  teste_falhou=1
}

teste_rc() {
  local desc="$1" esperado="$2" rc
  shift 2
  set +e
  "$@" >"${TMP:?}/teste-out" 2>"${TMP:?}/teste-err"
  rc=$?
  set -e
  if [[ "$rc" != "$esperado" ]]; then
    teste_falha "${desc} — esperado exit ${esperado}, veio ${rc}"
    echo "--- stdout ---" >&2
    cat "${TMP:?}/teste-out" >&2 || true
    echo "--- stderr ---" >&2
    cat "${TMP:?}/teste-err" >&2 || true
    return 0
  fi
  teste_ok "$desc"
}

teste_repo_init() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.email "teste@example.com"
  git -C "$dir" config user.name "Teste"
  mkdir -p "$dir/docs/history" "$dir/docs/fases-ativas" "$dir/docs/changes" "$dir/src"
  cat > "$dir/docs/CHANGELOG.md" <<'EOF'
# CHANGELOG

> Ledger.


**F-001** — base — 2026-01-01
EOF
  cat > "$dir/docs/ROADMAP.md" <<'EOF'
# ROADMAP

## Atual

(nenhuma fase aberta)

## Próximas

**F-010** — alfa

**F-011** — beta

**F-020** — gama — depende de F-099
EOF
  cat > "$dir/docs/DECISOES.md" <<'EOF'
# DECISÕES

## Método

| ADR | Título | Status |
| --- | ------ | ------ |
| ADR-001 | Canal | accepted |

## Plataforma

| ADR | Título | Status |
| --- | ------ | ------ |
EOF
  printf '%s\n' '# DÉBITO TÉCNICO' '' '**D-001** — um débito — 🔵 baixo' > "$dir/docs/DEBITO-TECNICO.md"
  printf '%s\n' '# DÉBITO RESOLVIDO' > "$dir/docs/history/DEBITO-RESOLVIDO.md"
  printf '%s\n' '# SETUP — histórico' '' '- F-001 — base' > "$dir/docs/history/SETUP-HISTORICO.md"
  printf '%s\n' '# SETUP — fase atual' '' '> Vazio quando não há fase aberta.' > "$dir/docs/SETUP.md"
  echo "leia" > "$dir/docs/fases-ativas/LEIA.md"
  echo "leia" > "$dir/docs/changes/LEIA.md"
  echo "readme" > "$dir/README.md"
  git -C "$dir" add -- README.md docs
  git -C "$dir" commit -q -m "chore: base"
}

teste_bare() {
  local bare="$1" clone="$2"
  git init -q --bare -b main "$bare"
  teste_repo_init "$clone"
  git -C "$clone" remote add origin "$bare"
  git -C "$clone" push -q -u origin main 2>/dev/null
}
