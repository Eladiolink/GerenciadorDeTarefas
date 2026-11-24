#!/usr/bin/env bash
# Entrypoint do modo dev: compila o projeto, mantém um watcher de arquivos e
# inicia a aplicação. A cada alteração em src/ (ou no pom.xml) o watcher roda
# `mvn compile`, atualizando target/classes; o Spring DevTools detecta a mudança
# no classpath e reinicia apenas o contexto da aplicação (sem reconstruir a imagem).
set -euo pipefail

cd /workspace

echo "[hotreload] compilação inicial..."
mvn -B -ntp -nsu compile -DskipTests

watch_and_compile() {
  # -r recursivo em src/ + pom.xml. target/ fica de fora do watch, então a
  # própria compilação não dispara um novo ciclo. inotifywait nao permite
  # --include e --exclude juntos; por isso o filtro de extensão e o unico usado.
  while inotifywait -q -r \
    -e close_write,moved_to,create,delete \
    --include '\.(java|properties|yml|yaml|xml)$' \
    src pom.xml; do
    # Debounce: descarta eventos extras do mesmo save (editores geram vários).
    # Encerra após 1s sem eventos novos.
    while inotifywait -q -t 1 -r \
      -e close_write,moved_to,create,delete \
      --include '\.(java|properties|yml|yaml|xml)$' \
      src pom.xml; do :; done
    echo "[hotreload] alteração detectada — recompilando $(basename "$PWD")..."
    if mvn -B -ntp -nsu -q compile -DskipTests; then
      echo "[hotreload] compilação OK — o Spring DevTools vai reiniciar a aplicação"
    else
      echo "[hotreload] ERRO de compilação: corrija o código para que o restart ocorra" >&2
    fi
  done
}

watch_and_compile &
WATCH_PID=$!

mvn -B -ntp -Dmaven.test.skip=true spring-boot:run &
APP_PID=$!

cleanup() {
  trap - EXIT INT TERM
  kill "$APP_PID" "$WATCH_PID" 2>/dev/null || true
  wait "$APP_PID" "$WATCH_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Encerra o container se a aplicação (ou o watcher) morrer.
set +e
wait -n "$APP_PID" "$WATCH_PID"
STATUS=$?
set -e
exit "$STATUS"
