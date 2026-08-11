# AGENTS.md

Instruções para o agente de código deste projeto. **Núcleo agnóstico de ferramenta** — vale em qualquer stack e qualquer agente. Use como está.

- Mecânica por ferramenta: `CLAUDE.md` (Claude Code), `.cursor/rules/metodo.mdc` (Cursor).
- Convenções de código/UI **deste** projeto: `CONVENCOES.md`. Linguagem ubíqua do domínio: `CONTEXT.md`.
- Projeto de LLM/agentes: acople o add-on opcional e referencie aqui (ex.: `PERFIL-LLM.md`). Instruções no README.

## O loop — plan e code

Uma superfície, **dois modos** — os dois são você, os dois com o repo na mão:

- **Plan mode (raciocínio):** lê os docs vivos e **audita o código real**, discute o aberto com o dono (uma pergunta por vez), e **grava a spec da fase no `docs/SETUP.md`** — e para aí.
- **Code mode (execução):** em sessão nova (contexto limpo), lê a spec do `SETUP.md`, implementa aterrado no código, roda os critérios de sucesso na mesma resposta, e atualiza os docs vivos numa única passada antes de encerrar.

Entre os dois, uma **fronteira dura**: o dono limpa o contexto e abre a execução numa sessão nova. Cada fase é tarefa independente — o contexto mora nos docs vivos, não na sessão. (Mecânica por ferramenta: `CLAUDE.md`, `.cursor/rules/metodo.mdc`.)

Como o planejador **tem o repo**, a spec nasce confirmada contra o código: nomes de arquivo e símbolo são **verificados no plan mode**, não "hipóteses a confirmar". Ainda assim a verdade é o código — se em code mode a realidade diverge da spec, implemente o que é correto e **registre a divergência** (nota na fase, ou ADR se for decisão de arquitetura).

- **Audite o estado antes de modelar.** Fase que mexe em schema, enum ou estado persistido: no plan mode, audite o código real (migrations, tipos, dados) antes de escrever a spec. Barato, e evita spec que presume estado que não existe.
- **Uma fase de cada vez.** `docs/SETUP.md` tem **uma** spec. Implemente, atualize os vivos, **pare**, resuma ao dono e peça aprovação pra próxima — uma spec por vez, na ordem do ROADMAP.
- **Fique no modo até a fase fechar.** Se, em code mode, a conversa puxa pra fora do escopo da spec atual (nova ideia, decisão de arquitetura, refatoração não pedida), **pare e pergunte ao dono**: seguir no code, dentro do escopo, ou voltar pro plan pra tratar aquilo como fase própria? É o mesmo princípio de "sem refatoração de carona", aplicado à troca de modo.
- **Revisão de fecho com contexto fresco.** Ao fechar a fase em code mode — depois de rodar os critérios, antes do commit — dispare um **subagente sem o contexto da sessão**, que recebe só os *docs vivos + o diff* e confere se o entregue bate com a intenção da spec. Limpo → passada única de docs + commit. Divergiu → corrija antes. Fase que não toca código pode pular.
- **O plano durável é a spec.** A spec no `docs/SETUP.md` é o plano canônico (o porquê arquitetural distila em ADR; a narrativa de implementação, ao fechar, no `SETUP-HISTORICO`). O arquivo de plano nativo da ferramenta (Claude Code `~/.claude/plans`, Cursor) é **rascunho efêmero — fica fora do git**.

## Stack e comandos

> Ajuste esta seção pro seu projeto.
>
> - Build: `...`
> - Test: `...`
> - Lint/format: `...`
> - Run local: `...`

Duas regras valem em qualquer stack:

- **Markdown em uma linha física por parágrafo.** Em **qualquer** `.md` (não só os vivos), cada parágrafo/bullet/célula ocupa uma linha só, por mais longa que fique — o wrap é do editor/render. Quebra de linha só **entre** parágrafos, e edição sempre à mão: hard-wrap no meio do parágrafo polui o diff, e formatador automático corrompe tabelas.
- **O ambiente é do dono.** Ele sobe e derruba o ambiente **manualmente**; precisa dele reiniciado, **peça**. Build, typecheck, lint, testes e leitura de código são livres — rodam sem o ambiente de pé e dispensam pedido.

## Princípios de execução

Cinco falhas comuns de agente de código que este projeto evita ativamente (destiladas das observações de Andrej Karpathy sobre LLMs em código — ver [`andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills)):

1. **Trabalhe por critério de sucesso, não por receita.** Agente é ótimo em iterar até bater uma meta. Antes de codar, declare os critérios de sucesso em alto nível; implemente; verifique cada um explicitamente com execução real — teste, build, run — e itere no que falhar. "Feito" só depois da verificação. Em correção de bug: escreva primeiro um teste que **reproduz** o bug e corrija até ele passar, só até aí.
2. **Gerencie a confusão.** A falha mais cara é assumir algo no lugar do dono e seguir em frente sem checar. Requisito ambíguo → **pergunte**. Pedidos que se contradizem → **aponte** antes de seguir. Trade-off real → **apresente** os dois lados com prós/contras. Discorda da abordagem → **diga**, com argumento técnico. Escopo incerto → **nomeie as suposições** (quais campos? qual tipo de dado? qual contrato de API?) antes de tocar no código.
3. **Sem refatoração de carona.** Toque só no escopo da tarefa. Código feio fora do escopo vira TODO. Comentário que você não entendeu fica (pode carregar contexto); nome de variável fora do escopo fica; código alheio se limpa a pedido, nunca de ofício.
4. **Sem over-engineering.** Resolva o problema declarado — nem mais, nem menos. Abstração nasce quando precisa, não "pro caso de um dia precisar". Código direto e legível ganha de padrão complexo. YAGNI e KISS sempre.
5. **Preserve contexto.** Antes de mudar um arquivo, leia o suficiente pra entender o que ele faz. Função ou import só sai com certeza de que ninguém usa. Em dúvida, mantenha.

## Docs vivos — o que são

Ficam em `docs/`. São a memória compartilhada entre o plan, o code, e as sessões futuras. Cada um responde a uma pergunta, no menor número de palavras:


| Doc                 | Responde                     | Forma                                 |
| ------------------- | ---------------------------- | ------------------------------------- |
| `ROADMAP.md`        | pra onde vamos               | fases futuras + a atual; 1 linha cada |
| `CHANGELOG.md`      | o que já entrou              | ledger: 1 linha por fase entregue     |
| `DECISOES.md`       | o que foi decidido e por quê | índice: 1 linha por ADR               |
| `DEBITO-TECNICO.md` | o que está aberto            | só débito ativo; **máx. 3 frases** cada |
| `SETUP.md`          | o que estamos fazendo agora  | exatamente 1 spec                     |


Detalhe pesado vive fora dos vivos: texto cheio de ADR em `docs/adr/`, specs concluídas (+ notas de implementação) em `docs/history/SETUP-HISTORICO.md`, débito fechado em `docs/history/DEBITO-RESOLVIDO.md`.

**Quente vs. frio (economia de contexto).** Plan mode pré-carrega só **SETUP + ROADMAP + `CONTEXT.md`** (e `DEBITO-TECNICO` se a fase toca área com débito conhecido). **CHANGELOG, DECISOES e o texto cheio dos ADRs são frios** — ledgers que crescem sem teto; consulte sob demanda (`grep` pelo ID).

**Linguagem ubíqua.** O `CONTEXT.md` na raiz é o glossário do domínio: um termo por conceito, definição de uma linha, sinônimos sob `Evitar`. Ele entra no pré-carregado porque a spec e o código herdam o vocabulário dele. Termo afiado numa conversa de plan mode é registrado ali na mesma passada.

## Inbox de achados — GitHub Issues

Fora dos docs vivos existe um inbox informal: **issues do GitHub com label `achado`**, template em `.github/ISSUE_TEMPLATE/achado.md`. É onde o dono registra, a qualquer momento e sem fricção, um problema isolado ou um conjunto de problemas/melhorias que encontrou usando o app — sem precisar abrir editor nem achar onde anotar.

**Issue é matéria-prima solta, não spec** — lida e triada só em plan mode: no início de toda sessão de plan mode, rode `gh issue list --label achado --state open` e leia o que houver. Cada item vira uma das três coisas — entra na spec da fase em andamento (se couber no escopo já decidido), vira linha no `ROADMAP.md` como fase própria (se for maior), ou vira ADR/item de `DEBITO-TECNICO.md` (se for decisão registrada, não trabalho). Achado avaliado e recusado tem destino próprio: **ADR com status `rejeitado`** registrando o porquê do "não". Depois de triado, **feche a issue** (`gh issue close`) referenciando o destino — a fase no `SETUP.md`/`ROADMAP.md`, o ID do ADR (aceito ou rejeitado), ou o ID do débito. Issue aberta e sem destino depois do plan mode é sinal de triagem pela metade.

## Docs auxiliares — onde cada coisa mora

Os **5 docs vivos são um conjunto fixo — não se adiciona doc vivo.** Todo o resto roteia pra um balde, pra `docs/` raiz não virar zona de documentos:

| Tipo | Casa |
| ---- | ---- |
| decisão de arquitetura | **ADR** (`docs/adr/`) |
| convenção de código/UI | **`CONVENCOES.md`** |
| débito | **`DEBITO-TECNICO.md`** |
| referência durável (how-to, deploy, prompts, i18n) | **`docs/reference/`** — cabeçalho de 1 linha dizendo pra que serve; linkada do README; lida sob demanda |
| investigação / spike / comparação | **efêmero** — `docs/scratch/` (ignorado no git); distila num balde acima **ou é descartado**, nunca acumula |

**Regra de ouro:** todo doc commitado tem uma casa e um propósito de 1 linha. Se não cabe em nenhum balde, provavelmente não deve ser commitado. **Invariante:** `docs/` raiz = só os docs vivos (+ `adr/`, `history/`, `reference/`).

## Regra de migração — mantenha os vivos enxutos

A regra mais importante. O detalhe de "como/por quê" tem três destinos, por tipo:

- **decisão de arquitetura** (por que esta forma/lib/padrão) → **ADR** em `docs/adr/`.
- **narrativa de implementação não-arquitetural** (desviei da spec por X; o caminho óbvio falhou por Y) → **bloco "Notas de implementação" na entrada da fase** no SETUP-HISTORICO.
- **o diff literal** (o que exatamente mudou) → **git**, que já o guarda; markdown não duplica.

**A cada commit**, mantenha os vivos em dia: registre a entrega no `CHANGELOG.md` (uma linha), atualize `DEBITO-TECNICO.md` (débito novo/resolvido) e, se a entrega divergiu do pedido por decisão de arquitetura, adicione um ADR.

**Ao concluir uma fase:**

1. Rode os critérios de sucesso da spec.
2. Mova a spec inteira de `SETUP.md` → `history/SETUP-HISTORICO.md` (append), anexando na mesma entrada um bloco **"Notas de implementação"** com o que vale reler depois (desvios, soluções não-óbvias, becos evitados) — memória, não log passo-a-passo, que o git já tem. Escreva nota só quando houver algo que mereça.
3. Colapse a fase em **uma linha** no `CHANGELOG.md`: `F-xxx — o que entrou — AAAA-MM-DD`.
4. **Remova** a fase do `ROADMAP.md` (o CHANGELOG é que guarda o entregue).
5. Ponha a próxima spec em `SETUP.md` (agora vazio).

**Ao tomar uma decisão de arquitetura:**

1. Escreva o ADR completo em `docs/adr/ADR-NNN.md` (use `docs/adr/TEMPLATE.md`).
2. Adicione **uma linha** ao índice `docs/DECISOES.md`: `ADR-NNN — título — status`.
3. ADR aceito é imutável. Pra revogar, crie um novo ADR e mude o **status** do antigo pra `superseded por ADR-MMM` no índice — o antigo permanece visível, sempre.
4. **Decidir não fazer também é decisão:** proposta avaliada e recusada vira ADR com status `rejeitado` — mesmo formato, com o porquê da recusa nas Consequências. É o que impede a ideia de voltar à mesa a cada seis meses, e o ponteiro pra onde o "não" foi argumentado.

**Ao resolver um débito:**

1. Mova o item **inteiro** de `DEBITO-TECNICO.md` → `history/DEBITO-RESOLVIDO.md`, sem deixar linha de índice no ativo. O vivo mostra só o que está aberto.
2. Acrescente uma **nota de como foi resolvido** (em qual fase, como).

**Princípio do ponteiro:** ao resumir numa linha, a linha referencia onde está o detalhe (o ID da fase no SETUP-HISTORICO, o ID do ADR). Resumo com ponteiro é compressão; sem ponteiro é perda.

**Teto por item, e ele é um teto — não uma licença.** Item de `DEBITO-TECNICO`: **no máximo 3 frases** — o defeito com `arquivo:linha`, a consequência prática, e `Correção:` nomeada. Linha de `ROADMAP`: **uma**, com ID + objetivo + o que a fase fecha. Todo *porquê histórico* — que fase criou, o que foi tentado, o que o dono recusou, como a fase foi fatiada — mora no ADR ou na entrada da fase no `SETUP-HISTORICO`, **com ponteiro**. O objetivo é **menos contexto por leitura**. Ao cortar, o `Correção:` é a única parte que fica sempre — é a única acionável.

**Todo débito fica registrado.** Pra depois → item em `DEBITO-TECNICO` (ID + até 3 frases + severidade). Resolvido → migra pro histórico. Aceito como limitação → registra como tal. Não há quarta saída.

## Quando pedir confirmação

Confirme quando há **risco real ou dúvida real** — não a cada passo. Dentro de uma tarefa já aprovada, execute sem pausar; pare nos casos abaixo.

**SEMPRE pedir confirmação (risco real):**

- Operações destrutivas ou irreversíveis: drop table, delete em massa, `force-push`, remover arquivos, reescrever histórico git.
- Gasto significativo: rodar processo caro, consumir recurso em volume, qualquer coisa que custe de verdade.
- Instalar dependência nova não prevista.
- Mudar arquitetura, trocar biblioteca, ou alterar schema do banco.
- Tocar em segredos, credenciais ou `.env`.
- Ao final de cada fase do `SETUP.md` (marco explícito).

**Pedir confirmação quando houver DÚVIDA real:**

- Requisito com duas interpretações razoáveis, e a escolha muda o resultado.
- Especificação que aparenta inconsistência com outra parte do projeto.
- Trade-off técnico real entre duas opções, sem vencedor claro.

**Seguir direto (apenas execute):**

- Passos rotineiros e reversíveis de tarefa aprovada (criar/editar arquivo, build, testes, formatar, dev server, `git add`/`commit` local no escopo).
- Decisões pequenas e óbvias dentro do escopo.
- Leituras (ler, grep, ls, inspecionar estado).

Em dúvida entre pausar ou seguir num passo **reversível e de baixo risco**, **siga e relate depois**. Reserve as pausas pra risco e ambiguidade reais.

## Git — uma fase, uma branch, um PR

- **`main` só recebe merge de PR.** Ele é protegido, e toda fase nasce numa branch a partir do `main` atualizado. **Nunca commite direto no `main`.**
- **Uma fase = uma branch = um PR.** A spec pode ser entregue em **1+ etapas**, e **cada etapa é um commit** na branch da fase — commite a etapa que terminou antes de abrir a próxima. Nome da branch: `fase/F-xxx-slug` (trabalho avulso fora de fase: `fix/slug`, `chore/slug`).
- **Commits: Conventional Commits.** Prefixos `feat: fix: docs: test: refactor: chore:`; mensagem no imperativo, escopo claro, uma etapa por commit, sem refatoração não pedida junto. **Nunca** adicione trailer de atribuição de IA (`Co-Authored-By` ou similar).
- **O fecho da fase é 100% do agente, depois da validação do dono.** O agente roda os critérios de sucesso e a revisão de fecho e **para**, relatando o resultado; PR, checks, merge e limpeza de branch esperam o dono validar (salvo se o prompt de abertura autorizar o fecho sem teste). Liberado, o fecho corre inteiro e sem pausa no meio: abre o PR (corpo curto: o que/por quê + critérios, referência à `F-xxx`) via `gh`/CLI do forge → confirma checks verdes → **integra por `gh pr merge --rebase` → apaga a branch (remota E local) → sincroniza o `main` local** (`git switch main && git pull`). O dono não toca no GitHub. Ao terminar, `git branch` mostra só `main`, atualizado com o `origin/main`.
- **Um CI por fecho.** Checks verdes conferidos **antes** do merge; o build de imagem que dispara no merge é entrega, não gate — o fecho termina no merge.
- **Histórico linear — sempre `--rebase`.** `gh pr merge --rebase` põe os commits da fase lineares no `main`, preservando 1 commit por etapa. **Nunca** `--merge` (criaria merge commit e ramificaria o gráfico) nem `--squash` (colapsaria as etapas num commit só). O histórico do `main` é uma linha reta.
- **Reescrita de história só no que ainda é local.** `rebase`/`amend`/`force-push` valem enquanto a branch não foi publicada; branch já em PR é imutável. (Config do repo: `main` protegido exigindo PR + checks verdes, mas permitindo o merge do agente — senão o loop trava.)

## Em resumo

> Pergunte mais. Codifique menos. Verifique sempre.
> Não suponha. Não embeleze. Não toque no que não foi pedido.
> Cada fase tem fim. Cada fim tem aprovação. Sem atalhos.
