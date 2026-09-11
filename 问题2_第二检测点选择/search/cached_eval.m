function [res, cache, stats] = cached_eval(P, cfg, cache, stats)
%CACHED_EVAL 缓存只在同一几何配置内使用；淘汰阈值放宽后允许继续评价。
key = point_key(P);
hit = isKey(cache, key);
if hit
    stats.n_cache_hits = stats.n_cache_hits+1;
    old = cache(key);
    if old.U-old.L <= cfg.eval_tol
        old.status = 'converged';
    elseif old.L > cfg.kill_threshold
        old.status = 'pruned';
    elseif old.neval+3 > cfg.eval_budget
        old.status = 'budget';
    else
        old = [];
    end
    if ~isempty(old)
        res = old; res.cache_hit = true; cache(key) = res; return;
    end
    old = cache(key);
    res = eval_P_bounds(P, cfg, old.state);
else
    res = eval_P_bounds(P, cfg);
end
res.cache_hit = hit;
cache(key) = res;
stats.n_eval_calls = stats.n_eval_calls+1;
switch res.status
    case 'pruned', stats.n_pruned = stats.n_pruned+1;
    case 'converged', stats.n_converged = stats.n_converged+1;
    case 'budget', stats.n_budget = stats.n_budget+1;
end
end
