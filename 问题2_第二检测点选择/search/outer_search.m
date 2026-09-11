function out = outer_search(cfg)
%OUTER_SEARCH 近似排序、必要条件淘汰、局部改进、少量候选精评。
% 未精评点的略过属于启发式筛选；不据此证明全局最优或恢复连续可行域。
t0 = tic;
rng(cfg.seed);
cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
stats = struct('n_eval_calls', 0, 'n_cache_hits', 0, 'n_pruned', 0, ...
    'n_converged', 0, 'n_budget', 0, 'n_pair_pruned', 0);
[~, cfg.witness] = D_region(cfg);
[Pcand, bb] = generate_candidates(cfg);
n = size(Pcand, 2);
assert(n > 0, 'E 内没有生成候选点，请检查参数。');
hat = zeros(1, n); ell = hat;
for i = 1:n
    hat(i) = hat_f1(Pcand(:, i), cfg);
    ell(i) = pair_lower_bound(Pcand(:, i), cfg.witness, cfg);
end
[~, ord] = sort(hat);
P_hat = Pcand(:, ord(1));
chosen = ord(1:min(cfg.n_hat_top, n));
while numel(chosen) < min(n, cfg.n_hat_top+cfg.n_diverse)
    dmin = inf(1, n);
    for j = chosen
        dmin = min(dmin, sum((Pcand-Pcand(:, j)).^2, 1));
    end
    dmin(chosen) = -inf;
    [~, j] = max(dmin);
    chosen(end+1) = j; %#ok<AGROW>
end
statuses = repmat({'not_evaluated'}, 1, n);
cfg.eval_tol = cfg.tol_coarse;
cfg.eval_budget = cfg.budget_coarse;
U_best = inf;
say(cfg, '候选 %d 点，选择 %d 点粗评。\n', n, numel(chosen));
for i = 1:numel(chosen)
    if stats.n_eval_calls >= cfg.max_eval_calls, break; end
    k = chosen(i);
    if ell(k) > U_best+cfg.tau_m
        stats.n_pair_pruned = stats.n_pair_pruned+1;
        statuses{k} = 'pair_pruned'; continue;
    end
    cfg.kill_threshold = U_best+cfg.tau_m;
    [r, cache, stats] = cached_eval(Pcand(:, k), cfg, cache, stats);
    U_best = min(U_best, r.U);
    say(cfg, '粗评 %2d/%2d  (%.1f, %.1f)  [%.3f, %.3f]  %s\n', ...
        i, numel(chosen), r.P, r.L, r.U, r.status);
end
starts = pick_starts(cache, cfg.n_search_starts, cfg.start_min_sep);
for s = 1:numel(starts)
    if stats.n_eval_calls >= cfg.max_eval_calls, break; end
    [~, u, cache, stats] = local_search(starts{s}, cfg, cache, stats);
    U_best = min(U_best, u);
    say(cfg, '局部搜索 %d/%d：目前最小上界 %.3f m。\n', s, numel(starts), U_best);
end
% 精评池由较小下界圈定；同时保留低上界和短距离点，控制精评总量。
rr = values(cache);
low = cellfun(@(r) r.L, rr);
upper = cellfun(@(r) r.U, rr);
dist = cellfun(@(r) norm(r.P), rr);
pool = find(low <= U_best+cfg.fine_pool);
[~, orderU] = sort(upper(pool));
[~, orderD] = sort(dist(pool));
nk = min(cfg.fine_max_points, numel(pool));
half = max(1, ceil(nk/2));
select = pool(orderU(1:min(half, numel(pool))));
% 先精评低上界点，再用更新后的阈值筛选短距离点，避免把预算用在宽区间上。
primary = cellfun(@(r) r.P, rr(select), 'UniformOutput', false);
primary = unique([P_hat, primary{:}]', 'rows', 'stable')';
secondary = cellfun(@(r) r.P, rr(pool(orderD)), 'UniformOutput', false);
points = unique([primary, secondary{:}]', 'rows', 'stable')';
cfg.eval_tol = cfg.tol_fine;
cfg.eval_budget = cfg.budget_fine;
cfg.kill_threshold = inf;
fines = struct([]); fine_best = inf;
for i = 1:size(points, 2)
    if numel(fines) >= cfg.fine_max_points, break; end
    old = cache(point_key(points(:,i)));
    if i > size(primary,2) && old.L > fine_best+cfg.tau_m, continue; end
    [r, cache, stats] = cached_eval(points(:, i), cfg, cache, stats);
    fine_best = min(fine_best,r.U);
    f = struct('P', r.P, 'L', r.L, 'U', r.U, 'gap', r.U-r.L, ...
        'neval', r.neval, 'status', r.status, 'worst_beta', r.worst_beta, ...
        'worst_beta_deg', mod(rad2deg(r.worst_beta), 360), 'dist', norm(r.P));
    if isempty(fines), fines = f; else, fines(end+1) = f; end %#ok<AGROW>
    say(cfg, '精评 %2d/%2d  (%.1f, %.1f)  [%.3f, %.3f]  %s\n', ...
        numel(fines), cfg.fine_max_points, r.P, r.L, r.U, r.status);
end
good = strcmp({fines.status}, 'converged');
assert(any(good), '精评全部未收敛，请增加 budget_fine 或放宽 tol_fine。');
idx = find(good);
[m_hat, k] = min([fines(idx).U]); bi = idx(k);
idxF = find(good & [fines.U] <= m_hat+cfg.tau_m);
[~, k] = min([fines(idxF).dist]); fi = idxF(k);
% CSV 取缓存最新结果，包含已续算的粗候选。
Ls = nan(1, n); Us = Ls; nevals = zeros(1, n); ts = nevals;
for i = 1:n
    key = point_key(Pcand(:, i));
    if ~isKey(cache, key), continue; end
    r = cache(key);
    Ls(i) = r.L; Us(i) = r.U; nevals(i) = r.neval; ts(i) = r.t;
    statuses{i} = r.status;
end
T = table(Pcand(1,:)', Pcand(2,:)', hat', ell', Ls', Us', statuses', ...
    nevals', ts', vecnorm(Pcand)', 'VariableNames', ...
    {'x','y','hat','ell_pair','L','U','status','neval','time_s','dist'});
if cfg.export_csv
    if ~isfolder(cfg.results_dir), mkdir(cfg.results_dir); end
    writetable(T, fullfile(cfg.results_dir, 'candidates.csv'));
end
out = struct('Pcand', Pcand, 'bb', bb, 'hat', hat, 'ell', ell, 'eval_list', chosen, ...
    'Ls', Ls, 'Us', Us, 'cache', cache, 'stats', stats, 'U_best', m_hat, ...
    'm_hat', m_hat, 'P_best', fines(bi).P, 'f1_best_L', fines(bi).L, ...
    'f1_best_U', fines(bi).U, 'f1_best_gap', fines(bi).gap, ...
    'f1_best_status', fines(bi).status, 'worst_beta_best', fines(bi).worst_beta_deg, ...
    'P_f2', fines(fi).P, 'f2_dist', fines(fi).dist, 'f2_time', fines(fi).dist/cfg.speed, ...
    'tau', cfg.tau_m, 'P_hat', P_hat, 'f1_hat_val', hat(ord(1)), ...
    'hat_res', cache(point_key(P_hat)), 'fines', fines, 'best_index', bi, ...
    'selected_index', fi, 'near_indices', idxF, 't_total', toc(t0));
out.statuses = statuses;
% 输出代表角度对应的外包圆，圆心可用于后续光学行动规划。
out.representative_beta = fines(fi).worst_beta;
if ~isfinite(out.representative_beta)
    [lo, hi] = theta_span_P(out.P_f2, cfg);
    out.representative_beta = (lo+hi)/2;
end
[out.representative_radius, out.representative_center] = ...
    region_mec(out.P_f2, out.representative_beta, cfg.delta, 'outer', cfg);
say(cfg, '最小精评上界 %.3f m，P=(%.2f, %.2f)。\n', m_hat, out.P_best);
say(cfg, '容许增加 %.1f m 后选 P=(%.2f, %.2f)，路程 %.2f m，时间 %.2f s。\n', ...
    cfg.tau_m, out.P_f2, out.f2_dist, out.f2_time);
say(cfg, '搜索耗时 %.2f s，评价调用 %d 次，缓存命中 %d 次。\n', ...
    out.t_total, stats.n_eval_calls, stats.n_cache_hits);
end

function say(cfg, varargin)
if cfg.verbose, fprintf(varargin{:}); end
end
