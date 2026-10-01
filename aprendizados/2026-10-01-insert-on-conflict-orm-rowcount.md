---
titulo: insert(Model).on_conflict_do_nothing() pela Session devolve rowcount -1
data: 2026-10-01
autor: Vitor Katakura
repos: [backend]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/10
tags: [sqlalchemy, postgres, psycopg]
resumo: Com SQLAlchemy 2 + psycopg 3, INSERT ... ON CONFLICT DO NOTHING executado via Session (insert do model ORM) devolve rowcount -1; use .returning(col) e confira .first() is not None.
---

## Situação

`reservations.acquire` decidia se reservou a câmera pelo `result.rowcount == 1` de `insert(CameraReservationModel)...on_conflict_do_nothing(...)`, e sempre dava "câmera ocupada".

## O que descobrimos

Pela `Session`, o `insert()` de uma entidade ORM vira um INSERT habilitado para ORM, e o `CursorResult` volta com `rowcount == -1` mesmo quando a linha entra. `UPDATE` e `DELETE` pela mesma via devolvem `rowcount` normal.

## Como lidar

Acrescente `.returning(<coluna>)` e teste `result.first() is not None` (ver `app/services/reservations.py:acquire`). Para `UPDATE`/`DELETE`, `rowcount` continua confiável.
