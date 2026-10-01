---
titulo: Cancelamento de Run só entre células; CellContext.cancel sinaliza apenas lease perdido
data: 2026-10-01
autor: Vitor Katakura
repos: [backend]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/10
tags: [fila, worker, engine, cancelamento]
resumo: O worker relê cancel_requested entre células e nunca interrompe uma célula no meio; o cancel() passado a execute_cell (e daí a execute_definition) só fica verdadeiro quando o lease foi perdido.
---

## Contexto

A Estrutura de Dados v2 (§7) diz que o cancelamento é cooperativo e que "uma célula nunca é interrompida no meio". O brief do escopo 2 prevê `execute_definition(..., cancel=ctx.cancel)`, que o engine consulta entre passos. Se `ctx.cancel` refletisse o pedido do usuário, a célula corrente pararia no meio depois do glue.

## Decisão

- `POST /runs/{id}/cancel` em Run `running` só grava `cancel_requested`; `app/runner/run_executor.py` relê a flag antes de cada célula e fecha as restantes como `canceled`.
- `CellContext.cancel` (contrato em `app/runner/executor.py`) devolve verdadeiro só quando o lease foi perdido, porque aí nada mais será gravado e continuar só prende a câmera.
- Cancelar e repetir valem por Run, não por lote (`batch_id`).

## Alternativas descartadas

- `cancel` também para o pedido do usuário — cancelamento mais rápido, mas deixa o painel da câmera num estado que ninguém descreve e contradiz a Estrutura de Dados.

## Consequências

No glue do engine, `execute_definition(..., cancel=ctx.cancel)` continua correto: os passos restantes só viram `canceled` em perda de lease. Se o time quiser cancelamento no meio da célula, isso é nova decisão e muda `run_executor.run_cell`.
