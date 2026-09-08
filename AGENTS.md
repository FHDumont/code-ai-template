# AGENTS.md

Instruções para o agente de código deste projeto. **Núcleo agnóstico de ferramenta** — vale em qualquer stack e qualquer agente. Use como está.

- Mecânica por ferramenta: `CLAUDE.md` (Claude Code), `.cursor/rules/metodo.mdc` (Cursor).
- Convenções de código/UI **deste** projeto: `CONVENCOES.md`. Linguagem ubíqua do domínio: `CONTEXT.md`.
- Projeto de LLM/agentes: acople o add-on opcional e referencie aqui (ex.: `PERFIL-LLM.md`). Instruções no README.

## O loop — plan e code

Uma superfície, **dois modos** — os dois são você, os dois com o repo na mão:

- **Plan mode (raciocínio):** lê os docs vivos e **audita o código real**, discute o aberto com o dono (uma pergunta por vez), e **grava a spec da fase no `docs/SETUP.md`** — e para aí. Ler código é o trabalho desta passada; **escrever código é da outra**.
- **Code mode (execução):** em sessão nova (contexto limpo), lê a spec do `SETUP.md`, implementa aterrado no código, roda os critérios de sucesso na mesma resposta, e atualiza os docs vivos numa única passada antes de encerrar.

Entre os dois, uma **fronteira dura**: é o dono que limpa o contexto e abre a execução. Cada fase é tarefa independente — o contexto mora nos docs vivos, não na sessão.

Como o planejador **tem o repo**, a spec nasce confirmada contra o código: nomes de arquivo e símbolo são **verificados no plan mode**, não "hipóteses a confirmar". Ainda assim a verdade é o código — se em code mode a realidade diverge da spec, implemente o que é correto e **registre a divergência** (nota na fase, ou ADR se for decisão de arquitetura).

- **Audite o estado antes de modelar.** Fase que mexe em schema, enum ou estado persistido: no plan mode, audite o código real (migrations, tipos, dados) antes de escrever a spec. Barato, e evita spec que presume estado que não existe.
- **Uma fase de cada vez.** `docs/SETUP.md` tem **uma** spec, e as fases entram na ordem do ROADMAP. Implemente, atualize os vivos, **pare**, resuma ao dono e peça aprovação pra próxima.
- **Fique no modo até a fase fechar.** Se, em code mode, a conversa puxa pra fora do escopo da spec atual (nova ideia, decisão de arquitetura, refatoração não pedida), **pare e pergunte ao dono**: seguir no code, dentro do escopo, ou voltar pro plan pra tratar aquilo como fase própria? É o mesmo princípio de "sem refatoração de carona", aplicado à troca de modo.
- **Revisão de fecho com contexto fresco.** Ao fechar a fase em code mode — depois de rodar os critérios, antes do commit — dispare um **subagente sem o contexto da sessão**, que recebe só os *docs vivos + o diff* e confere se o entregue bate com a intenção da spec. Limpo → passada única de docs + commit. Divergiu → corrija antes. Fase que não toca código pode pular.
- **O plano durável é a spec.** A spec no `docs/SETUP.md` é o plano canônico (o porquê arquitetural distila em ADR; a regra de comportamento, em `R-NNN`; a narrativa de implementação, ao fechar, no arquivo da fase em `docs/history/fases/`). O arquivo de plano nativo da ferramenta (Claude Code `~/.claude/plans`, Cursor) é **rascunho efêmero — fica fora do git**. **A spec é enxuta** (`templates/spec-fase.md`): passos e etapas de uma linha, porquê por ponteiro (ADR, `R-NNN`, termo do `CONTEXT.md`) sem reproduzir o argumento, e a árvore do grilling (`Q1…Qn`) **não entra** — só as decisões que ela produziu. Teto orientativo de 4 KB.
- **Revisão que divergiu roda de novo sobre a correção.** A correção abre defeito novo com frequência, e só a segunda passada de contexto fresco vê.
- **Tela nova se mostra durante a execução**, não no fecho: screenshot da etapa pro dono enquanto se faz.

## Stack e comandos

> Ajuste esta seção pro seu projeto.
>
> - Build: `...`
> - Test: `...`
> - Lint/format: `...`
> - Run local: `...`

Duas regras valem em qualquer stack:

- **Markdown em uma linha física por parágrafo.** Em **qualquer** `.md` (não só os vivos), cada parágrafo/bullet/célula ocupa uma linha só, por mais longa que fique — o wrap é do editor. Quebra de linha só **entre** parágrafos, e edição sempre à mão: hard-wrap polui o diff, formatador automático corrompe tabelas.
- **O ambiente é do dono.** Ele sobe e derruba o ambiente **manualmente**; precisa dele reiniciado, **peça**. Build, typecheck, lint, testes e leitura de código são livres — rodam sem o ambiente de pé e dispensam pedido.

## Princípios de execução

Cinco falhas comuns de agente de código que este projeto evita ativamente (destiladas das observações de Andrej Karpathy sobre LLMs em código — ver [`andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills)):

1. **Trabalhe por critério de sucesso, não por receita.** Agente é ótimo em iterar até bater uma meta. Antes de codar, declare os critérios de sucesso em alto nível; implemente; verifique cada um explicitamente com execução real — teste, build, run — e itere no que falhar. "Feito" só depois da verificação. Em correção de bug: escreva primeiro um teste que **reproduz** o bug e corrija até ele passar, só até aí. O teste da fase tem que **falhar no código antigo**: prove o vermelho com execução real (worktree ou patch revertido), não por raciocínio. Número errado na tela se **decompõe termo a termo** contra o gravado antes de qualquer correção de UI.
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


Detalhe pesado vive fora dos vivos: texto cheio de ADR em `docs/adr/`, regras de comportamento `R-NNN` em `docs/reference/`, specs concluídas (+ notas de implementação) em `docs/history/fases/<ID>.md` — um arquivo por fase, com `docs/history/SETUP-HISTORICO.md` como índice de uma linha por fase —, débito fechado em `docs/history/DEBITO-RESOLVIDO.md`.

**Quente vs. frio (economia de contexto).** Plan mode pré-carrega só **SETUP + ROADMAP + `CONTEXT.md`** — este último é o glossário de **linguagem ubíqua** do domínio, **uma linha por termo**, e a spec e o código herdam o vocabulário dele; o texto cheio de cada termo (exemplos, números, mecanismo) é frio e mora em `docs/reference/dominio.md`. Termo afiado numa conversa de plan mode entra nos dois na mesma passada. Some `DEBITO-TECNICO` se a fase toca área com débito conhecido. **CHANGELOG, DECISOES e o texto cheio dos ADRs são frios** — ledgers que crescem sem teto; consulte sob demanda (`grep` pelo ID).

## Inbox de achados — GitHub Issues

Fora dos docs vivos existe um inbox informal: **issues do GitHub com label `achado`**, template em `.github/ISSUE_TEMPLATE/achado.md`. É onde o dono registra sem fricção, a qualquer momento, um problema ou uma melhoria que encontrou usando o app.

**Issue é matéria-prima solta, não spec** — lida e triada só em plan mode: no início de toda sessão, rode `gh issue list --label achado --state open` e leia o que houver. Cada item vira uma das três coisas — entra na spec da fase em andamento (se couber no escopo já decidido), vira linha no `ROADMAP.md` como fase própria (se for maior), ou vira ADR/item de `DEBITO-TECNICO.md` (se for decisão registrada, não trabalho — inclusive ADR com status `rejeitado`, quando a decisão é não fazer). Depois de triado, **feche a issue** (`gh issue close`) referenciando o destino — a fase no `SETUP.md`/`ROADMAP.md`, o ID do ADR (aceito ou rejeitado), ou o ID do débito. Issue aberta e sem destino depois do plan mode é sinal de triagem pela metade.

## Docs auxiliares — onde cada coisa mora

Os **5 docs vivos são um conjunto fixo — não se adiciona doc vivo.** Todo o resto roteia pra um balde:

| Tipo | Casa |
| ---- | ---- |
| decisão de arquitetura | **ADR** (`docs/adr/`) — só o que passa no teste de §Regra de migração |
| regra de comportamento (o que o sistema faz, com exemplo) | **`R-NNN`** em `docs/reference/<assunto>.md` — viva, editável, citada pelo ID |
| convenção de código/UI | **`CONVENCOES.md`** |
| débito | **`DEBITO-TECNICO.md`** |
| referência durável (how-to, deploy, prompts, i18n) | **`docs/reference/`** — cabeçalho de 1 linha dizendo pra que serve; linkada do README; lida sob demanda |
| investigação / spike / comparação | **efêmero** — `docs/scratch/` (ignorado no git); distila num balde acima **ou é descartado**, nunca acumula |

**Regra de ouro:** todo doc commitado tem uma casa e um propósito de 1 linha. Se não cabe em nenhum balde, provavelmente não deve ser commitado. **Invariante:** `docs/` raiz = só os docs vivos (+ `adr/`, `history/`, `reference/`).

## Regra de migração — mantenha os vivos enxutos

A regra mais importante. O detalhe de "como/por quê" tem quatro destinos, por tipo:

- **decisão de arquitetura** (por que esta forma/lib/padrão) → **ADR** em `docs/adr/`.
- **regra de comportamento** (o que o sistema faz hoje, com o exemplo que a fixou) → **`R-NNN`** em `docs/reference/<assunto>.md`.
- **narrativa de implementação não-arquitetural** (desviei da spec por X; o caminho óbvio falhou por Y) → **bloco "Notas de implementação" no arquivo da fase** em `docs/history/fases/`.
- **o diff literal** (o que exatamente mudou) → **git**. Markdown não duplica o que o git já guarda.

**A cada commit**, mantenha os vivos em dia: registre a entrega no `CHANGELOG.md` (uma linha), atualize `DEBITO-TECNICO.md` (débito novo/resolvido) e, se a entrega divergiu do pedido por decisão de arquitetura, adicione um ADR.

**Ao concluir uma fase:**

1. Rode os critérios de sucesso da spec.
2. Mova a spec inteira de `SETUP.md` → `docs/history/fases/F-xxx.md` (arquivo novo) e acrescente **uma linha** no índice `history/SETUP-HISTORICO.md`, anexando no arquivo da fase um bloco **"Notas de implementação"** com o que vale reler depois (desvios, soluções não-óbvias, becos evitados) — memória, não log passo-a-passo, que o git já tem. Escreva nota só quando houver algo que mereça.
3. Colapse a fase em **uma linha** no `CHANGELOG.md`: `F-xxx — o que entrou — AAAA-MM-DD`.
4. **Remova** a fase do `ROADMAP.md` (o CHANGELOG é que guarda o entregue).
5. Ponha a próxima spec em `SETUP.md` (agora vazio).

**ADR ou regra? — o teste.** Só é ADR o que passa em pelo menos um: muda **contrato** entre pacotes ou API pública; muda **schema** de forma estrutural; adiciona ou troca **dependência, lib ou padrão transversal** (auth, cache, RLS, jobs, CI); custa **mais de uma fase** pra reverter; ou é decisão de **método** ou de **escopo do produto**. O resto — como a linha casa, como a fatura soma, o que a tela mostra, qual perna é a manchete, como o import deduplica — é **regra de comportamento**: `R-NNN` em `docs/reference/<assunto>.md`, viva e editável, no presente, com exemplo, âncora `arquivo › símbolo`, o rejeitado e a origem. Na dúvida é regra: ADR é a exceção. A recusa segue a mesma régua — recusa arquitetural é ADR `rejeitado`; recusa de regra mora no `**Rejeitado:**` da regra; escolha de escopo mora na spec. O projeto de origem deste método chegou a 341 ADRs em 248 fases com 5 `superseded` — a maioria era regra, e a verdade atual de cada uma estava espalhada por uma cadeia de emendas.

**Emenda não reabre o corpo nem infla o índice.** ADR novo que estreita, corrige ou envelhece um aceito escreve `emenda ADR-NNN` no próprio cabeçalho e **uma linha** no bloco `## Emendas` no rodapé do ADR emendado (`ADR-MMM (F-xxx) — o que muda`). O corpo acima do bloco nunca se edita. A linha do índice fica **uma linha**, e o status é exatamente um de `accepted` · `rejeitado` · `superseded por ADR-MMM` · `deprecated` · `regra R-NNN` (ADR migrado pra regra: a linha fica, é o ponteiro que mantém toda citação viva). `DECISOES.md` é secionado por **assunto**, seções fixas; ADR novo entra na seção dele, não no fim.

**Ao tomar uma decisão de arquitetura:**

1. Escreva o ADR completo em `docs/adr/ADR-NNN.md` (use `docs/adr/TEMPLATE.md`).
2. Adicione **uma linha** ao índice `docs/DECISOES.md`: `ADR-NNN — título — status`.
3. ADR aceito é imutável (o bloco `## Emendas` do rodapé é a única parte mutável). Pra revogar, crie um novo ADR e mude o **status** do antigo pra `superseded por ADR-MMM` no índice — o antigo permanece visível, sempre.
4. **Decidir não fazer também é decisão:** proposta avaliada e recusada vira ADR com status `rejeitado` — mesmo formato, com o porquê da recusa nas Consequências. É o que impede a ideia de voltar à mesa a cada seis meses, e o ponteiro pra onde o "não" foi argumentado.

**Ao resolver um débito:**

1. Mova o item **inteiro** de `DEBITO-TECNICO.md` → `history/DEBITO-RESOLVIDO.md`, sem deixar linha de índice no ativo. O vivo mostra só o que está aberto.
2. Acrescente uma **nota de como foi resolvido** (em qual fase, como).

**Perf especulativa não vira débito.** Custo medido e ainda confortável é nota da fase, com o número; item vivo só quando há defeito ou compromisso não cumprido.

**Princípio do ponteiro:** **resuma sempre com ponteiro** — a linha resumida referencia onde está o detalhe (o arquivo da fase em `docs/history/fases/`, o ID do ADR). Com ponteiro é compressão; sem ponteiro é perda.

**Teto por item, e ele é um teto — não uma licença.** Item de `DEBITO-TECNICO`: **no máximo 3 frases** — o defeito com `arquivo:linha`, a consequência prática, e `Correção:` nomeada. Linha de `ROADMAP`: **uma**, com ID + objetivo + o que a fase fecha. Todo *porquê histórico* — que fase criou, o que foi tentado, o que o dono recusou, como a fase foi fatiada — mora no ADR ou na arquivo da fase em `docs/history/fases/`, **com ponteiro**. O objetivo é **menos contexto por leitura**. Ao cortar, o `Correção:` é a única parte que fica sempre — é a única acionável.

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
- **ID da fase:** o maior `F-NNN` presente em `CHANGELOG`, `history/SETUP-HISTORICO.md` e `ROADMAP`, mais um — não "o último que eu vi mais um".
- **Com subagente rodando, nunca `git add -A`.** O working tree é compartilhado: adicione por caminho explícito e confira o `git status` antes de commitar.
- **Uma fase = uma branch = um PR.** A spec pode ser entregue em **1+ etapas**, e **cada etapa é um commit** na branch da fase — commite a etapa que terminou antes de abrir a próxima. Nome da branch: `fase/F-xxx-slug` (trabalho avulso fora de fase: `fix/slug`, `chore/slug`).
- **Commits: Conventional Commits.** Prefixos `feat: fix: docs: test: refactor: chore:`; mensagem no imperativo, escopo claro, uma etapa por commit, sem refatoração não pedida junto. **Nunca** adicione trailer de atribuição de IA (`Co-Authored-By` ou similar).
- **O pedido de fecho é a validação — o fecho é 100% do agente e corre até o fim sem pausa.** "Fechar fase" — digitado ou via ritual da ferramenta — significa que o dono testou e libera a sequência inteira. **Falha ainda para:** critério que falha ou revisão de fecho que diverge interrompem o fecho e voltam pro código — falha reportada, não pedido de confirmação. Liberado, o fecho corre inteiro: abre o PR (corpo curto: o que/por quê + critérios, referência à `F-xxx`) via `gh`/CLI do forge → confirma checks verdes → **integra por `gh pr merge --rebase` → apaga a branch (remota E local) → sincroniza o `main` local** (`git switch main && git pull`). O dono não toca no GitHub. Ao terminar, `git branch` mostra só `main`, atualizado com o `origin/main`.
- **Um CI por fecho.** Checks verdes conferidos **antes** do merge; o build de imagem que dispara no merge é entrega, não gate — o fecho termina no merge.
- **Histórico linear — sempre `--rebase`.** `gh pr merge --rebase` põe os commits da fase lineares no `main`, preservando 1 commit por etapa. **Nunca** `--merge` (criaria merge commit e ramificaria o gráfico) nem `--squash` (colapsaria as etapas num commit só). O histórico do `main` é uma linha reta.
- **Reescrita de história só no que ainda é local.** `rebase`/`amend`/`force-push` valem enquanto a branch não foi publicada; branch já em PR é imutável. (Config do repo: `main` protegido exigindo PR + checks verdes, mas permitindo o merge do agente — senão o loop trava.)

## Em resumo

> Pergunte mais. Codifique menos. Verifique sempre.
> Não suponha. Não embeleze. Não toque no que não foi pedido.
> Cada fase tem fim. Cada fim tem aprovação. Sem atalhos.
