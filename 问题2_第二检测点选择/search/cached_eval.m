function [res, cache, stats] = cached_eval(P, cfg, cache, stats)
%CACHED_EVAL 带状态缓存的固定点评价
%   缓存键: 坐标毫米量化('%.3f,%.3f'); 本搜索中所有评价点互距 ≥ 1 米, 无碰撞
%   命中且已满足当前精度(或已淘汰/空) → 直接复用;
%   命中但精度不足 → 从缓存的角度箱状态继续细分(不重新计算);
%   未命中 → 全新计算并写入缓存。
key = sprintf('%.3f,%.3f', P(1), P(2));
if isKey(cache, key)
    st = cache(key);
    done = (st.U - st.L <= cfg.eval_tol + 1e-9) || ...
           strcmp(st.status, 'pruned') || strcmp(st.status, 'empty');
    if done
        res = st;
        res.cache_hit = true;
        stats.n_cache_hits = stats.n_cache_hits + 1;
        return;
    end
    res = eval_P_bounds(P, cfg, st.state);
    res.cache_hit = true;
    stats.n_cache_hits = stats.n_cache_hits + 1;
else
    res = eval_P_bounds(P, cfg, []);
    res.cache_hit = false;
end
cache(key) = res; %#ok<NASGU>
stats.n_eval_calls = stats.n_eval_calls + 1;
switch res.status
    case 'pruned',    stats.n_pruned    = stats.n_pruned + 1;
    case 'converged', stats.n_converged = stats.n_converged + 1;
    case 'budget',    stats.n_budget    = stats.n_budget + 1;
end
end
