function [bestP, bestU, cache, stats] = local_search(P0, cfg, cache, stats)
%LOCAL_SEARCH 有预算的八方向模式搜索；只保证获得局部数值改进。
cur = P0(:);
cfg.kill_threshold = inf;
[res, cache, stats] = cached_eval(cur, cfg, cache, stats);
bestU = res.U;
step = cfg.ls_step0;
dirs = [1 0; -1 0; 0 1; 0 -1; 1 1; 1 -1; -1 1; -1 -1]';
for iter = 1:cfg.ls_max_iter
    if step < cfg.ls_step_min || stats.n_eval_calls >= cfg.max_eval_calls, break; end
    improved = false;
    for j = 1:size(dirs, 2)
        if stats.n_eval_calls >= cfg.max_eval_calls, break; end
        pt = cur+step*dirs(:, j);
        if ~in_E(pt, cfg), continue; end
        cfg.kill_threshold = bestU+cfg.tau_m;
        [r, cache, stats] = cached_eval(pt, cfg, cache, stats);
        if r.U < bestU-0.01
            cur = pt; bestU = r.U; improved = true; break;
        end
    end
    if ~improved, step = step*cfg.ls_shrink; end
end
bestP = cur;
end
