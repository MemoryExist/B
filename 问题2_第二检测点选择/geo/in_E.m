function ok = in_E(P, cfg)
%IN_E 保守安全候选域 E 可行性检查(4 个圆盘约束)
%   E = ∩ {(x - r cosδ)^2 + (y - s r sinδ)^2 <= R0^2}, r∈{r_inner,Lmax}, s∈{±1}
%   标准完整扇区下 E 的精确刻画; 目标圆域裁切 D 后该 E 仍为安全子区域
%   输入 P: 2×n; 输出 ok: 1×n logical
cent = e_centers_local(cfg);
ok = true(1, size(P, 2));
for k = 1:4
    ok = ok & (sum((P - cent(:, k)).^2, 1) <= cfg.R0^2 + 1e-9);
end
end

function cent = e_centers_local(cfg)
d = cfg.delta;
cent = [cfg.r_inner*cos(d), cfg.r_inner*cos(d), cfg.Lmax*cos(d), cfg.Lmax*cos(d);
        cfg.r_inner*sin(d), -cfg.r_inner*sin(d), cfg.Lmax*sin(d), -cfg.Lmax*sin(d)];
end
