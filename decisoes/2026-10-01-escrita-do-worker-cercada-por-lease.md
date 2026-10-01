---
titulo: Toda escrita de resultado do worker passa por fenced_execute, com status='running' na cerca
data: 2026-10-01
autor: Vitor Katakura
repos: [backend]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/10
tags: [fila, worker, lease]
resumo: No worker, gravar passo, célula ou status de Run só via app/runner/lease.fenced_execute (SELECT FOR SHARE em runs com id, lease_epoch, locked_by e status='running'); falso = LeaseLost, abortar sem escrever.
---

## Contexto

A Arquitetura v3 (§5.5) exige que toda escrita de resultado leve `lease_epoch` e `locked_by` no filtro, para um worker que acordou tarde não sobrescrever o que o reaper decidiu. Só que o reaper marca a Run `interrupted` sem subir o `lease_epoch`, então um filtro só com epoch e dono ainda deixaria o worker atrasado gravar veredito numa Run já interrompida. E as escritas são de tipos diferentes (`INSERT` em `run_steps`, `UPDATE` em `run_cases` e em `runs`), o que impede depender do `rowcount` do próprio comando.

## Decisão

- `app/runner/lease.py:fenced_execute(db, stmt, run_id, epoch, worker_id) -> bool` primeiro faz `SELECT id FROM runs WHERE id AND lease_epoch AND locked_by AND status='running' FOR SHARE` e só então executa o comando. Sem linha: `rollback` e `False`.
- O `FOR SHARE` segura o `UPDATE` do reaper até o commit da escrita: ou ela entra antes da decisão do reaper, ou é recusada.
- `run_executor` traduz `False` em `LeaseLost` e aborta a Run sem gravar mais nada (só log de processo). Artefatos e linhas de log não são cercados: são evidência, não veredito.

## Alternativas descartadas

- `UPDATE ... WHERE lease_epoch AND locked_by` com `rowcount` — não serve para `INSERT` e confunde "célula não existe" com "lease perdido".
- Reaper subir o `lease_epoch` — funcionaria, mas espalha a regra por dois lugares; o `status` no filtro resolve no ponto da escrita.

## Consequências

Quem acrescentar escrita de resultado no worker (por exemplo, no glue do engine) usa `_RunExecution.fenced` em `app/runner/run_executor.py`, nunca `db.execute` direto. Escrita de longa duração (upload de trace) fica fora da transação que segura o `FOR SHARE`, para não travar heartbeat e reaper.
