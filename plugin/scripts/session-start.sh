#!/usr/bin/env bash
set -u

MAX_ITEMS=40
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

resolve_dir() {
  local c
  for c in "${CAPSTONE_KNOWLEDGE_DIR:-}" "$PROJECT_DIR" "$PROJECT_DIR/../capstone-knowledge" "$HOME/capstone/capstone-knowledge"; do
    if [ -n "$c" ] && [ -d "$c/decisoes" ] && [ -d "$c/templates" ]; then
      (cd "$c" && pwd)
      return 0
    fi
  done
  return 1
}

detect_repo() {
  local name
  name="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "$PROJECT_DIR")"
  name="$(basename "$name" .git | tr '[:upper:]' '[:lower:]')"
  case "$name" in
    *backend*) echo backend ;;
    *frontend*) echo frontend ;;
    *) echo todos ;;
  esac
}

sync_repo() {
  export GIT_TERMINAL_PROMPT=0
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"
  if ! git -C "$DIR" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    echo "sem branch remota configurada"
    return
  fi
  if ! git -C "$DIR" fetch --quiet >/dev/null 2>&1; then
    echo "offline — o índice pode estar desatualizado"
    return
  fi
  local ahead dirty
  ahead="$(git -C "$DIR" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  dirty="$(git -C "$DIR" status --porcelain | grep -c .)"
  if ! git -C "$DIR" merge --ff-only --quiet '@{u}' >/dev/null 2>&1; then
    echo "não foi possível atualizar (divergência com o remoto) — resolva no repositório de conhecimento"
    return
  fi
  if [ "$ahead" -gt 0 ] || [ "$dirty" -gt 0 ]; then
    echo "atualizado, mas há conhecimento local não publicado ($ahead commit(s), $dirty arquivo(s)) — publique com /cerebro:registrar"
    return
  fi
  echo "atualizado"
}

list_entries() {
  local folder="$1" empty="$2" files total=0 shown=0 f line
  files="$(ls -1r "$DIR/$folder"/*.md 2>/dev/null)"
  [ -z "$files" ] && { echo "($empty)"; return; }
  while IFS= read -r f; do
    line="$(awk -v repo="$REPO" -v path="$folder/$(basename "$f")" '
      NR == 1 { if ($0 != "---") exit; inside = 1; next }
      inside && $0 == "---" { closed = 1; exit }
      inside {
        key = $0; sub(/:.*/, "", key)
        val = $0; sub(/^[^:]*:[ \t]*/, "", val)
        meta[key] = val
      }
      END {
        if (!closed) exit
        if (meta["status"] != "" && meta["status"] != "ativo") exit
        r = meta["repos"]
        if (repo != "todos" && r != "" && index(r, repo) == 0 && index(r, "ambos") == 0) exit
        printf "- %s · %s — %s [%s]\n", meta["data"], meta["titulo"], meta["resumo"], path
      }
    ' "$f")"
    [ -z "$line" ] && continue
    total=$((total + 1))
    if [ "$shown" -lt "$MAX_ITEMS" ]; then
      echo "$line"
      shown=$((shown + 1))
    fi
  done <<< "$files"
  [ "$total" -eq 0 ] && echo "($empty relevante para este repo)"
  [ "$total" -gt "$shown" ] && echo "- … e mais $((total - shown)) entradas antigas — busque com grep em $folder/"
  return 0
}

list_contracts() {
  local files f
  files="$(ls -1 "$DIR/contratos"/*.md 2>/dev/null)"
  [ -z "$files" ] && { echo "(nenhum)"; return; }
  while IFS= read -r f; do
    echo "- contratos/$(basename "$f")"
  done <<< "$files"
}

if ! DIR="$(resolve_dir)"; then
  echo "[cérebro] Repositório capstone-knowledge não encontrado. Clone-o ao lado dos repositórios de código (ex.: ~/capstone/capstone-knowledge) ou defina CAPSTONE_KNOWLEDGE_DIR. Avise o usuário."
  exit 0
fi

REPO="$(detect_repo)"
SYNC="$(sync_repo)"

cat <<EOF
# Cérebro compartilhado do time (capstone-knowledge)

Local: $DIR
Repo desta sessão: $REPO
Sincronização: $SYNC

Este é o conhecimento acumulado pelas 4 pessoas do time e pelos agentes delas. Regras:
- Antes de implementar, confira abaixo as decisões e aprendizados que tocam a área da tarefa e leia o arquivo completo dos relevantes.
- Decisões ativas são acordos do time. Não as contradiga em silêncio: se a tarefa exigir mudar uma, avise o usuário e registre uma nova decisão que substitui a anterior.
- Se mudar a interface entre front e back (endpoint, payload, enum, evento), atualize contratos/ na mesma tarefa.
- Ao concluir uma tarefa (antes de abrir o PR), sugira ao usuário rodar /cerebro:registrar para salvar o que foi decidido e aprendido.

## Decisões ativas
$(list_entries decisoes nenhuma)

## Aprendizados
$(list_entries aprendizados nenhum)

## Contratos front ↔ back
$(list_contracts)
EOF
