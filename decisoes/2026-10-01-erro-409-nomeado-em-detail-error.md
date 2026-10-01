---
titulo: Conflito nomeado da API vem em detail.error, com message legível ao lado
data: 2026-10-01
autor: Vitor Katakura
repos: [ambos]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/8
tags: [api, erros, contrato]
resumo: 409 com código nomeado responde {"detail": {"error": "<codigo>", "message": "<texto em português>"}}; o front decide pelo error e mostra o message.
---

## Contexto

A Arquitetura v3 (§2) manda o 409 trazer "um error nomeado no corpo" (`code_taken`, `slug_taken`, `address_taken`, `camera_busy`, `session_limit`, `revision_conflict`), mas não fixa o formato. Os três escopos da reestruturação (fila, testes-engine, amarrar-banco) estão sendo escritos em paralelo, e o `src/lib/api.ts` do front hoje só lê `detail` como string ou como lista do Pydantic.

## Decisão

- O corpo é o `HTTPException` padrão do FastAPI com `detail` em objeto: `{"detail": {"error": "camera_busy", "message": "A câmera X está reservada..."}}`.
- `error` é o código estável que o front usa para decidir o que fazer. `message` é texto em português, pronto para exibir.
- Os 409 antigos com `detail` em string continuam como estão (ex.: IP:porta repetido em `/cameras`) até alguém migrá-los para `address_taken` junto com o front.

## Alternativas descartadas

- `{"error": ...}` na raiz do corpo — exige handler de exceção próprio e foge do formato que o front já interpreta.
- Só o código, sem `message` — obrigaria o front a manter um texto por código antes de poder exibir qualquer coisa.

## Consequências

- Back: novos conflitos nomeados seguem `HTTPException(409, detail={"error": ..., "message": ...})` (ex.: `app/api/routes/cameras.py`, `app/api/routes/drivers.py`).
- Front: `detailToMessage` em `src/lib/api.ts` precisa aceitar `detail` em objeto (mostrar `detail.message`) e o `ApiError` deve expor `detail.error`.
