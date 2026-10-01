# capstone-knowledge — cérebro compartilhado do time

Um lugar único onde ficam as **decisões**, os **aprendizados** e os **contratos front ↔ back** do projeto, escritos pelos nossos agentes ao fim de cada tarefa e lidos automaticamente pelos agentes de todo mundo no início de cada sessão.

A memória do Claude Code é local de cada máquina. Este repositório é a memória do time.

## Como funciona

```
 sessão começa (back ou front)                      tarefa termina
          │                                               │
          ▼                                               ▼
 hook SessionStart do plugin `cerebro`           /cerebro:registrar
   1. git pull neste repositório                   1. garimpa a sessão: decisões,
   2. injeta no contexto do agente o índice           aprendizados, contratos
      das entradas ativas do repo em uso           2. compara com o que já existe
      (título + resumo + caminho)                     (substitui o que ficou velho)
          │                                        3. escreve 1 arquivo por entrada
          ▼                                        4. mostra pra você → commit + push
 agente lê o arquivo completo das
 entradas que tocam a tarefa
```

- **Um arquivo por entrada**: quatro pessoas escrevendo ao mesmo tempo não geram conflito de merge.
- **Nada se apaga**: decisão que mudou vira `status: substituido` e aponta para a nova. O índice só mostra o que está ativo, então ninguém trabalha com informação velha.
- **Filtro por repo**: no backend o agente vê `repos: [backend]` e `[ambos]`; no frontend, `[frontend]` e `[ambos]`. Contratos aparecem nos dois.

## Setup (cada pessoa, uma vez)

1. Clone este repositório **ao lado** dos repositórios de código:

   ```
   ~/capstone/
   ├── 202602_INTELBRAS_VisaoComputacional_Backend/
   ├── 202602_INTELBRAS_VisaoComputacional_Frontend/
   └── capstone-knowledge/
   ```

   Se preferir outro lugar, exporte `CAPSTONE_KNOWLEDGE_DIR=/caminho/do/clone` no seu shell.

2. Instale o plugin no Claude Code:

   ```
   /plugin marketplace add thevitorhideki/capstone-knowledge
   /plugin install cerebro@capstone
   ```

3. Reinicie o Claude Code. A sessão já começa com o bloco "Cérebro compartilhado do time" no contexto.

Para que o Claude Code ofereça o plugin automaticamente a quem abrir os repositórios de código, adicione em `.claude/settings.json` do backend e do frontend:

```json
{
  "extraKnownMarketplaces": {
    "capstone": {
      "source": { "source": "github", "repo": "thevitorhideki/capstone-knowledge" }
    }
  },
  "enabledPlugins": {
    "cerebro@capstone": true
  }
}
```

## Dia a dia

- **Começou uma tarefa**: nada a fazer. O agente já recebe o índice e lê o que for relevante.
- **Terminou uma tarefa** (antes de abrir o PR): rode `/cerebro:registrar`. O agente propõe as entradas e só faz commit e push depois que você aprovar.
- **Mudou endpoint, payload ou enum entre front e back**: o `/cerebro:registrar` atualiza `contratos/<dominio>.md`. Quem estiver do outro lado vê na próxima sessão.
- **Quer consultar algo**: pergunte ao agente ("o que o time já decidiu sobre autenticação?"). Ele faz grep aqui.

## Estrutura

| Pasta | O que vai | Formato |
|---|---|---|
| `decisoes/` | Escolhas entre alternativas que definem como o código deve ser escrito | `AAAA-MM-DD-slug.md`, imutável (só muda o `status`) |
| `aprendizados/` | Coisas não óbvias que custaram tempo: pegadinhas, causas de bugs, comandos | `AAAA-MM-DD-slug.md`, pode ser editado |
| `contratos/` | Interface front ↔ back: semântica, regras, quem consome, mudanças em andamento | `<dominio>.md`, documento vivo |
| `templates/` | Modelos das três estruturas acima | — |
| `plugin/` | O plugin `cerebro` (hook + skill) | — |

## O que vale registrar

Registre o que **o próximo a tocar o código precisaria saber e não descobriria lendo o código**. Não registre o que é óbvio no código, detalhes que só valem para aquela tarefa, nem o que já está no PR. O índice entra no contexto de todo mundo em toda sessão: menos e melhor vale mais que muito e raso.

## Evoluindo o plugin

Alterou `plugin/` (hook ou skill)? Suba a `version` em `plugin/.claude-plugin/plugin.json` e em `.claude-plugin/marketplace.json`. Cada pessoa atualiza com `/plugin marketplace update capstone`. As entradas de conhecimento não precisam disso: chegam pelo `git pull` do hook.
