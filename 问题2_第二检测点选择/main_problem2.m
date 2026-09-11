function main_problem2
%MAIN_PROBLEM2 一键运行: 验证 → 两阶段外层搜索 → 参数敏感性 → 绘图与导出
root = fileparts(mfilename('fullpath'));
cd(root);
addpath(genpath(root));
cfg = config_problem2();
mkdir(cfg.results_dir); mkdir(cfg.fig_dir);
fprintf('======================================================\n');
fprintf(' 国赛B题 问题2: 第二检测点选择 | MATLAB %s\n', version);
fprintf(' 开始时间: %s\n', char(datetime));
fprintf('======================================================\n');
t_all = tic;
fprintf('\n======== 阶段0: 验证套件 ========\n');
V = verify_problem2();
if V.nfail > 0
    error('验证失败 %d 项, 请检查失败项', V.nfail);
end
fprintf('\n======== 阶段1: 两阶段外层搜索 ========\n');
out = outer_search(cfg);
fprintf('\n======== 阶段2: 参数敏感性 ========\n');
S = sensitivity(out, cfg);
fprintf('\n======== 阶段3: 绘图与导出 ========\n');
plot_problem2(cfg, out, V);
save(fullfile(cfg.results_dir, 'out.mat'), 'out', 'V', 'S', 'cfg', '-v7');
summ = table();
summ.item = {'m_hat_m'; 'P_best_x'; 'P_best_y'; 'f1_best_L_m'; 'f1_best_U_m'; 'f1_best_gap_m'; ...
    'worst_beta_deg'; 'P_f2_x'; 'P_f2_y'; 'f2_dist_m'; 'f2_time_s'; 'tau_m'; ...
    'P_hat_x'; 'P_hat_y'; 'f1_hat_m'; 'hat_true_L'; 'hat_true_U'; ...
    'n_eval_calls'; 'n_cache_hits'; 'n_pruned'; 'n_pair_pruned'; 'n_converged'; 'n_budget'; ...
    't_search_s'; 't_total_s'};
summ.value = [out.m_hat; out.P_best(1); out.P_best(2); out.f1_best_L; out.f1_best_U; out.f1_best_gap; ...
    out.worst_beta_best; out.P_f2(1); out.P_f2(2); out.f2_dist; out.f2_time; out.tau; ...
    out.P_hat(1); out.P_hat(2); out.f1_hat_val; out.hat_res.L; out.hat_res.U; ...
    out.stats.n_eval_calls; out.stats.n_cache_hits; out.stats.n_pruned; out.stats.n_pair_pruned; ...
    out.stats.n_converged; out.stats.n_budget; out.t_total; toc(t_all)];
writetable(summ, fullfile(cfg.results_dir, 'final_summary.csv'));
fprintf('\n======================================================\n');
fprintf('全部完成, 总耗时 %.1f s\n', toc(t_all));
fprintf('结果: results/, 图: figures/, 说明: README.md\n');
end
