# SETUP — fase atual

> **Exatamente uma** spec por vez, a fase em andamento. **Plan mode escreve aqui** (auditada contra o código, sem commitar — o commit é da execução); code mode lê em sessão nova pós-`/clear` e executa. Vazio (ou 1 linha de ponteiro) quando não há fase aberta.
> Quando a fase fecha, a spec vai inteira pra `docs/history/fases/<ID>.md` (+ uma linha no índice `docs/history/SETUP-HISTORICO.md`) e este arquivo fica vazio até o próximo plan mode.
> Formato em `templates/spec-fase.md`. Exemplo preenchido em `examples/docs/SETUP.md`.

---

# F-metodo-v8 — melhorias genéricas de método vindas do Amplug

## Objetivo

Trazer para o template o método que o Amplug evoluiu depois de `2faa6c2` (itens 1–11 da #16), sem nada do produto. Pré-requisito de FHDumont/amplug#357. Absorve #12, #13, #14 e #15.

## Escopo

**Entra:** os 11 itens da #16, portados de `amplug@764c2a6d` e generalizados (sem nome de host, workflow, pacote ou trilha de vídeo do Amplug).

**NÃO entra:** `lab.sh`, `test-db.sh`, `prod.sh`, `clone-prod.sh`, `duas-suites.sh`, `avisos-ios.sh`, `gerar-marca.py`, `acompanhar-video.sh`; hooks `lint-arquivo` e `journal-em-ordem`; skills `nova-migration` e `produzir-video`; `auditor-migration`; docs de referência do produto; a extensão "trilha de vídeo" do canal; hook que valide a placa de estado (segue candidato, #15); qualquer mudança no `amplug` ou no `dumontech-videos`.

## Passos

1. Branch `fase/F-metodo-v8`; cada `.test.sh` novo ou alterado fica vermelho antes do código e verde depois.
2. Portar pela diferença arquivo a arquivo (template → Amplug), revisando cada trecho: genérico entra, do produto sai ou vira parâmetro.
3. `validar.sh` do template passa a rodar todos os `.test.sh` (hooks e `scripts/`) e o `shellcheck`.
4. Cada item ganha ponteiro de origem ("portado do Amplug F-xxx") em `docs/reference/referencias.md`.

## Etapas

1. **Fases paralelas robustas** (itens 4 e 5): `scripts/lib/integracao.sh`, `integrar-fase.sh`, `fases-ativas.sh`, `abrir-fase.sh`, `enfileirar.sh`, `test-lib.sh` e os `.test.sh` — bash 3.2 (sem `declare -A`, `mapfile`, `readarray`), trava solta na falha pós-merge, versão do `main`, sessão no checkout principal, prompt com placa e fecho liberado, teste ponta a ponta do conflito de ledger.
2. **Hooks endurecidos** (item 8): `block-dangerous-git.sh` e `block-comandos-do-dono.sh` com os casos novos nos `.test.sh`; os comandos de dono do Amplug (`lab.sh`, `seed --force`) ficam como exemplo parametrizável.
3. **Fecho comum** (item 9): `scripts/fechar-pr.sh`, `conferir-fecho.sh`, `fecho-gh-falso.sh`, `fecho-teste-comum.sh`, os `.test.sh` e `validar.test.sh`; sem `AMPLUG_VIDEOS_WT` (vira variável genérica opcional de worktree de trilha); `integrar-fase.sh` passa a fechar por ele.
4. **Canal v1** (item 3): `scripts/canal-avisar.sh` e o `.test.sh`; `docs/reference/canal.md` e `templates/canal/*` com handoff, marcas VERIFIED/INFERRED/UNKNOWN, `proibido:`, `teto_diario` e aviso idempotente.
5. **Um restart por leva, opcional** (item 7): `scripts/deploy-segurado.sh` e o `.test.sh`, com workflow e alvo por variável; documentado como add-on em `integracao.md`.
6. **Texto do método** (itens 1, 2, 6, 7, 10, 11): `AGENTS.md` (§Observador de atrito, §Placa de estado, fase de produção só com ok do dono, trilha fora do ciclo como padrão opcional), `CLAUDE.md`, `.cursor/rules/metodo.mdc`, as cinco skills, `revisor-fecho.md`, `settings.json`, `templates/` (`spec-fase`, `fragmento-fase`, `fase-ativa` com `pronta-para-integrar`), `.github/ISSUE_TEMPLATE/trabalho.md`, `docs/reference/integracao.md` e `docs/reference/atritos.md` vazio.
7. **Docs do fecho:** ADR novo (fecho comum por script e trilha fora do ciclo, generalizando ADR-055/056 do Amplug), `referencias.md`, `docs/history/fases/F-metodo-v8.md`, `CHANGELOG`, `DECISOES`, `SETUP-HISTORICO`.

## Critério de pronto

- `bash scripts/validar.sh` verde local e no CI do PR, com `shellcheck`.
- `grep -n 'mapfile\|readarray\|declare -A' scripts/*.sh scripts/lib/*.sh` vazio; testes verdes no `/bin/bash` 3.2 do macOS.
- `grep -rn -i 'amplug\|ocpp\|atlas\|efesto' AGENTS.md CLAUDE.md .claude .cursor scripts templates docs/reference` só acha ponteiros de origem.
- Itens 1–11 presentes, cada um com ponteiro em `referencias.md`; histórico, CHANGELOG e DECISOES atualizados.
- Revisão de fecho de contexto fresco (`revisor-fecho`) sem pendência.
- PR aberto e **parado** até o ok do dono; depois do merge, #12–#15 fechadas com ponteiro e o SHA comentado na amplug#357.

Model/effort de execução: modelo forte (Fable 5.2) · high
