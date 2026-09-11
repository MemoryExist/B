function [c, r] = welzl_mec(P, cfg)
%WELZL_MEC 增量支撑集最小包围圆（沿用文件名，不声称 Welzl 的线性复杂度）
%   输入 P: 2×n 点列; cfg.mec_tol / cfg.mec_tol_rel: 数值容差
%   输出 [c, r]: 圆心(2×1)与半径; 空集返回 r=0, c=NaN
%   调用前由外部 rng 固定种子保证可重复; 支持单点/两点/共线/重复/近共线点
P=unique(P','rows')';
n = size(P, 2);
if n == 0
    c = [nan; nan]; r = 0; return;
end
tol  = cfg.mec_tol;
rtol = cfg.mec_tol_rel;
if n == 1
    c = P(:, 1); r = 0; return;
end
Q = P(:, randperm(n));
b = zeros(2, 3); m = 0;          % 边界支撑点(不超过 3 个)
[c, r] = trivial_mec(b(:, 1:m));
k = 1;
while k <= n
    if norm(Q(:, k) - c) <= r * (1 + rtol) + tol
        k = k + 1;
        continue;
    end
    if m < 3
        m = m + 1;
        b(:, m) = Q(:, k);
        [c, r] = trivial_mec(b(:, 1:m));
    else
        % 3 个支撑点已满: 求 {b, 新点} 4 点的最小包围圆并退回 ≤3 支撑点
        [c, r, b] = mec_of_4(b, Q(:, k));
        m = size(b, 2);
    end
    k = 1;                          % 换圆后从头复查
end
if r < 0
    c = [nan; nan]; r = 0;
end
end

function [c, r] = trivial_mec(b)
% 0/1/2/3 点平凡情形: 3 点钝角/直角→最长边直径; 锐角→外接圆; 近共线→最长边直径
m = size(b, 2);
if m == 0, c = [0; 0]; r = -1; return; end
if m == 1, c = b(:, 1); r = 0; return; end
if m == 2
    c = (b(:, 1) + b(:, 2)) / 2;
    r = norm(b(:, 1) - b(:, 2)) / 2;
    return;
end
d12 = norm(b(:, 1) - b(:, 2));
d13 = norm(b(:, 1) - b(:, 3));
d23 = norm(b(:, 2) - b(:, 3));
if d12 >= d13 && d12 >= d23
    if d12^2 >= (d13^2 + d23^2) * (1 + 1e-12)
        c = (b(:, 1) + b(:, 2)) / 2; r = d12 / 2; return;
    end
elseif d13 >= d12 && d13 >= d23
    if d13^2 >= (d12^2 + d23^2) * (1 + 1e-12)
        c = (b(:, 1) + b(:, 3)) / 2; r = d13 / 2; return;
    end
else
    if d23^2 >= (d12^2 + d13^2) * (1 + 1e-12)
        c = (b(:, 2) + b(:, 3)) / 2; r = d23 / 2; return;
    end
end
A = [2*(b(:, 2) - b(:, 1))'; 2*(b(:, 3) - b(:, 1))'];
rhs = [sum(b(:, 2).^2) - sum(b(:, 1).^2); sum(b(:, 3).^2) - sum(b(:, 1).^2)];
if abs(det(A)) < 1e-12 * (norm(b(:, 2) - b(:, 1)) * norm(b(:, 3) - b(:, 1)))
    % 近共线退化: 取最长边直径
    [dm, i1] = max([d12, d13, d23]);
    if i1 == 1, c = (b(:, 1) + b(:, 2)) / 2;
    elseif i1 == 2, c = (b(:, 1) + b(:, 3)) / 2;
    else, c = (b(:, 2) + b(:, 3)) / 2;
    end
    r = dm / 2; return;
end
c = A \ rhs;
r = norm(b(:, 1) - c);
end

function [c, r, b] = mec_of_4(b3, p)
% 4 点(3 个旧支撑点 + 1 个新外部点)的最小包围圆, 并返回圆上的 ≤3 个支撑点
P4 = [b3, p];
best_r = inf;
c = [nan; nan]; b = zeros(2, 0);
for s = 1:3
    comb = nchoosek(1:4, s);
    for t = 1:size(comb, 1)
        sub = P4(:, comb(t, :));
        [cc, rr] = trivial_mec(sub);
        dd = sqrt(sum((P4 - cc).^2, 1));
        if all(dd <= rr * (1 + 1e-12) + 1e-9) && rr < best_r
            best_r = rr; c = cc; b = sub;
        end
    end
end
r = best_r;
end
