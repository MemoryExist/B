function out = problem3_solver_shared(robotId, baseUrl)
% 问题三共享观测版：短半径覆盖骨架 + 动态开放路径 + 同点多频道观测。
% 官方模拟器就绪后：out = problem3_solver_shared('你们的参赛队号');
% 本地公平对比请运行 problem3_compare_shared_monte_carlo。
% 基础款和原优化版均保持不变；本文件继续复用问题一、二的几何工具。
if nargin < 1, error('请传入参赛队号；本地测试请运行 problem3_compare_shared_monte_carlo。'); end
if nargin < 2, baseUrl = 'http://127.0.0.1:2026'; end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'问题1_交会定位'));
addpath(genpath(fullfile(root,'问题2_第二检测点选择')));
cfg = config_problem2();
local = isa(robotId,'function_handle');
if local, transport = robotId; robotId = 'local'; end
opt = weboptions('MediaType','application/json','Timeout',5);
pos = [0;0]; channel = 1; vt = 0; serial = 0; limit = inf; clock0 = tic;
known = false(1,20); done = known; regions = cell(1,20);
centers = nan(2,20); radii = inf(1,20); discovered = nan(1,20);
cleared = nan(1,20); history = cell(0,3);

% 用20 m方格给连续圆域建立覆盖证书。格子外接半径为20/sqrt(2) m：
% 若格心距扫描点不超过1000-margin，则整个格子都在保守接收圆内。
h = 20; margin = h/sqrt(2);
[gx,gy] = meshgrid(-1800:h:1800);
unseen = [gx(:)';gy(:)'];
unseen = unseen(:,vecnorm(unseen)<=1800+margin);
coverR = 1000-margin-1e-6;

% 原点和正六边形构成必达搜索骨架。首轮在原点发现的目标越少，说明
% 目标越可能偏外，环站就越靠外；半径限制在[1200,1500] m。
% 对最小半径1200 m，外层最坏格心到最近环站的距离上界为980.05 m，
% 小于coverR=985.86 m；更大的环站半径也通过相同不等式验证。
% 因而自适应选择仍保证发现接收半径至少1000 m的任意全向源。
anchors = zeros(2,0); anchorRadius = nan;
a = (0:63)*2*pi/64;
domain = 1800/cos(pi/64)*[cos(a);sin(a)]; % 目标圆的外接多边形
reply = act('/enter'); limit = reply.remaining_real_duration_s;
reason = 'coverage_complete';
while true
    if toc(clock0)>limit-10, reason = 'real_time_limit'; break; end
    if sum(done)==16, reason = 'all_16_cleared'; break; end
    newlyCovered = vecnorm(unseen-pos)<=coverR;
    pending = find(known & ~done);
    % 顺路覆盖新增面积较大时扫描；没有已知目标时立即扫描以继续发现目标。
    if any(newlyCovered) && (sum(newlyCovered)*h^2>=8e5 || isempty(pending))
        order = [channel,setdiff(1:20,channel,'stable')];
        for k = order
            if ~done(k) && (~known(k)||radii(k)>60), observe(pos,k); end
        end
        unseen(:,newlyCovered) = [];
        pending = find(known & ~done);
    end
    if isempty(anchors)
        anchorRadius=max(1200,1500-60*sum(known));
        anchors=anchorRadius*[cos((0:5)*pi/3);sin((0:5)*pi/3)];
    end
    if isempty(pending) && isempty(unseen), break; end
    useful = any(hypot(unseen(1,:)'-anchors(1,:), ...
                       unseen(2,:)'-anchors(2,:))<=coverR,1);

    % 把待清除目标与尚有覆盖贡献的骨架站放入同一条开放路径。
    % 每个任务同时记录：位置、类型及关联频道
    taskPos = [centers(:,pending),anchors(:,useful)];
    taskType = [ones(1,numel(pending)),2*ones(1,nnz(useful))];
    % taskType：1=干扰源定位/清除任务，2=搜索站扫描任务
    taskChannels = [num2cell(pending),repmat({[]},1,nnz(useful))];
    % 搜索站到达后实时扫描全部频道，因此其频道集合暂时为空
    tour = zeros(1,size(taskPos,2)); left = 1:size(taskPos,2); q = pos;
    for i = 1:numel(tour)
        [~,j] = min(vecnorm(taskPos(:,left)-q));
        tour(i)=left(j); q=taskPos(:,left(j)); left(j)=[];
    end
    improved = true;
    while improved
        improved = false;
        for i = 1:numel(tour)-1
            for j = i+1:numel(tour)
                route=[pos,taskPos(:,tour)];
                old=norm(route(:,i)-route(:,i+1));
                new=norm(route(:,i)-route(:,j+1));
                if j<numel(tour)
                    old=old+norm(route(:,j+1)-route(:,j+2));
                    new=new+norm(route(:,i+1)-route(:,j+2));
                end
                if new<old-1e-6, tour(i:j)=fliplr(tour(i:j)); improved=true; end
            end
        end
    end
    j=tour(1);
    if taskType(j)==2
        q=taskPos(:,j); order=[channel,setdiff(1:20,channel,'stable')];
        for k=order
            if ~done(k) && (~known(k)||radii(k)>60), observe(q,k); end
        end
        unseen(:,vecnorm(unseen-q)<=coverR)=[];
        continue;
    end

    S = taskChannels{j};
    k = S(1);
    for step = 1:12
        if done(k), break; end
        c = centers(:,k); r = radii(k);
        if r<=60
            if clearAt(c,k), break; end
            observe(pos,k);
        else
            % 沿用基础款的局部定位动作，只检验搜索骨架收缩的净收益。
            u=c-pos; if norm(u)<1e-9, u=[1;0]; end
            u=u/norm(u); observe(c+min(80,r/2)*[-u(2);u(1)],k);
        end
    end
    if ~done(k)
        % 数值退化兜底：25 m光学方格最远覆盖距离17.68 m，小于20 m。
        V=regions{k}; lo=min(V,[],2); hi=max(V,[],2);
        for y=lo(2):25:hi(2)+25
            xs=lo(1):25:hi(1)+25;
            if abs(xs(end)-pos(1))<abs(xs(1)-pos(1)), xs=fliplr(xs); end
            for x=xs
                if clearAt([x;y],k), break; end
            end
            if done(k), break; end
        end
        assert(done(k),'光学覆盖兜底失败：请检查测向误差或接口数据。');
    end
end
act('/exit');
out = struct('cleared',sum(done),'totalTime',vt,'averageTime',vt/max(1,sum(done)), ...
    'complete',all(~known|done) && (isempty(unseen)||sum(done)==16), ...
    'reason',reason,'runtime',toc(clock0),'discoveryTime',discovered, ...
    'clearTime',cleared,'history',{history},'remainingCells',size(unseen,2), ...
    'anchorRadius',anchorRadius);
if ~local
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
    save(fullfile(root,['problem3_shared_run_' stamp '.mat']),'out');
    fprintf('共享观测版：清除%d个，总时间%.2f s，平均%.2f s，完整排查=%d\n', ...
        out.cleared,out.totalTime,out.averageTime,out.complete);
end

    function observe(q,k)
        z=act('/measure',q,k);
        if strcmp(z.measure_result,'no_signal'), return; end
        if ~known(k), known(k)=true; discovered(k)=vt; regions{k}=domain; end
        if strcmp(z.measure_result,'near')
            assert(clearAt(q,k),'near 后光学清除失败。'); return;
        end
        th=deg2rad(z.svd_deg);
        [n1,b1,n2,b2]=wedge_planes(q,th,deg2rad(1.005));
        V=clip_halfplane(regions{k},n1,b1+1e-7);
        V=clip_halfplane(V,n2,b2+1e-7);
        u=[cos(th);sin(th)];
        V=clip_halfplane(V,u,u'*q+1500+1e-7);
        assert(~isempty(V),'交会区域为空：观测与模型不相容。');
        regions{k}=V; D=diameter_many({V'});
        if D<=20, c=V(:,1); r=D;
        else, [c,r]=welzl_mec(V,cfg); end
        centers(:,k)=c; radii(k)=max(r,max(vecnorm(V-c)));
    end

    function success=clearAt(q,k)
        z=act('/clear',q,k); success=strcmp(z.clear_result,'success');
        if success, done(k)=true; cleared(k)=vt; end
    end

    function z=act(path,q,k)
        if ~strcmp(path,'/exit') && toc(clock0)>limit-5
            error('现实时间不足，停止发送新动作。');
        end
        serial=serial+1;
        request=struct('arena_id','default','robot_id',robotId, ...
            'request_id',sprintf('p3opt-%d',serial));
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
        assert(z.accepted,'模拟器拒绝请求：%s',jsonencode(z));
        vt=z.virtual_time_s;
        if nargin>1, pos=q; end
        if strcmp(path,'/measure'), channel=k; end
        history(end+1,:)={path,request,z};
    end
end
