function [Pcand, bb] = generate_candidates(cfg)
%GENERATE_CANDIDATES 在候选域 E 内生成粗候选点
%   规则网格(cand_grid×cand_grid) + 均匀随机(cand_random) + 参考点(750,600)
%   全部满足 E 的四圆盘约束; 调用方需先 rng(cfg.seed) 保证可重复
[~, bb] = E_polygon(cfg);
nx = cfg.cand_grid;
xs = linspace(bb(1) + 2, bb(2) - 2, nx);
ys = linspace(bb(3) + 2, bb(4) - 2, nx);
[X, Y] = meshgrid(xs, ys);
P = [X(:)'; Y(:)'];
P = P(:, in_E(P, cfg));
nrand = cfg.cand_random;
acc = zeros(2, nrand);
cnt = 0; tries = 0;
while cnt < nrand && tries < 100 * nrand
    q = [bb(1) + (bb(2) - bb(1)) * rand; bb(3) + (bb(4) - bb(3)) * rand];
    tries = tries + 1;
    if in_E(q, cfg)
        cnt = cnt + 1;
        acc(:, cnt) = q;
    end
end
P = [P, acc(:, 1:cnt)];
if in_E([750; 600], cfg)
    P = [P, [750; 600]];
end
P = unique(P', 'rows')';
Pcand = P;
end
