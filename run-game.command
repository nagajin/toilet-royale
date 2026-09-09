#!/bin/sh
# Double-click on macOS, or run ./run-game.command from a terminal.
TOILET_GAME_DIR="$(cd "$(dirname "$0")" && pwd)/game"
if command -v godot >/dev/null 2>&1; then
    TOILET_GODOT="$(command -v godot)"
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    TOILET_GODOT=/Applications/Godot.app/Contents/MacOS/Godot
else
    printf '%s\n' 'Godot 4 をインストールしてから，もう一度起動してください．'
    exit 1
fi
# Refresh class_name registrations after a fresh checkout or script additions.
mkdir -p "$TOILET_GAME_DIR/.godot"
"$TOILET_GODOT" --headless --path "$TOILET_GAME_DIR" --editor --import --quit \
    --log-file "$TOILET_GAME_DIR/.godot/launcher-import.log" >/dev/null || exit $?
exec "$TOILET_GODOT" --path "$TOILET_GAME_DIR" "$@"
