function ell = pair_lower_bound(P, W, cfg)
%PAIR_LOWER_BOUND 点对下界 ell_pair(P): 真实 f1(P) 的严格下界
%   见证点 W(2×nw) 全部属于真实 D。若两见证点 G_i,G_j 满足:
%     (a) ||G_i-P||>5 且 ||G_j-P||>5 (正常观测分支);
%     (b) 从 P 看两者圆周夹角 ≤ 2δ (点积判据, 避免 atan2);
%   则存在同一实际读数 β 与两者同时相容 → J(P,β) 同时包含两点
%     → f1(P) ≥ ||G_i-G_j||/2。
%   无符合条件的点对时下界取 0(不表示精度为 0)。
V = W - P;
d = sqrt(sum(V.^2, 1));
ok = d > cfg.r_inner;
ell = 0;
nw = size(W, 2);
coslim = cos(2 * cfg.delta);
for i = 1:nw-1
    if ~ok(i), continue; end
    for j = i+1:nw
        if ~ok(j), continue; end
        if V(:, i)' * V(:, j) >= coslim * d(i) * d(j) - 1e-12
            ell = max(ell, norm(W(:, i) - W(:, j)) / 2);
        end
    end
end
end
