function [lo, hi, isfull] = theta_span_P(P, cfg)
%THETA_SPAN_P 可行读数集合 Θ(P) 的安全覆盖区间(未卷绕角度)
%   Θ(P) = ∪_{G∈D_ang(P)} [arg(G-P)-δ, arg(G-P)+δ] (圆周意义)
%   返回 [lo, hi] ⊇ Θ(P); isfull=true 表示覆盖整个圆周
%   标准情形论证:
%     P 在 D 内部 → D 从 P 看覆盖全部方向 → 全圆
%     P 在 D 外部 → 方向集合 {arg(G-P): G∈D} 是连续弧, 其端点必在 D 边界;
%       P∈E ⇒ ||P|| ≤ ~1005 < 1500, 故外圆(1500)无切点; 内圆(5)同理;
%       边界方向极值只可能在四角点 (r∈{5,1500}, s∈{±1}) 处取得
%   裁切情形(crop_enabled)不做精细推导, 保守返回全圆
d = cfg.delta;
if cfg.crop_enabled
    lo = 0; hi = 2*pi; isfull = true; return;
end
if abs(atan2(P(2), P(1))) <= d + 1e-9 && ...
   norm(P) <= cfg.Lmax && norm(P) >= cfg.r_inner - 1e-9
    lo = 0; hi = 2*pi; isfull = true; return;
end
corners = [cfg.r_inner*cos(d), cfg.Lmax*cos(d), cfg.Lmax*cos(d), cfg.r_inner*cos(d);
           cfg.r_inner*sin(d), cfg.Lmax*sin(d), -cfg.Lmax*sin(d), -cfg.r_inner*sin(d)];
phi  = atan2(corners(2, :) - P(2), corners(1, :) - P(1));
phi0 = atan2(-P(2), 750 - P(1));   % 参考方向: 指向 D 内部点 G0=(750,0) (P∉D 时 P≠G0)
u = wrapToPi(phi - phi0);
lo = phi0 + min(u) - d - deg2rad(0.05);   % 0.05° 数值安全余量
hi = phi0 + max(u) + d + deg2rad(0.05);
isfull = (hi - lo) >= 2*pi - 1e-9;
if isfull
    lo = 0; hi = 2*pi;
end
end
