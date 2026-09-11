function [lo,hi,isfull]=theta_span_P(P,cfg)
%THETA_SPAN_P 从外包凸多边形给安全角域，不依赖 Mapping Toolbox。
[~,Dout]=source_polygons(cfg);P=P(:);
if isempty(Dout),error('Problem2:EmptySourceRegion','目标裁切后的源区域为空。');end
if size(Dout,2)>=3 && inpolygon(P(1),P(2),Dout(1,:),Dout(2,:))
    lo=0;hi=2*pi;isfull=true;return;
end
a=sort(mod(atan2(Dout(2,:)-P(2),Dout(1,:)-P(1)),2*pi));
[gap,k]=max(diff([a,a(1)+2*pi]));
start=a(mod(k,numel(a))+1);
lo=start-cfg.delta-1e-10;
hi=start+2*pi-gap+cfg.delta+1e-10;
isfull=hi-lo>=2*pi;
if isfull,lo=0;hi=2*pi;end
end
