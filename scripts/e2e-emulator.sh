#!/usr/bin/env bash

set -euo pipefail

COMMAND="${1:?uso: e2e-emulator.sh start|stop|cleanup ...}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/ganza-e2e"
STATE_FILE="$RUNTIME_DIR/emulator.state"

read_state() {
  [ -f "$STATE_FILE" ] || return 1
  # shellcheck disable=SC1090
  . "$STATE_FILE"
}

owns_process() {
  [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null &&
    tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null | grep -Fq -- "-avd $AVD"
}

stop_owned() {
  read_state || return 0
  if owns_process; then
    adb -s "$SERIAL" emu kill >/dev/null 2>&1 || kill "$PID" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$PID" 2>/dev/null || break
      sleep 1
    done
    kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null || true
  fi
  rm -f "$STATE_FILE"
}

case "$COMMAND" in
  start)
    AVD="${2:?AVD ausente}"
    SERIAL="${3:?serial ausente}"
    FUSO="${4:?fuso ausente}"
    LOG="${5:?log ausente}"
    mkdir -p "$RUNTIME_DIR"
    if read_state && owns_process; then
      echo "Emulador E2E já pertence a outro roteiro (pid $PID, AVD $AVD)." >&2
      exit 1
    fi
    rm -f "$STATE_FILE"
    if adb devices | grep -q "^$SERIAL[[:space:]]*device$"; then
      echo "O serial $SERIAL já está em uso e não pertence ao harness." >&2
      exit 1
    fi
    nohup emulator -avd "$AVD" -no-window -no-audio -no-boot-anim \
      -timezone "$FUSO" -gpu swiftshader_indirect -no-snapshot > "$LOG" 2>&1 &
    PID=$!
    printf 'PID=%q\nSERIAL=%q\nAVD=%q\n' "$PID" "$SERIAL" "$AVD" > "$STATE_FILE"
    ;;
  stop)
    stop_owned
    ;;
  cleanup)
    stop_owned
    ;;
  *)
    echo "uso: e2e-emulator.sh start|stop|cleanup" >&2
    exit 1
    ;;
esac
