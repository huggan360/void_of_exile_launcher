#!/usr/bin/env bash
# Export the launcher and zip it per platform into build/.
#   ./build.sh [godot] [Linux Windows macOS]
# Platforms whose export templates aren't installed are skipped with a note.
set -Eeuo pipefail
cd "$(dirname "$0")"
GODOT="${1:-${GODOT:-godot}}"
shift || true
PLATFORMS=("${@:-Linux Windows macOS}")
read -r -a PLATFORMS <<<"${PLATFORMS[*]}"
rm -rf build && mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for p in "${PLATFORMS[@]}"; do
    dir="build/$(tr '[:upper:]' '[:lower:]' <<<"$p")"
    mkdir -p "$dir"
    target="$(sed -n "/^name=\"$p\"/,/^export_path/{s/^export_path=\"\(.*\)\"/\1/p}" export_presets.cfg)"
    if ! "$GODOT" --headless --path . --export-release "$p" "$target" >"$dir.log" 2>&1 || [[ ! -s "$target" ]]; then
        echo "skipped $p (see $dir.log)"; continue
    fi
    zip="build/VoidOfExileLauncher-$p.zip"
    if [[ "$p" == macOS ]]; then
        mv "$target" "$zip"
    else
        (cd "$dir" && chmod +x VoidOfExileLauncher* && if command -v zip >/dev/null; then zip -q -9 "../$(basename "$zip")" VoidOfExileLauncher*
            else python3 -m zipfile -c "../$(basename "$zip")" VoidOfExileLauncher*; fi)
    fi
    echo "built $zip ($(du -h "$zip" | cut -f1))"
done
