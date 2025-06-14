#!/bin/bash
set -euo pipefail

# Environment defaults
MODE="${MP3GAIN_MODE:-initial}"
MUSIC_DIR="${MUSIC_DIR:-/music}"
LOG_DIR="${LOG_DIR:-/appdata}"
LOG_DATE=$(date +"%Y-%m-%d")
MP3GAIN_ERROR_LOG="$LOG_DIR/mp3gain_error.log"
MP3GAIN_LOGFILE="$LOG_DIR/mp3gain_$LOG_DATE.log"
DRY_RUN="${DRY_RUN:-false}"
GAIN_MODE="${GAIN_MODE:-track}"
SCAN_INTERVAL="${SCAN_INTERVAL:-}"
TZ="${TZ:-America/New_York}"
export TZ

# Force default if MUSIC_DIR is empty or unset
if [[ -z "$MUSIC_DIR" ]]; then
  MUSIC_DIR="/music"
fi

# Route only actual errors to the error log
log() {
  echo "[$(date)] $*" | tee -a "$MP3GAIN_LOGFILE"
}
log_error() {
  echo "[$(date)] $*" | tee -a "$MP3GAIN_ERROR_LOG" >&2
}

mkdir -p "$LOG_DIR"
chown -R "${PUID:-99}":"${PGID:-100}" "$LOG_DIR"

log "Container started successfully. Mode: $MODE"

# Rotate logs: Keep only the latest 5
LOG_PATTERN="mp3gain_*.log"
LOG_COUNT=$(ls -1t "$LOG_DIR"/$LOG_PATTERN 2>/dev/null | wc -l)
if [ "$LOG_COUNT" -gt 5 ]; then
  echo "[$(date)] Cleaning up old logs..."
  ls -1t "$LOG_DIR"/$LOG_PATTERN | tail -n +6 | xargs -r rm -f
fi

echo "[$(date)] mp3gain-watcher starting in '$MODE' mode"
echo "[$(date)] Timezone: $TZ | DRY_RUN=$DRY_RUN | GAIN_MODE=$GAIN_MODE"

run_mp3gain() {
  local file="$1"
  if [ "$MODE" = "undo" ]; then
    echo "[$(date)] Undoing normalization (mp3gain will report deletions): $file"
    if [ "$DRY_RUN" != "true" ]; then
      mp3gain -s d "$file" > /dev/null
    fi
  else
    echo "[$(date)] Normalizing: $file"
    if [ "$DRY_RUN" != "true" ]; then
      if [ "$GAIN_MODE" = "album" ]; then
        mp3gain -a "$file" > /dev/null
      else
        mp3gain -r "$file" > /dev/null
      fi
    fi
  fi
}

process_directory() {
  log "Scanning directory: $MUSIC_DIR"

  mapfile -t files < <(find "$MUSIC_DIR" -type f -iname '*.mp3')
  log "Found ${#files[@]} MP3 files."

  if [[ ${#files[@]} -eq 0 ]]; then
    log_error "No MP3 files found in $MUSIC_DIR."
  else
    for file in "${files[@]}"; do
      log "Running mp3gain on: $file"
      run_mp3gain "$file" || log_error "mp3gain failed on: $file"
    done
  fi

  log "Done."
}

# Run selected mode
case "$MODE" in
  initial)
    process_directory
    ;;
  watch)
    echo "[$(date)] Watching for new files in $MUSIC_DIR..."
    inotifywait -m -r -e close_write,moved_to,create --format '%w%f' "$MUSIC_DIR" | while read -r file; do
      [[ "$file" == *.mp3 ]] && run_mp3gain "$file" || echo "[$(date)] mp3gain failed on: $file" >> "$MP3GAIN_ERROR_LOG"
    done
    ;;
  undo)
    process_directory
    ;;
  *)
    echo "[$(date)] Invalid mode specified: $MODE" | tee -a "$MP3GAIN_ERROR_LOG" >&2
    exit 1
    ;;
esac

log "Undo complete. Sleeping indefinitely to keep container alive."
tail -f /dev/null