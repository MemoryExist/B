function [polys, flags] = build_J_region(P, beta, half, mode, cfg)
%BUILD_J_REGION 构造定位区域 J(P, β; half) 的内/外多边形近似
%   J = D ∩ W(P;β,half), 其中 D = {u>=0, |v|<=u·tanδ, 5<||G||<=1500}(可选再与目标圆相交)
%   mode='outer': 外近似(超集, 供上界): 扇区+楔形半平面精确, 圆弧用外切正多边形,
%                 并减去近源孔的内接多边形(半径略小于 5, 保证仍为超集)
%   mode='inner': 内近似(子集, 供下界): 圆弧用内接正多边形, 并减去近源孔的外接多边形
%                 (半径略大于 5, 保证仍为子集)
%   输出 polys: 1×k cell, 每个为 2×m 凸多边形顶点列; flags: 状态标志
%   注: 多边形顶点集的最小包围圆 = 该多边形区域(或这些凸片的并)的最小包围圆,
%       故上/下界分别对 polys 顶点并集求 Welzl 最小包围圆
flags = struct('touched_arc', false, 'hole_subtracted', false, 'empty', false);
d = cfg.delta;
planes = zeros(3, 5);
planes(:, 1) = [-1; 0; 0];            % u >= 0
planes(:, 2) = [-tan(d); 1; 0];       % v <= u·tanδ
planes(:, 3) = [-tan(d); -1; 0];      % v >= -u·tanδ  ⟺  -tanδ·u - v <= 0
[n1, c1, n2, c2] = wedge_planes(P, beta, half);
planes(:, 4) = [n1; c1];
planes(:, 5) = [n2; c2];
M = 1800;                              % 包围盒: 区域 ⊂ disk(1500)
poly = [-M -M M M; -M M M -M];
for j = 1:5
    poly = clip_halfplane(poly, planes(1:2, j), planes(3, j));
    if size(poly, 2) < 3
        polys = {}; flags.empty = true; return;
    end
end
% 外圆(半径 Lmax, 圆心原点)裁剪: 仅当区域触及外弧才需要
maxr = max(hypot(poly(1, :), poly(2, :)));
if maxr > cfg.Lmax * (1 - 1e-12)
    flags.touched_arc = true;
    poly = clip_by_circle(poly, [0; 0], cfg.Lmax, cfg.n_arc, mode);
    if size(poly, 2) < 3
        polys = {}; flags.empty = true; return;
    end
end
% 目标圆域裁切(可选)
if cfg.crop_enabled
    poly = clip_by_circle(poly, cfg.crop_center(:), cfg.crop_radius, cfg.n_crop, mode);
    if size(poly, 2) < 3
        polys = {}; flags.empty = true; return;
    end
end
% 近源孔(原点孔与 P 孔): 两种模式都要减去, 但半径不同以保证包含关系:
%   inner: 外接正 n_hole_gon 边形(半径 r_inner+hole_margin ⊇ 真孔) → 结果仍是子集
%   outer: 内接正 n_hole_gon 边形(半径 r_inner−hole_margin ⊆ 真孔) → 结果仍是超集
%          (若外近似不扣孔, 当 P∈D 内部时定位区域贴住 P 孔, 孔的极端点会永久抬升上界,
%           导致细分无法收敛; 扣内接孔后 J(β)=K(β)\孔 ⊆ K_widened\内接孔, 上界有效且收紧)
if strcmp(mode, 'inner')
    rgon = cfg.r_inner + cfg.hole_margin;
else
    rgon = cfg.r_inner - cfg.hole_margin;
end
pieces = {poly};
holes = {[0; 0], P(:)};
for hi = 1:numel(holes)
    h = holes{hi};
    newpieces = {};
    for q = 1:numel(pieces)
        K = pieces{q};
        for j = 1:cfg.n_hole_gon
            phi = 2*pi*(j-1)/cfg.n_hole_gon;
            nv = [cos(phi); sin(phi)];
            pc = clip_halfplane(K, -nv, -(nv'*h + rgon));
            if size(pc, 2) >= 3
                newpieces{end+1} = pc; %#ok<AGROW>
            end
        end
    end
    pieces = newpieces;
    if isempty(pieces)
        polys = {}; flags.empty = true; return;
    end
end
flags.hole_subtracted = true;
polys = pieces;
end

function poly = clip_by_circle(poly, ctr, R, n, mode)
% 按圆约束裁剪: outer=外切正多边形(超集), inner=内接正多边形(子集)
if strcmp(mode, 'outer')
    th = 2*pi*(0:n-1)/n;
    for j = 1:n
        nv = [cos(th(j)); sin(th(j))];
        poly = clip_halfplane(poly, nv, nv'*ctr + R);
        if size(poly, 2) < 3, poly = zeros(2, 0); return; end
    end
else
    dth = 2*pi/n;
    thm = dth/2 + dth*(0:n-1);
    for j = 1:n
        nv = [cos(thm(j)); sin(thm(j))];
        poly = clip_halfplane(poly, nv, nv'*ctr + R*cos(dth/2));
        if size(poly, 2) < 3, poly = zeros(2, 0); return; end
    end
end
end

function near = polygon_near_point(K, h, R)
% 点 h 到凸多边形 K 的距离是否小于 R
if inpolygon(h(1), h(2), K(1, :), K(2, :))
    near = true; return;
end
m = size(K, 2);
dmin = inf;
for i = 1:m
    a = K(:, i); b = K(:, mod(i, m) + 1);
    dmin = min(dmin, dist_point_segment(h, a, b));
end
near = dmin < R;
end

function dd = dist_point_segment(p, a, b)
ab = b - a;
L2 = ab' * ab;
if L2 < 1e-24
    dd = norm(p - a); return;
end
t = max(0, min(1, (p - a)' * ab / L2));
dd = norm(p - (a + t * ab));
end
