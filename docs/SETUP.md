# SETUP — fase atual

> **Exatamente uma** spec por vez, a fase em andamento. **Plan mode escreve aqui** (auditada contra o código, sem commitar — o commit é da execução); code mode lê em sessão nova pós-`/clear` e executa. Vazio (ou 1 linha de ponteiro) quando não há fase aberta.
> Quando a fase fecha, a spec vai inteira pra `docs/history/fases/<ID>.md` (+ uma linha no índice `docs/history/SETUP-HISTORICO.md`) e este arquivo fica vazio até o próximo plan mode.
> Formato em `templates/spec-fase.md`. Exemplo preenchido em `examples/docs/SETUP.md`.


---

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

---

Model/effort de execução: `Sonnet 5.5 · medium`.
