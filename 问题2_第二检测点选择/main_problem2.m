function [out, V, S] = main_problem2(mode)
%MAIN_PROBLEM2 默认仅搜索、绘图与导出；'verify' 单独验证，'full' 另做敏感性分析。
if nargin == 0, mode = 'run'; end
assert(any(strcmp(mode, {'run','verify','full'})), '模式应为 run、verify 或 full。');
root = fileparts(mfilename('fullpath'));
old = pwd; cleanup = onCleanup(@() cd(old));
cd(root); addpath(genpath(root));
cfg = config_problem2();
if ~isfolder(cfg.results_dir), mkdir(cfg.results_dir); end
if ~isfolder(cfg.fig_dir), mkdir(cfg.fig_dir); end
out = []; V = []; S = [];
t_all = tic;
fprintf('问题二：第二检测点选择 | MATLAB %s\n', version);
if any(strcmp(mode, {'verify','full'}))
    V = verify_problem2();
    assert(V.nfail == 0, '验证失败，请检查 results/verify_results.mat。');
    if strcmp(mode, 'verify'), return; end
end
out = outer_search(cfg);
if strcmp(mode, 'full'), S = sensitivity(out, cfg); end
plot_problem2(cfg, out);
out.t_run = toc(t_all);
export_problem2(out, cfg);
save(fullfile(cfg.results_dir, 'out.mat'), 'out', 'cfg', 'V', 'S', '-v7');
fprintf('完成：搜索 %.2f s，总计 %.2f s（均不含 MATLAB 启动）。\n', out.t_total, out.t_run);
fprintf('数值及论文数据：results/；图：figures/。\n');
end

