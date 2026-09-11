function [inner,outer]=source_polygons(cfg)
%SOURCE_POLYGONS 首站扇区内/外凸多边形，近源孔在 build_J_region 扣除。
% 圆弧连弦给子集，相邻切线交点给超集。固定几何只构造一次。
persistent oldkey savedinner savedouter
key=sprintf('%.17g,',[cfg.delta,cfg.Lmax,cfg.n_arc,cfg.crop_enabled,...
    cfg.crop_center(:)',cfg.crop_radius,cfg.n_crop]);
if isequal(key,oldkey),inner=savedinner;outer=savedouter;return;end
n=max(2,round(cfg.n_arc));
th=linspace(-cfg.delta,cfg.delta,n+1);
arc=cfg.Lmax*[cos(th);sin(th)];
mid=(th(1:end-1)+th(2:end))/2;
tangents=(cfg.Lmax/cos(cfg.delta/n))*[cos(mid);sin(mid)];
inner=[[0;0],arc];
outer=[[0;0],arc(:,1),tangents,arc(:,end)];
if cfg.crop_enabled
    nc=max(8,round(cfg.n_crop));
    for j=0:nc-1
        a=2*pi*j/nc; nv=[cos(a);sin(a)];
        outer=clip_halfplane(outer,nv,nv'*cfg.crop_center(:)+cfg.crop_radius);
        a=a+pi/nc;nv=[cos(a);sin(a)];
        inner=clip_halfplane(inner,nv,nv'*cfg.crop_center(:)+cfg.crop_radius*cos(pi/nc));
    end
end
oldkey=key;savedinner=inner;savedouter=outer;
end
