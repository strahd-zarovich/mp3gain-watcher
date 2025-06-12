#!/bin/bash

LOG_FILE="/appdata/mp3gain.log"
MUSIC_DIR="/music"

echo "========================================" >> "$LOG_FILE"
echo "[$(date)] Starting mp3gain docker script" >> "$LOG_FILE"
echo "Mode: ${MODE:-scan}" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Wait for the music directory to be available
if [ ! -d "$MUSIC_DIR" ]; then
    echo "[$(date)] ERROR: Music directory not found at $MUSIC_DIR" >> "$LOG_FILE"
    exit 1
fi

# Perform action based on MODE
case "$MODE" in
  undo)
    echo "[$(date)] Running UNDO (reverse gain adjustments)" >> "$LOG_FILE"
    find "$MUSIC_DIR" -type f -iname "*.mp3" -print0 | while IFS= read -r -d '' file; do
        echo "[$(date)] Undoing gain on: $file" >> "$LOG_FILE"
        mp3gain -s s -u "$file" >> "$LOG_FILE" 2>&1
    done
    ;;
  *)
    echo "[$(date)] Running NORMAL SCAN (applying ReplayGain)" >> "$LOG_FILE"
    find "$MUSIC_DIR" -type f -iname "*.mp3" -print0 | while IFS= read -r -d '' file; do
        echo "[$(date)] Processing: $file" >> "$LOG_FILE"
        mp3gain -s s -r -k "$file" >> "$LOG_FILE" 2>&1
    done
    ;;
esac

echo "[$(date)] Done." >> "$LOG_FILE"
