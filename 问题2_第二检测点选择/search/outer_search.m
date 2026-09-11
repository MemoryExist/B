function out = outer_search(cfg)
%OUTER_SEARCH 两阶段外层选点完整流程
%   A. 在 E 内生成粗候选点(规则网格+均匀随机, 不做全 E 密集精确扫描)
%   B. 显式近似指标 f1_hat 排序 + 多样化起点保留
%   C. 依次粗评(角度区间细分, 预算/提前淘汰), 建立当前最好上界 U_best
%   D. 点对下界 ell_pair 数学排除: ell_pair(P) > U_best + τ 的点安全淘汰
%   E. 从多个保留起点出发做带 E 约束的模式搜索(不假设凸)
%   F. 状态缓存: 相同点提高精度时继续细分, 不重新计算
%   G. 精评复核: U ≤ U_best + fine_pool 的点以 tol_fine 细化
%   输出数值最优参考 m_hat(上界口径), 分层选择: F_τ 内距离最短点, 及基线对比
t0 = tic;
rng(cfg.seed);
cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
stats = struct('n_eval_calls', 0, 'n_cache_hits', 0, 'n_pruned', 0, ...
               'n_converged', 0, 'n_budget', 0, 'n_pair_pruned', 0);
[~, W] = D_region(cfg);
cfg.witness = W;
[Pcand, bb] = generate_candidates(cfg);
n = size(Pcand, 2);
fprintf('候选点总数: %d (E 包围盒 [%.1f,%.1f]×[%.1f,%.1f])\n', n, bb);
hat = zeros(1, n);
ell = zeros(1, n);
for i = 1:n
    hat(i) = hat_f1(Pcand(:, i), cfg);
    ell(i) = pair_lower_bound(Pcand(:, i), W, cfg);
end
[~, ord] = sort(hat);
% 评估列表: 近似最好 n_hat_top + 多样化 n_diverse(贪婪最远点)
top = ord(1:min(cfg.n_hat_top, n));
chosen = top;
while numel(chosen) < cfg.n_hat_top + cfg.n_diverse
    dmin = inf(1, n);
    for j = 1:n
        if any(chosen == j)
            dmin(j) = -1; continue;
        end
        dd = sqrt(min(sum((Pcand(:, j) - Pcand(:, chosen)).^2, 1)));
        dmin(j) = dd;
    end
    [dv, jj] = max(dmin);
    if dv <= 0, break; end
    chosen(end+1) = jj; %#ok<AGROW>
end
eval_list = unique(chosen, 'stable');
% 逐候选状态记录
statuses = repmat({'not_evaluated'}, 1, n);
Ls = nan(1, n); Us = nan(1, n); nevals = zeros(1, n); ts = zeros(1, n);
% ---- C/D: 粗评(近似最优优先, 点对下界淘汰) ----
cfg.eval_tol = cfg.tol_coarse;
cfg.eval_budget = cfg.budget_coarse;
U_best = inf;
for i = 1:numel(eval_list)
    k = eval_list(i);
    P = Pcand(:, k);
    if ell(k) > U_best + cfg.tau_m
        stats.n_pair_pruned = stats.n_pair_pruned + 1;
        statuses{k} = 'pair_pruned';
        fprintf('粗评 %2d/%2d  P=(%7.2f,%7.2f)  hat=%8.2f  ell=%7.2f  → 点对下界排除(>U_best+τ)\n', ...
            i, numel(eval_list), P(1), P(2), hat(k), ell(k));
        continue;
    end
    cfg.kill_threshold = U_best + cfg.tau_kill;
    [res, cache, stats] = cached_eval(P, cfg, cache, stats);
    if res.U < U_best, U_best = res.U; end
    statuses{k} = res.status;
    Ls(k) = res.L; Us(k) = res.U; nevals(k) = res.neval; ts(k) = res.t;
    fprintf('粗评 %2d/%2d  P=(%7.2f,%7.2f)  hat=%8.2f  ell=%7.2f  [L,U]=[%6.2f,%6.2f]  n=%3d  %s\n', ...
        i, numel(eval_list), P(1), P(2), hat(k), ell(k), res.L, res.U, res.neval, res.status);
end
fprintf('粗评完成: U_best=%.3f m, 调用 %d, 缓存命中 %d, 淘汰 %d, 点对排除 %d\n', ...
    U_best, stats.n_eval_calls, stats.n_cache_hits, stats.n_pruned, stats.n_pair_pruned);
% ---- E: 局部搜索 ----
starts = pick_starts(cache, cfg.n_search_starts, cfg.start_min_sep);
fprintf('局部搜索起点数: %d\n', numel(starts));
for s = 1:numel(starts)
    [~, Ub_s, cache, stats] = local_search(starts{s}, cfg, cache, stats);
    fprintf('局部搜索 %d/%d 起点(%7.2f,%7.2f) → 终点最好 U=%7.3f\n', ...
        s, numel(starts), starts{s}(1), starts{s}(2), Ub_s);
end
% ---- G: 精评复核 ----
cfg.eval_tol = cfg.tol_fine;
cfg.eval_budget = cfg.budget_fine;
cfg.kill_threshold = inf;
keys = cache.keys;
fine_keys = {};
for i = 1:numel(keys)
    r = cache(keys{i});
    if r.U <= U_best + cfg.fine_pool
        fine_keys{end+1} = keys{i}; %#ok<AGROW>
    end
end
fines = struct('P', {}, 'L', {}, 'U', {}, 'Uw', {}, 'gap', {}, 'neval', {}, ...
               'status', {}, 'worst_beta', {}, 'worst_beta_deg', {}, 'dist', {}, 'center', {});
for i = 1:numel(fine_keys)
    P = cache(fine_keys{i}).P;
    [res, cache, stats] = cached_eval(P, cfg, cache, stats);
    k = numel(fines) + 1;
    fines(k).P = res.P;
    fines(k).L = res.L;
    fines(k).U = res.U;
    fines(k).Uw = res.Uw;
    fines(k).gap = res.U - res.L;
    fines(k).neval = res.neval;
    fines(k).status = res.status;
    fines(k).worst_beta = res.worst_beta;
    fines(k).worst_beta_deg = mod(rad2deg(res.worst_beta), 360);
    fines(k).dist = norm(res.P);
    fines(k).center = nan(2, 1);
    fprintf('精评 %2d/%2d  P=(%7.2f,%7.2f)  [L,U]=[%7.3f,%7.3f]  gap=%6.3f  worstβ=%.3f°  n=%3d  %s\n', ...
        i, numel(fine_keys), res.P(1), res.P(2), res.L, res.U, res.U - res.L, ...
        fines(k).worst_beta_deg, res.neval, res.status);
end
UsF = [fines.U];
[m_hat, bi] = min(UsF);
P_best = fines(bi).P;
% 分层选择: F_τ = { P∈已精评点 : U(P) ≤ m_hat + τ }, 其中取 ||P|| 最小
inF = UsF <= m_hat + cfg.tau_m;
idxF = find(inF);
dists = [fines.dist];
[~, fi] = min(dists(inF));
P_f2 = fines(idxF(fi)).P;
% 基线: 仅用近似指标的最佳点 P_hat
P_hat = Pcand(:, top(1));
[rhat, cache, stats] = cached_eval(P_hat, cfg, cache, stats);
% 对照: 仅粗候选真实评分(不搜索)的最好点 P_grid
best_grid_U = inf; best_grid_P = [nan; nan]; best_grid_L = nan;
for i = 1:n
    if isnan(Ls(i)), continue; end
    if Us(i) < best_grid_U
        best_grid_U = Us(i); best_grid_P = Pcand(:, i); best_grid_L = Ls(i);
    end
end
% 汇总候选表(全部候选点)
T = table();
T.x = Pcand(1, :)';
T.y = Pcand(2, :)';
T.hat = hat';
T.ell_pair = ell';
T.L = Ls';
T.U = Us';
T.status = statuses';
T.neval = nevals';
T.time_s = ts';
T.dist = sqrt(sum(Pcand.^2, 1))';
if cfg.export_csv
    writetable(T, fullfile(cfg.results_dir, 'candidates.csv'));
end
out = struct();
out.statuses = statuses;
out.Ls = Ls;
out.Us = Us;
out.Pcand = Pcand;
out.hat = hat;
out.ell = ell;
out.eval_list = eval_list;
out.bb = bb;
out.cache = cache;
out.stats = stats;
out.U_best = U_best;
out.m_hat = m_hat;
out.P_best = P_best;
out.f1_best_L = fines(bi).L;
out.f1_best_U = fines(bi).U;
out.f1_best_gap = fines(bi).gap;
out.f1_best_status = fines(bi).status;
out.worst_beta_best = fines(bi).worst_beta_deg;
out.P_f2 = P_f2;
out.f2_dist = norm(P_f2);
out.f2_time = norm(P_f2) / cfg.speed;
out.fines = fines;
out.tau = cfg.tau_m;
out.P_hat = P_hat;
out.f1_hat_val = min(hat);
out.hat_res = rhat;
out.P_grid = best_grid_P;
out.f1_grid_L = best_grid_L;
out.f1_grid_U = best_grid_U;
out.t_total = toc(t0);
fprintf('================ 两阶段搜索汇总 ================\n');
fprintf('数值最优参考 m_hat = %.3f m (P=(%.2f,%.2f), 上下界 [%.3f, %.3f], 状态 %s)\n', ...
    m_hat, P_best(1), P_best(2), out.f1_best_L, out.f1_best_U, out.f1_best_status);
fprintf('分层选择(τ=%.1f m): P=(%.2f,%.2f), 移动距离 %.2f m, 移动时间 %.2f s\n', ...
    cfg.tau_m, P_f2(1), P_f2(2), out.f2_dist, out.f2_time);
fprintf('基线(仅近似指标): P=(%.2f,%.2f), f1_hat=%.2f m, 真实 [%.3f, %.3f] (%s)\n', ...
    P_hat(1), P_hat(2), out.f1_hat_val, rhat.L, rhat.U, rhat.status);
fprintf('对照(仅粗候选真实评分, 不搜索): P=(%.2f,%.2f), [%.3f, %.3f]\n', ...
    best_grid_P(1), best_grid_P(2), best_grid_L, best_grid_U);
fprintf('统计: 评价调用 %d, 缓存命中 %d, 淘汰(提前) %d, 点对排除 %d, 收敛 %d, 预算 %d\n', ...
    stats.n_eval_calls, stats.n_cache_hits, stats.n_pruned, stats.n_pair_pruned, ...
    stats.n_converged, stats.n_budget);
fprintf('外层搜索总耗时 %.1f s\n', out.t_total);
end
