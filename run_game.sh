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

# Preserve arguments and exit status; never download, reinstall or cold-import here.
exec python3 "$runtime" run "$@"
