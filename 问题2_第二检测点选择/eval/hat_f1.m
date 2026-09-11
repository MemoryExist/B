function f = hat_f1(P, cfg)
%HAT_F1 一阶端点近似指标 f1_hat(P) = max{ ρ_hat(r_inner;P), ρ_hat(Lmax;P) }
%   ρ_hat(r;x,y) = δ·sqrt( r² + [((r-x)²+y²+r|r-x|)² / y²] ), y≠0
%   模型: 参考源 G=(r,0) 在第一次示向度中心射线上, 小角度线性化,
%         未做真实边界裁剪; 关于 r≥0 数值验证为凸(见 verify_problem2),
%         故端点 r∈{5,1500} 取最大。
%   用途: 仅用于候选排序与产生起点, 不是真实 f1 的上/下界, 不能作为
%         排除候选点的必要条件; y≈0 的奇异性置 1e9(排名最末)
d = cfg.delta;
x = P(1); y = P(2);
if abs(y) < 1e-6
    f = 1e9; return;
end
rho = @(r) d * sqrt(r^2 + (((r - x)^2 + y^2 + r * abs(r - x))^2) / y^2);
f = max(rho(cfg.r_inner), rho(cfg.Lmax));
end
