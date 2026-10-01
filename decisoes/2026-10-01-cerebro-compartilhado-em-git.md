---
titulo: Conhecimento do time fica no repositório capstone-knowledge, distribuído por plugin do Claude Code
data: 2026-10-01
autor: Vitor Katakura
repos: [ambos]
status: ativo
substituido_por:
pr:
tags: [processo, agentes]
resumo: Decisões, aprendizados e contratos front↔back vão para o capstone-knowledge via /cerebro:registrar ao fim de cada tarefa; o plugin injeta o índice em toda sessão.
---

## Contexto

O time tem 4 pessoas, cada uma com seu Claude Code, trabalhando em dois repositórios (backend FastAPI e frontend React). A memória do Claude Code é local de cada máquina, então decisões e descobertas feitas numa sessão não chegavam às outras pessoas, e o conhecimento ficava defasado entre elas.

## Decisão

- Um repositório git único (capstone-knowledge) guarda decisões, aprendizados e contratos front↔back em markdown, um arquivo por entrada.
- O mesmo repositório é um marketplace com o plugin `cerebro`: um hook de início de sessão atualiza o clone local e injeta o índice das entradas ativas relevantes para o repo em uso, e a skill `/cerebro:registrar` grava o conhecimento novo ao fim de cada tarefa.
- Decisões não são apagadas: quando mudam, a antiga é marcada como substituída e aponta para a nova.

## Alternativas descartadas

- `docs/` dentro de cada repositório — o agente do frontend não veria as decisões do backend, e decisões que cruzam os dois ficariam duplicadas ou perdidas.
- Banco vetorial ou servidor MCP de memória — infraestrutura para manter, conteúdo opaco e sem revisão por diff; com o volume de um time de 4, markdown + grep basta.
- Notion/Docs — exige conector e não entra automaticamente no contexto dos agentes; sem histórico por diff.

## Consequências

- Ao terminar uma tarefa, rodar `/cerebro:registrar` antes de abrir o PR.
- Decisões ativas valem como acordo do time; para mudar uma, registrar nova decisão que a substitui.
- Mudanças de API entre front e back atualizam `contratos/` na mesma tarefa.
