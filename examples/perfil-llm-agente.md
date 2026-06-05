# Perfil: projetos de LLM / agentes (add-on opcional)

> **Não faz parte do núcleo do template.** É um conjunto de princípios extras pra quem constrói sistemas de LLM/agentes (orquestração, integração com modelos, custo de inferência). Num projeto sem LLM, ignore este arquivo.

## Como acoplar ao seu projeto

1. Copie este arquivo pra raiz do seu repo (ex.: `PERFIL-LLM.md`).
2. Referencie no seu `AGENTS.md`, numa linha: *"Projeto de LLM/agentes — veja também `PERFIL-LLM.md`."*
3. (lado chat) Se as conversas vão discutir arquitetura de agente, suba também nos **files do projeto** — é estável, como o `CONVENCOES.md`.

## Princípios

### Cost-aware

- Toda integração com LLM captura tokens in/out e custo. Sem exceção.
- Declare a estimativa de custo por execução nos comentários do agente.
- Log de custo em cada chamada — não confie em estimativa de memória.

### Human-in-the-loop por padrão (no runtime do produto)

- Toda ação que envia email, posta em rede, gasta dinheiro, ou modifica recurso externo passa por pedido de aprovação **por padrão**.
- O dono pode desativar explicitamente, mas o default é exigir aprovação.

### Config-as-Code com UI on top

- Config de agent/squad/skill/tool persistida no banco também tem **representação serializável** (JSON/YAML).
- Operação destrutiva (delete) faz export prévio automático antes de apagar.

### Composability over hardcoding

- Não hardcode prompts, modelos ou tools no código de aplicação — use registries.
- Tool genérica e reutilizável ganha de tool especializada one-off.

### Observability built-in

- Cada chamada a LLM passa por uma camada de observability (ex.: Langfuse ou equivalente).
- Cada execução grava input, output, tokens, custo, modelo, duração.
- Cada tarefa tem audit log de transições.

### Eval antes de promover

- Mudou system prompt em produção? Rode eval de regressão antes de marcar como ativo.
- Sem framework de eval ainda? No mínimo rode manualmente em 3–5 inputs conhecidos.

### Cost transparency em dois eixos

- Separe custo **cobrado por API** de custo **coberto por assinatura** — conflar os dois produz dado enganoso. Se um executor roda sob assinatura (sem cobrança por token), registre como coberto, não como zero "grátis".

