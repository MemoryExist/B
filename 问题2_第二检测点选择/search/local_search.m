function [bestP, bestU, cache, stats] = local_search(P0, cfg, cache, stats)
%LOCAL_SEARCH 二维坐标方向模式搜索(无导数), 约束在 E 内
%   不假设 f1 关于 P 凸; 8 方向尝试, 改进即重扫全部方向, 否则步长减半;
%   试验点先查缓存; 评价时用 kill 阈值(当前最好 U + tau_kill)提前淘汰明显更差的点
cur = P0;
cfg.kill_threshold = inf;
[res, cache, stats] = cached_eval(cur, cfg, cache, stats);
Ub = res.U;
step = cfg.ls_step0;
iter = 0;
dirs = [1 0; -1 0; 0 1; 0 -1; 1 1; 1 -1; -1 1; -1 -1];
while step >= cfg.ls_step_min && iter < cfg.ls_max_iter
    improved = false;
    j = 1;
    while j <= 8
        pt = cur + step * dirs(j, :)';
        j = j + 1;
        if ~in_E(pt, cfg)
            continue;
        end
        cfg.kill_threshold = Ub + cfg.tau_kill;
        [res, cache, stats] = cached_eval(pt, cfg, cache, stats);
        if ~strcmp(res.status, 'pruned') && res.U < Ub - 0.01
            cur = pt;
            Ub = res.U;
            improved = true;
            j = 1;               % 重新扫描全部方向
        end
    end
    if ~improved
        step = step * cfg.ls_shrink;
    end
    iter = iter + 1;
end
bestP = cur;
bestU = Ub;
end
