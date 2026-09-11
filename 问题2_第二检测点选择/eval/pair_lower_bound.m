function ell=pair_lower_bound(P,W,cfg)
%PAIR_LOWER_BOUND 同一读数能容纳的合法见证点对给真实评分下界。
W=W(:,in_D(W,cfg));P=P(:);
v=W-P;d=vecnorm(v,2,1);normal=d>cfg.r_inner+1e-9;
ok=triu((v'*v)>=cos(2*cfg.delta)*(d'*d)+1e-10,1);
ok=ok & (normal'*normal);
dist=hypot(W(1,:)'-W(1,:),W(2,:)'-W(2,:))/2;
if any(ok(:)),ell=max(dist(ok));else,ell=0;end
end
