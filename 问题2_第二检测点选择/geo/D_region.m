function [Db, W] = D_region(cfg)
%D_REGION 源可行域 D 的边界多边形(绘图用)与见证点集合 W
%   D = { G: u>=0, -u*tanδ<=v<=u*tanδ, 5<||G||<=1500 }(标准完整扇区)
%   Db: 2×m 边界顶点(外弧→内弧, 可闭合作图)
%   W : 2×nw 见证点(用于点对下界, 全部属于 D 且 ||G||>=5.01)
d = cfg.delta;
th  = linspace(-d, d, 400);
arc_out = cfg.Lmax * [cos(th); sin(th)];
th2 = linspace(d, -d, 200);
arc_in  = cfg.r_inner * [cos(th2); sin(th2)];
Db = [arc_out, arc_in];
r = cfg.witness_r;
a = deg2rad(cfg.witness_ang_deg);
W = zeros(2, numel(r) * numel(a));
k = 0;
for i = 1:numel(r)
    for j = 1:numel(a)
        k = k + 1;
        W(:, k) = r(i) * [cos(a(j)); sin(a(j))];
    end
end
end
