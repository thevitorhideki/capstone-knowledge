---
titulo: Senha de câmera cifrada com Fernet e chave única por ambiente em CREDENTIAL_KEY
data: 2026-10-01
autor: Vitor Katakura
repos: [backend]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/8
tags: [seguranca, cameras, configuracao, migracao]
resumo: cameras.password_encrypted é Fernet com CREDENTIAL_KEY (fora do banco, uma chave por ambiente, a mesma na API, no worker e na migração 0005); só app/core/credentials.py cifra e decifra, e a senha nunca sai em resposta.
---

## Contexto

A senha da câmera é credencial de máquina: o executor precisa do valor original para digitá-la no painel, então hash não serve. Estrutura de Dados v2 §4 e Arquitetura v3 §8.2.

## Decisão

- `app/core/credentials.py` (`fernet`, `encrypt`, `decrypt`, `CredentialKeyMissing`) é a única porta. A chave vem de `CREDENTIAL_KEY` via `settings`, ou seja, do ambiente ou do `.env`, sem default.
- `CREDENTIAL_KEY` aceita lista separada por vírgula (MultiFernet): a primeira cifra e todas decifram. É assim que se roda a chave (procedimento no README).
- Quem decifra é o runner (`load_camera_for_run`, Parte B), no instante do uso. Rota nenhuma devolve `password` nem `password_encrypted`.
- A API se recusa a subir sem chave válida. A migração `0005_inventory` cifra as senhas existentes e falha antes de alterar o schema se não houver chave.

## Alternativas descartadas

- Cofre de segredos — mais um serviço para operar, sem reduzir o risco na proporção de um laboratório com poucas câmeras. A troca fica contida na coluna `password_encrypted`.
- Ler a chave só de `os.environ` na migração — o setup hook do Orca roda `alembic upgrade head` com o `.env` copiado da raiz, e por esse caminho a chave nunca seria encontrada.

## Consequências

- Uma chave por ambiente, compartilhada: o `.env` da raiz do backend precisa de `CREDENTIAL_KEY` antes do merge do escopo 3, porque todas as worktrees copiam esse arquivo e o banco de desenvolvimento é um só. Chaves diferentes por worktree deixariam as senhas ilegíveis para as outras.
- Perder a chave é perder as senhas: a saída é recadastrar cada câmera com `PATCH /api/cameras/{id}`.
- Testes usam uma chave fixa definida em `tests/conftest.py`; `tests/factories.make_camera(password=...)` cifra sozinho.
