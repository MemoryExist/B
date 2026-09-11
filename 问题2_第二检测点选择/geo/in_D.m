function ok=in_D(G,cfg)
%IN_D 见证点必须属于真实源域，不是外包多边形中的任意点。
r=vecnorm(G,2,1);tol=1e-9;
ok=r>cfg.r_inner+tol & r<=cfg.Lmax+tol & G(1,:)>=-tol & ...
    abs(G(2,:))<=G(1,:)*tan(cfg.delta)+tol;
if cfg.crop_enabled
    ok=ok & vecnorm(G-cfg.crop_center(:),2,1)<=cfg.crop_radius+tol;
end
end
