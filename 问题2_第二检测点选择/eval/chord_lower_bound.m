function ell = chord_lower_bound(P, cfg)
%CHORD_LOWER_BOUND 理论下界: 对任意 P∈E, f1(P) ≥ r* = Lmax·sinδ/(1+sinδ) ≈ 25.73 米
%   证明要点(标准完整扇区): 扇区内部包含圆盘 C = (Lmax/(1+sinδ), 0), 半径 r*;
%   该圆盘与两条扇区边界线及外弧均相切, 故 C 圆盘 ⊂ D。
%   由于 E ⊂ { ||P-(5cosδ,0)|| ≤ R0 } ⇒ ||P|| ≤ R0+5 < Lmax/(1+sinδ) - r*,
%   故 P 必在 C 圆盘之外。取实际读数 β 指向 C: 射线 P→C 穿过圆盘一条完整直径
%   (长度 2r* ≈ 51.46 米), 直径上所有点具有相同真实方向且全部属于 D,
%   因此该定位区域包含这条直径 → f1(P) ≥ r*。
%   这是对所有 P∈E 成立的理论下界, 不是可达到的最优精度。
rs=cfg.Lmax*sin(cfg.delta)/(1+sin(cfg.delta));
C=[cfg.Lmax/(1+sin(cfg.delta));0];
if ~in_E(P,cfg) || norm(P(:)-C)<=rs+cfg.r_inner || ...
        norm(C)-rs<=cfg.r_inner || ...
        (cfg.crop_enabled && norm(C-cfg.crop_center(:))+rs>cfg.crop_radius)
    ell = 0;
    return;
end
ell=rs;
end
