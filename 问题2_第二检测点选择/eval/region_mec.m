function r = region_mec(P, beta, half, mode, cfg)
%REGION_MEC 定位区域 J(P,β;half) 的内/外多边形近似的覆盖圆半径(最小包围圆)
%   多边形顶点集的最小包围圆 = 区域(凸片并)的最小包围圆, 见 build_J_region 注释
%   mode: 'outer'(超集→上界) | 'inner'(子集→下界); 空区域返回 0
[polys, ~] = build_J_region(P, beta, half, mode, cfg);
V = zeros(2, 0);
for q = 1:numel(polys)
    V = [V, polys{q}]; %#ok<AGROW>
end
if isempty(V)
    r = 0;
    return;
end
[~, r] = welzl_mec(V, cfg);
end
