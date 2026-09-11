function [polys,flags]=build_J_region(P,beta,half,mode,cfg)
%BUILD_J_REGION 正常观测区域的内/外近似，含两站的 5 米排除区。
% inner 扣除外接孔；outer 只扣除内接孔，保证集合包含方向正确。
P=P(:);
assert(half>0 && half<pi/2,'楔形半角应在 (0,pi/2) 内。');
[Din,Dout]=source_polygons(cfg);
if strcmp(mode,'inner')
    poly=Din;
elseif strcmp(mode,'outer')
    poly=Dout;
else
    error('mode 必须为 inner 或 outer。');
end
[n1,c1,n2,c2]=wedge_planes(P,beta,half);
poly=clip_halfplane(poly,n1,c1);
poly=clip_halfplane(poly,n2,c2);
flags=struct('touched_arc',false,'hole_subtracted',false,'empty',isempty(poly));
if isempty(poly),polys={};return;end
flags.touched_arc=any(vecnorm(poly,2,1)>cfg.Lmax-1);
polys={poly}; n=max(8,round(cfg.n_hole_gon));
if strcmp(mode,'inner')
    offset=cfg.r_inner+cfg.hole_margin;
else
    % 内接孔的边到圆心距离必须乘 cos(pi/n)，只减去半径余量不够。
    offset=max(0,cfg.r_inner-cfg.hole_margin)*cos(pi/n);
end
holes=[[0;0],P];
for h=1:2
    pieces={};center=holes(:,h);
    for k=1:numel(polys)
        K=polys{k};
        if distance_to_polygon(K,center)>offset/cos(pi/n)+1e-9
            pieces{end+1}=K; %#ok<AGROW>
            continue;
        end
        flags.hole_subtracted=true;
        % 逐边分出不重叠的外侧片，避免旧实现重复片的乘法膨胀。
        remainder=K;
        for j=0:n-1
            nv=[cos(2*pi*j/n);sin(2*pi*j/n)];c=nv'*center+offset;
            outside=clip_halfplane(remainder,-nv,-c);
            if ~isempty(outside),pieces{end+1}=outside;end %#ok<AGROW>
            remainder=clip_halfplane(remainder,nv,c);
            if isempty(remainder),break;end
        end
    end
    polys=pieces;
    if isempty(polys),break;end
end
flags.empty=isempty(polys);
end

function d=distance_to_polygon(K,p)
if isempty(K),d=inf;return;end
if size(K,2)>=3 && inpolygon(p(1),p(2),K(1,:),K(2,:)),d=0;return;end
d=inf;
for i=1:size(K,2)
    a=K(:,i);v=K(:,mod(i,size(K,2))+1)-a;
    t=max(0,min(1,dot(p-a,v)/max(dot(v,v),realmin)));
    d=min(d,norm(p-a-t*v));
end
end
