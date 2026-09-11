#!/bin/bash
# 运行问题二完整流程(验证 → 搜索 → 敏感性 → 绘图导出)
# 依赖: 基础 MATLAB(无工具箱要求), 本机路径 /Applications/MATLAB_R2025a.app
cd "$(dirname "$0")"
/Applications/MATLAB_R2025a.app/bin/matlab -batch "main_problem2"
