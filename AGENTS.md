# AGENTS.md

Instruções para o agente de código deste projeto. **Núcleo agnóstico de ferramenta** — vale em qualquer stack e qualquer agente. Use como está.

- Claude Code: veja também `CLAUDE.md`.
- Convenções de código/UI **deste** projeto: `CONVENCOES.md`.
- Projeto de LLM/agentes: acople o add-on opcional e referencie aqui (ex.: `PERFIL-LLM.md`). Instruções no README.

## Seu papel no loop

Duas superfícies, papéis separados:

- **Chat (raciocínio):** discute e decide, e entrega uma **spec** de fase em texto. Não  escreve no repo.
- **Você (execução):** recebe a spec, implementa aterrado no código real, e atualiza os  docs vivos numa única passada antes de encerrar.

A spec pode citar nomes de arquivo ou símbolo — trate-os como **hipóteses**. A verdade é  o código. Se a realidade diverge da spec, implemente o que é correto e **registre a divergência** (nota na fase, ou ADR se for decisão de arquitetura).

## Stack e comandos

> Ajuste esta seção pro seu projeto.
>
> - Build: `...`
> - Test: `...`
> - Lint/format: `...`
> - Run local: `...`

## Princípios de execução

Cinco falhas comuns de agente de código que este projeto evita ativamente (destiladas das observações de Andrej Karpathy sobre LLMs em código):

1. **Trabalhe por critério de sucesso, não por receita.** Agente é ótimo em iterar até bater uma meta. Antes de codar, declare os critérios de sucesso em alto nível; implemente; verifique cada um explicitamente; itere no que falhar. Não declare "feito"  sem rodar verificação real — teste, build, execução.
2. **Gerencie a confusão — não suponha em silêncio.** A falha mais cara é assumir algo no lugar do dono e seguir em frente sem checar. Se o requisito é ambíguo, **pergunte**. Se dois pedidos se contradizem, **aponte** antes de seguir. Se há trade-off real, **apresente** os dois lados com prós/contras. Se discorda da abordagem, **diga** com argumento técnico.
3. **Sem refatoração de carona.** Toque só no escopo da tarefa. Código feio fora do escopo vira TODO, não refatoração agora. Não remova comentário que não entendeu — pode carregar contexto. Não renomeie variável fora do escopo. Não "limpe" código alheio sem pedir.
4. **Sem over-engineering.** Resolva o problema declarado — nem mais, nem menos. Não crie abstração "pro caso de um dia precisar"; crie quando precisar. Código direto e legível ganha de padrão complexo. YAGNI e KISS sempre.
5. **Preserve contexto.** Antes de mudar um arquivo, leia o suficiente pra entender o que ele faz. Não delete função/import sem certeza de que não é usado. Em dúvida, mantenha.

## Docs vivos — o que são

Ficam em `docs/`. São a memória compartilhada entre o chat, você, e as sessões futuras. Cada um responde a uma pergunta, no menor número de palavras:


| Doc                 | Responde                     | Forma                                 |
| ------------------- | ---------------------------- | ------------------------------------- |
| `ROADMAP.md`        | pra onde vamos               | fases futuras + a atual; 1 linha cada |
| `CHANGELOG.md`      | o que já entrou              | ledger: 1 linha por fase entregue     |
| `DECISOES.md`       | o que foi decidido e por quê | índice: 1 linha por ADR               |
| `DEBITO-TECNICO.md` | o que está aberto            | só débito ativo                       |
| `SETUP.md`          | o que estamos fazendo agora  | exatamente 1 spec                     |


Detalhe pesado vive fora dos vivos: texto cheio de ADR em `docs/adr/`, specs concluídas (+ notas de implementação) em `docs/history/SETUP-HISTORICO.md`, débito fechado em `docs/history/DEBITO-RESOLVIDO.md`.

## Regra de migração — mantenha os vivos enxutos

A regra mais importante. O detalhe de "como/por quê" tem três destinos, por tipo:

- **decisão de arquitetura** (por que esta forma/lib/padrão) → **ADR** em `docs/adr/`.
- **narrativa de implementação não-arquitetural** (desviei da spec por X; o caminho óbvio falhou por Y) → **bloco "Notas de implementação" na entrada da fase** no SETUP-HISTORICO.
- **o diff literal** (o que exatamente mudou) → **git**. Não duplique em markdown.

**A cada commit**, mantenha os vivos em dia: registre a entrega no `CHANGELOG.md` (uma linha), atualize `DEBITO-TECNICO.md` (débito novo/resolvido) e, se a entrega divergiu do pedido por decisão de arquitetura, adicione um ADR.

**Ao concluir uma fase:**

1. Rode os critérios de sucesso da spec.
2. Mova a spec inteira de `SETUP.md` → `history/SETUP-HISTORICO.md` (append). **Anexe ali, na mesma entrada, um bloco "Notas de implementação"** com o que vale reler depois  (desvios, soluções não-óbvias, becos evitados). Não é log passo-a-passo — isso o git já tem. Só escreva nota quando houver algo que mereça memória.
3. Colapse a fase em **uma linha** no `CHANGELOG.md`: `F-xxx — o que entrou — AAAA-MM-DD`.
4. **Remova** a fase do `ROADMAP.md` (o CHANGELOG é que guarda o entregue).
5. Ponha a próxima spec em `SETUP.md` (agora vazio).

**Ao tomar uma decisão de arquitetura:**

1. Escreva o ADR completo em `docs/adr/ADR-NNN.md` (use `docs/adr/TEMPLATE.md`).
2. Adicione **uma linha** ao índice `docs/DECISOES.md`: `ADR-NNN — título — status`.
3. ADR é imutável depois de aceito. Pra revogar, crie um novo ADR e mude o **status** do antigo pra `superseded por ADR-MMM` no índice — nunca delete nem esconda.

**Ao resolver um débito:**

1. Mova o item **inteiro** de `DEBITO-TECNICO.md` → `history/DEBITO-RESOLVIDO.md`, sem deixar linha de índice no ativo. O vivo mostra só o que está aberto.
2. Acrescente uma **nota de como foi resolvido** (em qual fase, como).

**Princípio do ponteiro:** ao resumir numa linha, a linha referencia onde está o detalhe (o ID da fase no SETUP-HISTORICO, o ID do ADR). Nunca resuma sem ponteiro.

**Débito nunca é descartado em silêncio.** Pra depois → vira linha em DEBITO-TECNICO (ID + 1 linha + severidade). Resolvido → migra. Aceito como limitação → registra como tal. Some sem registro → nunca.

## Quando pedir confirmação

O objetivo é confirmar quando há **risco real ou dúvida real** — não a cada passo. Dentro de uma tarefa já aprovada, execute sem pausar; só pare nos casos abaixo.

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

**NÃO pedir confirmação (apenas execute):**

- Passos rotineiros e reversíveis de tarefa aprovada (criar/editar arquivo, build, testes, formatar, dev server, `git add`/`commit` local no escopo).
- Decisões pequenas e óbvias dentro do escopo.
- Leituras (ler, grep, ls, inspecionar estado).

Em dúvida entre pausar ou seguir num passo **reversível e de baixo risco**, **siga e relate depois**. Reserve as pausas pra risco e ambiguidade reais.

## Uma fase de cada vez

`docs/SETUP.md` tem **uma** spec por vez. Implemente, atualize os vivos, **pare**, resuma ao dono e peça aprovação pra próxima. Não acumule specs. Não pule fases.

> **Exceção de bootstrap:** esta regra de fluxo é a única que o chat pode redigir como texto pra você inserir — não dá pra você escrever a regra que institui o fluxo antes de ela existir.

## Em resumo

> Pergunte mais. Codifique menos. Verifique sempre.
> Não suponha. Não embeleze. Não toque no que não foi pedido.
> Cada fase tem fim. Cada fim tem aprovação. Sem atalhos.

