#!/bin/sh
# Keep engine selection, version checks and the game entry in tools/runtime.py.
set -eu

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' '启动失败：未找到 Python 3。请先安装 Python 3，并确保 python3 在 PATH 中。' >&2
    exit 127
fi

# Resolve this checkout, not the caller's working directory. Quote paths with spaces.
project_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
runtime="$project_dir/tools/runtime.py"
if [ ! -f "$runtime" ]; then
    printf '%s\n' "启动失败：找不到 $runtime，请完整克隆 qingfeng 仓库。" >&2
    exit 2
fi

# All entrypoints use the same pinned engine/runtime selection. No implicit install,
# no destructive save reset, and no heavy testing just to open the game.
case "${1:-}" in
    --test)
        shift
        set -- phase0 "$@"
        ;;
    --test-all)
        shift
        set -- test "$@"
        ;;
    --editor)
        shift
        set -- editor "$@"
        ;;
    --capture)
        shift
        if [ "$#" -ne 1 ]; then
            printf '%s\n' '用法: ./run_game.sh --capture /输出目录' >&2
            exit 2
        fi
        set -- capture --capture-dir "$1"
        ;;
    --help|-h)
        set -- --help
        ;;
    *)
        set -- run "$@"
        ;;
esac

# Preserve argument boundaries and the original runner exit status.
exec python3 "$runtime" "$@"
