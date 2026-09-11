#!/bin/bash
# 默认搜索；./run_problem2.sh verify 验证；./run_problem2.sh full 完整实验。
set -e
cd "$(dirname "$0")"
mode="${1:-run}"
case "$mode" in run|verify|full) ;; *) echo "用法: $0 [run|verify|full]"; exit 2;; esac
matlab_bin="${MATLAB_BIN:-/Applications/MATLAB_R2025a.app/bin/matlab}"
"$matlab_bin" -batch "main_problem2('$mode')"
