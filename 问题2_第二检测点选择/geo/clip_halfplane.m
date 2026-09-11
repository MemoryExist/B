function Q=clip_halfplane(V,n,c)
%CLIP_HALFPLANE 保留 n'*G<=c；点和线段也是有效的退化交集。
Q=zeros(2,0);
if isempty(V),return;end
n=n(:);
if size(V,2)==1
    if n'*V<=c,Q=V;end
    return;
end
m=size(V,2); Q=zeros(2,m+2); k=0;
for i=1:m
    a=V(:,i); b=V(:,mod(i,m)+1);
    fa=n'*a-c; fb=n'*b-c;
    if fa<=0,k=k+1;Q(:,k)=a;end
    if (fa<=0)~=(fb<=0)
        k=k+1;Q(:,k)=a+fa/(fa-fb)*(b-a);
    end
end
Q=Q(:,1:k);
if size(Q,2)>1
    Q=Q(:,[true,vecnorm(diff(Q,1,2),2,1)>1e-10]);
    if size(Q,2)>1 && norm(Q(:,end)-Q(:,1))<=1e-10,Q(:,end)=[];end
end
end
