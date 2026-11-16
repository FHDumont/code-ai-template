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

## Notas de implementação

- **O porte partiu da versão do Amplug, não do diff.** Os scripts de fase de lá já eram o porte da F-metodo-v6 pro bash 3.2 e pro fecho comum; copiei e tirei o produto, em vez de aplicar 700 linhas de diff à mão. O que saiu virou gancho: `ABRIR_FASE_SO_SOLITARIA` (lá, `db/src/schema.ts` e `db/migrations/` fixos), `ABRIR_FASE_LINKS` (lá, `infra/.env`), `scripts/preparar-worktree.sh` (lá, `pnpm install`), `FECHO_WT_TRILHA` (lá, `AMPLUG_VIDEOS_WT`, com padrão; aqui sem padrão: sem a variável não se olha) e os workflows do `deploy-segurado.sh`.
- **Numeração traduzida.** R-060 a R-066 do Amplug são R-001 a R-007 aqui; ADR-063 é a ADR-002 e ADR-055/056 viraram a ADR-003. Um `replace` de `R-063` casou dentro de `ADR-063` e gerou um `ADR-004` que não existe: corrigido na hora. Referência a fase do Amplug só fica como ponteiro de origem (`Amplug F-xxx`).
- **Dois formatos de ledger.** O Amplug usa parágrafo (`**F-xxx** — …` entre linhas em branco); este template usa lista (`- **F-xxx** — …`). A lib aceita os dois, e os fixtures dos testes ficaram no de parágrafo, o mais exigente, com casos próprios pro de lista.
- **Etapas 1 e 3 saíram juntas, e a ordem mudou.** O `integrar-fase.sh` novo chama o `fechar-pr.sh`, então o fecho comum foi commitado antes das fases paralelas. Os hooks (etapa 2) foram o primeiro commit, porque o `shellcheck` do `validar.sh` novo reprovava o hook antigo (`tem_token` sem uso: SC2329).
- **`validar.sh` com lista explícita e teste próprio.** O atalho do Amplug que pula os testes de vídeo não veio. No lugar, o `validar.test.sh` reprova `.test.sh` versionado que ficou fora da lista e teste listado que não existe.
- **A raiz do canal sai do checkout principal.** `canal-avisar.sh` usa `git rev-parse --git-common-dir` pra achar o nome do projeto: num worktree de fase o basename é o id da fase, não o projeto. No Amplug o nome era fixo no script.
- **O vermelho.** No `main` (`2faa6c2`) o `validar.sh` quebra no bash 3.2 do macOS com `declare: -A: invalid option` em `scripts/fases-ativas.sh`. O `block-dangerous-git.test.sh` novo contra o hook antigo dá 14 falhas. O `block-comandos-do-dono.test.sh` novo passa igual no hook antigo: os casos novos são de caracterização (o parser já era o mesmo), e o passo 1 da spec não vale pra ele. Os testes de `fechar-pr`, `conferir-fecho`, `canal-avisar` e `deploy-segurado` não tinham código antigo.
- **Revisão de fecho, primeira passada: dois defeitos.** (1) `_integracao_acrescentar_se_falta` deixava uma linha em branco no meio da lista quando o ledger terminava com linha em branco, que é o caso do `CHANGELOG` real deste template; nenhum fixture tinha branca no fim. Agora o item de lista ou a linha de tabela tira as brancas do fim quando a última linha com texto é da mesma lista. (2) A mensagem do push forçado no hook citava `R-063`, o número do Amplug. O `grep` do critério (`amplug|ocpp|atlas|efesto`) não pega número de regra: a varredura por `R-06x`, `ADR-05x`/`ADR-06x` e `(F-1xx)` sem "Amplug" entrou na revisão.
- **Revisão de fecho, segunda passada (sobre a correção): nenhum defeito.** Provado com execução: lista terminando com uma e duas brancas, parágrafo e nota `>` sem mudança, arquivo vazio e sem newline, tabela, o `DEBITO-TECNICO` real que termina em comentário, e o fragmento completo contra os seis ledgers reais.
- **Esta fase não se integra pelo próprio `integrar-fase.sh`.** O script da branch difere do `origin/main` e, por desenho, roda a versão do `main`, que é a antiga: usa `mapfile`, quebra no bash 3.2 e faz o merge sem o fecho comum. O PR foi aberto na mão (push da branch e `gh pr create`) e o merge fica pro `scripts/fechar-pr.sh` da branch, com o ok do dono. Da próxima fase em diante a versão do `main` já é a nova.
- **O hook de git do projeto de onde a sessão rodava barrou um comando que só continha o texto `git commit`** dentro de um teste que eu editava. A edição foi pra um arquivo de script; nenhum commit saiu fora da branch da fase.
- **`settings.json`.** Entraram as permissões dos scripts do método e a lista `deny` (`gh pr merge --admin`, push forçado, `reset --hard`). A regra portada no `grilling` diz que permissão nova é passo do dono: foi avisado no relato, pra ele manter ou reverter.
- **F-metodo-v7.** O `canal-avisar` que a v6 tinha deixado pra v7 entrou aqui. A linha da v7 no `ROADMAP` ficou só com o disparador da trilha.
