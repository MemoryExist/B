function [Eb, bb] = E_polygon(cfg)
%E_POLYGON 候选域 E 的边界采样点(4 个圆盘上满足全部约束的弧段)与包围盒
cent = e_centers_local(cfg);
Eb = zeros(2, 0);
th = linspace(0, 2*pi, 6000);
for k = 1:4
    pts = cent(:, k) + cfg.R0 * [cos(th); sin(th)];
    ok = in_E(pts, cfg);
    Eb = [Eb, pts(:, ok)]; %#ok<AGROW>
end
bb = [min(Eb(1, :)), max(Eb(1, :)), min(Eb(2, :)), max(Eb(2, :))];
end

function cent = e_centers_local(cfg)
d = cfg.delta;
cent = [cfg.r_inner*cos(d), cfg.r_inner*cos(d), cfg.Lmax*cos(d), cfg.Lmax*cos(d);
        cfg.r_inner*sin(d), -cfg.r_inner*sin(d), cfg.Lmax*sin(d), -cfg.Lmax*sin(d)];
end
