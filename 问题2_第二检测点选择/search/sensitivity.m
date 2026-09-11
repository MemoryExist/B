function S = sensitivity(out, cfg)
%SENSITIVITY 参数敏感性: τ 扫描 / 精评精度扫描 / 候选数量扫描(小预算)
S = struct();
% (1) 精度让步 τ ∈ {0,1,3}: F_τ = { 已精评点 : U ≤ m_hat+τ } 内取距离最短
taus = [0 1 3];
Us = [out.fines.U];
dists = [out.fines.dist];
for i = 1:numel(taus)
    inF = Us <= out.m_hat + taus(i);
    idx = find(inF);
    [~, fi] = min(dists(inF));
    P = out.fines(idx(fi)).P;
    S.tau(i) = struct('tau', taus(i), 'P', P, 'dist', norm(P), ...
        'time', norm(P) / cfg.speed, 'n_inF', numel(idx));
    fprintf('τ=%.1f m: F_τ 内 %2d 个已精评点, 最短距离 P=(%.2f,%.2f) 距离 %.2f m 时间 %.2f s\n', ...
        taus(i), numel(idx), P(1), P(2), norm(P), norm(P) / cfg.speed);
end
% (2) 精评精度 tol ∈ {0.5, 0.1, 0.05}: 对 P_best 从缓存状态继续细分
tols = [0.5 0.1 0.05];
cache = out.cache;
statsS = struct('n_eval_calls', 0, 'n_cache_hits', 0, 'n_pruned', 0, ...
    'n_converged', 0, 'n_budget', 0);
[~, W] = D_region(cfg);
for i = 1:numel(tols)
    cgi = cfg;
    cgi.eval_tol = tols(i); cgi.eval_budget = 1200; cgi.kill_threshold = inf;
    cgi.witness = W;
    [ri, cache, statsS] = cached_eval(out.P_best, cgi, cache, statsS); %#ok<ASGLU>
    S.tol(i) = struct('tol', tols(i), 'L', ri.L, 'U', ri.U, 'gap', ri.U - ri.L, ...
        'neval', ri.neval, 'status', ri.status);
    fprintf('精评精度 tol=%.2f: [L,U]=[%.4f,%.4f] gap=%.4f n=%d %s\n', ...
        tols(i), ri.L, ri.U, ri.U - ri.L, ri.neval, ri.status);
end
% (3) 候选数量: cand_random ∈ {40, 320}(网格固定 20×20), 1 个搜索起点
nrand = [40 320];
for i = 1:2
    cgi = cfg;
    cgi.cand_random = nrand(i);
    cgi.n_search_starts = 1;
    cgi.export_csv = false;
    oi = outer_search(cgi);
    S.cand(i) = struct('n_cand', size(oi.Pcand, 2), 'm_hat', oi.m_hat, ...
        'P_best', oi.P_best, 'f1_best_L', oi.f1_best_L, 'f1_best_U', oi.f1_best_U, ...
        't_total', oi.t_total, 'stats', oi.stats);
end
% 导出 CSV
T = table();
T.tau = [S.tau.tau]';
T.tau_Px = arrayfun(@(s) s.P(1), S.tau)';
T.tau_Py = arrayfun(@(s) s.P(2), S.tau)';
T.tau_dist = [S.tau.dist]';
T.tau_time = [S.tau.time]';
T.tau_nF = [S.tau.n_inF]';
T.tol = [S.tol.tol]';
T.tol_L = [S.tol.L]';
T.tol_U = [S.tol.U]';
T.tol_gap = [S.tol.gap]';
T.tol_neval = [S.tol.neval]';
writetable(T, fullfile(cfg.results_dir, 'sensitivity.csv'));
end
