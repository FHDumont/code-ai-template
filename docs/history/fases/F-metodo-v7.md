# F-metodo-v7 — o disparador da trilha e a espera da resposta no shell

## Objetivo

Fechar em código o que falta do contrato v1 do canal e da trilha fora do ciclo (ADR-003): um disparador genérico que roda a skill da trilha em `claude -p`, e a espera da resposta em shell, sem turno de modelo. Sem skill de trilha pronta (ADR-003) e sem mudar o contrato v1.

## Escopo

**Entra:**

- `scripts/canal-esperar.sh <unidade>/<bot>/respostas/<nome>.md`: loop de `sleep` (`CANAL_ESPERA_INTERVALO`, 120 s; `CANAL_ESPERA_TETO`, 4 h). A resposta só vale estável (duas leituras iguais) e com `status:` na primeira linha, sem `.tmp`. Sai 0 com o status impresso; 1 no teto.
- `scripts/disparar-trilha.sh <issue>`: roda `claude -p` da skill da trilha, lê `estado.json`, em `esperando` chama o `canal-esperar.sh` e redispara (teto de 8 voltas; bloqueio tenta uma vez de novo), confere com `scripts/conferir-fecho.sh` e manda um aviso por disparo pelo `canal-avisar.sh`: `fim` (ok|pendente, com as pendências) ou `falha` (motivo).
- **Model/effort nunca vêm do padrão da conta.** O disparador exige `--modelo` e `--effort` (ou `TRILHA_MODELO`, `TRILHA_EFFORT`), sem valor de fábrica e sem `--fallback-model`. Falta um dos dois: `falha` e saída 2, sem rodar. Grava os dois na 1ª linha do log e confere o `init` do stream: modelo diferente do informado para com `falha`.
- `docs/reference/canal.md` ganha `§Trilha`: o `estado.json` (`esperando|pronto|falha`) na pasta da unidade `issue-<n>`, os tetos e as variáveis. O contrato v1 não muda.
- `AGENTS.md` §Trilha fora do ciclo aponta o disparador; `README.md` o lista; `.claude/settings.json` ganha as duas linhas `Bash(scripts/…:*)` (**passo do dono**, o agente não edita a própria permissão).

**NÃO entra:**

- Skill de trilha, `trilha.sh`, runbook ou conteúdo (do projeto, ADR-003); extensão de status do Amplug (`parcial`, `clipes-prontos`, `bloqueado`).
- Mexer em `canal-avisar.sh`, `fechar-pr.sh`, `conferir-fecho.sh` ou no loop de fases.
- Linha de ROADMAP nova: a v7 sai do ROADMAP ao fechar.

## Modo

Solitária (R-001): um item, nenhuma fase ativa, nada cruza.

## Bots

- (nenhum)

## Passos

1. `canal-esperar.sh` + `canal-esperar.test.sh` (`claude`/tempo falsos, `scripts/test-lib.sh`): estável, `.tmp` ignorado, sem `status:` ignorado, teto.
2. `disparar-trilha.sh` + `.test.sh` com `claude`, `gh` e `canal-avisar` falsos (`scripts/fecho-gh-falso.sh`): sem model/effort não roda, modelo trocado vira `falha`, `esperando`→espera→`pronto`, teto de voltas, `fim pendente` quando o conferir falha.
3. Os dois testes entram em `scripts/validar.sh` (`validar.test.sh` reprova `.test.sh` fora da lista); `shellcheck` limpo, bash 3.2.
4. `canal.md` §Trilha, `AGENTS.md`, `README.md`; CHANGELOG, ROADMAP, SETUP→histórico no fecho.

## Etapas

1. **Espera** · commit: `feat: canal-esperar espera a resposta em shell`
2. **Disparador** · commit: `feat: disparar-trilha roda a trilha com model/effort informado`
3. **Docs e validar** · commit: `docs: trilha e espera no canal e no AGENTS`

## Critério de pronto

- `bash scripts/validar.sh` verde; cada teste novo falha sem o script (prova: rodar contra stub vazio).
- `disparar-trilha.sh` sem `--modelo`/`--effort` e sem as variáveis sai 2 e não chama o `claude` falso.
- Nenhum default de modelo no script: `grep -nE 'claude-(opus|sonnet|haiku|fable)' scripts/disparar-trilha.sh` vazio.
- Docs vivos atualizados; linha da v7 fora do ROADMAP.

## Decisões em aberto

- (nenhuma). Suposição declarada: model/effort por flag **ou** variável (a pergunta foi "nunca rodar sem o criador informar"); `claude -p` usa `--output-format stream-json` pro `init`.

## Notas de implementação

- **Model/effort nunca de fábrica** (decisão do dono na rodada do grilling): skill, modelo e effort são obrigatórios (flag ou `TRILHA_*`); faltando, sai 2 e avisa `falha`. O `init` do stream tem de trazer o id inteiro informado; alias (`opus`) não casa e vira `falha`.
- **O `claude` real não foi rodado:** os testes usam `claude` falso. Falta um disparo manual com modelo barato antes da primeira trilha pra confirmar que o primeiro evento `init` do stream-json traz `.model` igual ao `--model`.
- **Estável** só é testado com `CANAL_ESPERA_ESTAVEL=0`; nenhum teste reescreve o arquivo entre as duas leituras.
- **Revisão de fecho: bate, sem defeito.** Nota aplicada: o `conferir-fecho.sh` é lido sem o stderr, pra o aviso `deploy segurado sem leva` não virar pendência no `fim`.
- **Passo do dono:** as linhas `Bash(scripts/canal-esperar.sh:*)` e `Bash(scripts/disparar-trilha.sh:*)` no `.claude/settings.json` (o agente não edita a própria permissão).
- **Lição de processo:** o `shellcheck` do `validar.sh` só olha arquivo versionado (`git ls-files`); script novo precisa de `git add` antes pra ser checado.
