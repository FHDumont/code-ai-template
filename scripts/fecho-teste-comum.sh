# shellcheck shell=bash disable=SC2034,SC2154 # `aqui` vem de quem lê; `falhou`, quem lê o devolve
# O cenário comum dos testes do fecho, lido por `fechar-pr.test.sh` e `conferir-fecho.test.sh`:
# um repositório descartável com um `origin` bare e o `gh` falso (`fecho-gh-falso.sh`).
base=$(mktemp -d)
trap 'rm -rf "$base"' EXIT
falhou=0
erro() { echo "FALHOU: $1" >&2; falhou=1; }

mkdir "$base/bin"
cp "$aqui/fecho-gh-falso.sh" "$base/bin/gh"; chmod +x "$base/bin/gh"
export PATH="$base/bin:$PATH" FECHAR_PR_ESPERA=0 FECHAR_PR_TENTATIVAS=3
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# Um cenário novo: origin bare com o main, o clone em `repo` no branch `fase/x` com um commit já
# empurrado, e o estado do gh falso com o PR aberto e verde.
cenario() {
  rm -rf "$base/c"; mkdir -p "$base/c/e"
  git init -q --bare -b main "$base/c/origin.git"
  git clone -q "$base/c/origin.git" "$base/c/repo" 2> /dev/null
  (cd "$base/c/repo" && git commit -q --allow-empty -m base && git push -q origin main \
    && git switch -q -c fase/x && git commit -q --allow-empty -m etapa && git push -q origin fase/x)
  export GH_ESTADO="$base/c/e" FECHO_WT_TRILHA="$base/c/wt-trilha"
  echo OPEN > "$GH_ESTADO/pr_state"; echo fase/x > "$GH_ESTADO/branch"; echo CLEAN > "$GH_ESTADO/merge_state"
  echo 0 > "$GH_ESTADO/checks_rc"; echo abc > "$GH_ESTADO/head"; echo OPEN > "$GH_ESTADO/issue_state"
  : > "$GH_ESTADO/log"
}
no_repo() { (cd "$base/c/repo" && "$@"); }

