function out = problem4_solver_split(robotId, baseUrl)
% 问题四分流优化版：信号稳定时沿用问题三全向定位，失联后转定向追踪。
% 官方模拟器：out = problem4_solver_split('你们的参赛队号');
% 配对检验：problem4_compare_split_monte_carlo(100,20260912,'uniform');
% 与基础款保持同一主结构；标有“分流改动”的部分是本版新增逻辑。
if nargin<1, error('请传入参赛队号；本地测试请运行配对蒙特卡洛程序。'); end
if nargin<2, baseUrl='http://127.0.0.1:2026'; end
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'问题1_交会定位'));
addpath(genpath(fullfile(root,'问题2_第二检测点选择')));
cfg=config_problem2();
local=isa(robotId,'function_handle');
if local, transport=robotId; robotId='local'; end
opt=weboptions('MediaType','application/json','Timeout',5);
pos=[0;0]; channel=1; vt=0; serial=0; limit=inf; clock0=tic;
inLocal=false; globalDistance=0; localDistance=0;
known=false(1,20); done=known; regions=cell(1,20);
centers=nan(2,20); radii=inf(1,20); obsCount=zeros(1,20);
lastPos=nan(2,20); lastTheta=nan(1,20);
firstPos=nan(2,20); firstTheta=nan(1,20);
discovered=nan(1,20); cleared=nan(1,20); history=cell(0,3);
fallbackCount=0; raySweepCount=0;

% 分流改动：mode=1 表示仍按全向源处理，mode=2 表示转入定向稳健追踪。
mode=zeros(1,20); certifiedDirectional=false(1,20); omniRefineCount=0;

% 与基础款完全相同的25点确定性覆盖证书，不淘汰任何未发现频道。
a=(0:11)*pi/6;
stations=[[0;0],950*[cos(a);sin(a)],1865*[cos(a+pi/12);sin(a+pi/12)]];
visited=false(1,size(stations,2));
ang=(0:71)*2*pi/72;
domain=1800/cos(pi/72)*[cos(ang);sin(ang)];

reply=act('/enter'); limit=reply.remaining_real_duration_s;
reason='search_complete';
while true
    if toc(clock0)>limit-10, reason='real_time_limit'; break; end
    if sum(done)==16, reason='all_16_cleared'; break; end
    left=find(~visited); pending=find(known & ~done);
    if isempty(left)&&isempty(pending), break; end

    % 与问题三/基础款一致：待清除源和剩余搜索站统一做开放路径排序。
    tasks=[centers(:,pending),stations(:,left)];
    tour=zeros(1,size(tasks,2)); pool=1:size(tasks,2); q=pos;
    for routeStep=1:numel(tour)
        [~,pick]=min(vecnorm(tasks(:,pool)-q));
        tour(routeStep)=pool(pick); q=tasks(:,pool(pick)); pool(pick)=[];
    end
    improved=true;
    while improved
        improved=false; route=[pos,tasks(:,tour)];
        for swapStart=1:numel(tour)-1
            for swapEnd=swapStart+1:numel(tour)
                old=norm(route(:,swapStart)-route(:,swapStart+1));
                new=norm(route(:,swapStart)-route(:,swapEnd+1));
                if swapEnd<numel(tour)
                    old=old+norm(route(:,swapEnd+1)-route(:,swapEnd+2));
                    new=new+norm(route(:,swapStart+1)-route(:,swapEnd+2));
                end
                if new<old-1e-7
                    tour(swapStart:swapEnd)=fliplr(tour(swapStart:swapEnd));
                    improved=true; route=[pos,tasks(:,tour)];
                end
            end
        end
    end
    next=tour(1);
    if next<=numel(pending)
        k=pending(next); inLocal=true; localize(k); inLocal=false; continue;
    end
    stationId=left(next-numel(pending)); q=stations(:,stationId); visited(stationId)=true;

    % 全局扫描条件与基础款相同，保留所有顺路获得方位线的机会。
    list=find(~done & (~known | obsCount<6));
    order=[channel,setdiff(list,channel,'stable')];
    if ~ismember(channel,list), order=list; end
    for k=order
        observe(q,k,false);
        if sum(done)==16, break; end
    end
end
if toc(clock0)<=limit-5, act('/exit'); end
out=struct('cleared',sum(done),'totalTime',vt,'averageTime',vt/max(1,sum(done)), ...
    'complete',(all(visited)||sum(done)==16) && all(~known|done), ...
    'reason',reason,'runtime',toc(clock0),'discoveryTime',discovered, ...
    'clearTime',cleared,'observations',obsCount,'finalRadius',radii,'history',{history}, ...
    'stationsVisited',sum(visited),'stationCount',size(stations,2), ...
    'fallbackCount',fallbackCount,'raySweepCount',raySweepCount, ...
    'globalDistance',globalDistance,'localDistance',localDistance, ...
    'directionalModeCount',sum(mode==2),'certifiedDirectionalCount',sum(certifiedDirectional), ...
    'p2Tests',omniRefineCount);
if ~local
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
    save(fullfile(root,['problem4_split_run_' stamp '.mat']),'out');
    fprintf('问题四分流版：清除%d个，总时间%.2f s，平均%.2f s，完整排查=%d\n', ...
        out.cleared,out.totalTime,out.averageTime,out.complete);
end

    function localize(k)
        if done(k), return; end
        if radii(k)<=20 && clearAt(centers(:,k),k), return; end

        % 分流改动：尚未出现过失联时，先假设为全向源，直接复用问题三
        % “区域中心+小幅侧移”的定位形式；点位落在1000 m保证区时，
        % 一旦无信号便可严格确认定向，并立即退出本段。
        if mode(k)==1 && radii(k)<=150
            for omniStep=1:2
                if done(k)||mode(k)==2, break; end
                c=centers(:,k); r=radii(k);
                if r<=60
                    if clearAt(c,k), return; end
                    hit=observe(pos,k,true);
                else
                    u=c-pos; if norm(u)<1e-9, u=[1;0]; end
                    u=u/norm(u); side=min(80,r/2);
                    q=c+side*[-u(2);u(1)];
                    hit=observe(q,k,r+side<=1000);
                end
                omniRefineCount=omniRefineCount+1;
                if ~hit, break; end
                if radii(k)<=20 && clearAt(centers(:,k),k), return; end
            end
        end
        if done(k), return; end

        % 定向稳健段沿用基础款形式：在测向线两侧成对前探。
        for round=1:5
            if done(k), return; end
            if radii(k)<=20 && clearAt(centers(:,k),k), return; end
            q0=lastPos(:,k); th=lastTheta(k);
            if any(~isfinite(q0))||~isfinite(th), break; end
            U=min(1500,max(vecnorm(regions{k}-q0)));
            if U<=600, raySweep(k,q0,th,U); return; end
            u=[cos(th);sin(th)]; v=[-u(2);u(1)];
            advance=min(490,0.6*U); side=advance*tan(deg2rad(1.005))+3;
            probes=[q0+advance*u+side*v,q0+advance*u-side*v];
            if norm(probes(:,2)-pos)<norm(probes(:,1)-pos), probes=fliplr(probes); end
            hit=observe(probes(:,1),k,false);
            if ~done(k)&&~hit, hit=observe(probes(:,2),k,false); end
            if done(k), return; end
            if ~hit
                mode(k)=2;
                raySweep(k,q0,th,advance/cos(deg2rad(1.005))+1); return;
            end
            if clearAt(lastPos(:,k),k), return; end
        end
        if done(k), return; end

        fallbackCount=fallbackCount+1;
        u=[cos(firstTheta(k));sin(firstTheta(k))]; v=[-u(2);u(1)];
        xs=0:28:1512; ys=[-42,-14,14,42];
        paths=cell(1,4); d0=inf(1,4); c=0;
        for flipY=0:1
            yy=ys; if flipY, yy=fliplr(yy); end
            for flipX=0:1
                c=c+1; P=zeros(2,numel(xs)*numel(yy)); t=0;
                for r=1:numel(yy)
                    xx=xs; if mod(r+flipX,2)==0, xx=fliplr(xx); end
                    Q=firstPos(:,k)+u*xx+v*(yy(r)*ones(size(xx)));
                    P(:,t+(1:numel(xx)))=Q; t=t+numel(xx);
                end
                paths{c}=P; d0(c)=norm(P(:,1)-pos);
            end
        end
        [~,c]=min(d0); P=paths{c};
        for fallbackPoint=1:size(P,2)
            if clearAt(P(:,fallbackPoint),k), return; end
        end
        error('光学窄带兜底失败：请检查测向误差或模拟器规则。');
    end

    function raySweep(k,q0,th,U)
        raySweepCount=raySweepCount+1; epsA=deg2rad(1.005);
        halfWidth=U*sin(epsA); assert(halfWidth<20,'测向带过宽，不能单线覆盖。');
        step=1.98*sqrt(20^2-halfWidth^2);
        xs=step/2:step:U+step/2; u=[cos(th);sin(th)]; P=q0+u*xs;
        if norm(P(:,end)-pos)<norm(P(:,1)-pos), P=fliplr(P); end
        for sweepPoint=1:size(P,2)
            if clearAt(P(:,sweepPoint),k), return; end
        end
        error('测向带直线覆盖失败：请检查误差上界或距离上界。');
    end

    function hit=observe(q,k,rangeCertified)
        if known(k) && ~rangeCertified, rangeCertified=rangeGuaranteed(q,k); end
        z=act('/measure',q,k); hit=~strcmp(z.measure_result,'no_signal');
        if ~hit
            if known(k) && mode(k)==1
                % 用户提出的“先全向、出现时有时无再按定向处理”。普通
                % 失联只改变求解分支；保证在接收距离内时还可严格确认定向。
                mode(k)=2;
                if rangeCertified, certifiedDirectional(k)=true; end
            end
            return;
        end
        if ~known(k)
            known(k)=true; mode(k)=1; discovered(k)=vt; regions{k}=domain;
        end
        if strcmp(z.measure_result,'near')
            assert(clearAt(q,k),'near 后光学清除失败。'); return;
        end
        th=deg2rad(z.svd_deg); obsCount(k)=obsCount(k)+1;
        lastPos(:,k)=q; lastTheta(k)=th;
        if obsCount(k)==1, firstPos(:,k)=q; firstTheta(k)=th; end
        [n1,b1,n2,b2]=wedge_planes(q,th,deg2rad(1.005));
        V=clip_halfplane(regions{k},n1,b1+1e-7);
        V=clip_halfplane(V,n2,b2+1e-7);
        u=[cos(th);sin(th)]; V=clip_halfplane(V,u,u'*q+1500+1e-7);
        assert(~isempty(V),'交会区域为空：观测与误差模型不相容。');
        regions{k}=V; D=diameter_many({V'});
        if D<=20, c=V(:,1); r=D;
        else, [c,r]=welzl_mec(V,cfg); end
        centers(:,k)=c; radii(k)=max(r,max(vecnorm(V-c)));
    end

    function yes=rangeGuaranteed(q,k)
        % 问题二思想的在线判据：若Q距整个可能区域均不超过1000 m，
        % 或Q对所有候选位置都不比上次有信号点远，则全向源必有信号。
        V=regions{k}; yes=max(vecnorm(V-q))<=1000+1e-7;
        if ~yes && all(isfinite(lastPos(:,k)))
            s=lastPos(:,k);
            yes=max(2*(s-q)'*V+q'*q-s'*s)<=1e-7;
        end
    end

    function success=clearAt(q,k)
        z=act('/clear',q,k); success=strcmp(z.clear_result,'success');
        if success, done(k)=true; cleared(k)=vt; end
    end

    function z=act(path,q,k)
        if ~strcmp(path,'/exit')&&toc(clock0)>limit-5
            error('现实时间不足，停止发送新动作。');
        end
        serial=serial+1;
        request=struct('arena_id','default','robot_id',robotId, ...
            'request_id',sprintf('p4split-%d',serial));
        if nargin>1
            request.position=struct('x',q(1),'y',q(2)); request.channel=k;
        end
        for attempt=1:3
            try
                if local, z=transport(path,request);
                else, z=webwrite([baseUrl path],request,opt); end
                break;
            catch err
                if attempt==3, rethrow(err); end
            end
        end
        assert(z.accepted,'模拟器拒绝请求：%s',jsonencode(z)); vt=z.virtual_time_s;
        if nargin>1
            if inLocal, localDistance=localDistance+norm(q-pos);
            else, globalDistance=globalDistance+norm(q-pos); end
            pos=q;
        end
        if strcmp(path,'/measure'), channel=k; end
        history(end+1,:)={path,request,z};
    end
end
