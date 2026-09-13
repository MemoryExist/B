
function out = problem3_solver_dp(robotId, baseUrl)
% 问题三优化版：短半径覆盖骨架 + 动态开放路径 + 1500m远距剔除剪枝（仅适用全向源）。
if nargin < 1, error('请传入参赛队号；本地测试请运行相应的 test 脚本。'); end
if nargin < 2, baseUrl = 'http://127.0.0.1:2026'; end
root = fileparts(fileparts(mfilename('fullpath'))); % 回退到 B 目录
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

% 用20 m方格给连续圆域建立覆盖证书。
h = 20; margin = h/sqrt(2);
[gx,gy] = meshgrid(-1800:h:1800);
unseen = [gx(:)';gy(:)'];
unseen = unseen(:,vecnorm(unseen)<=1800+margin);
coverR = 1000-margin-1e-6;

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
            if done(k), continue; end
            if known(k)
                if min(vecnorm(regions{k} - pos)) > 1500 + 1e-7
                    continue; % 远距剔除剪枝，节省测向时间
                end
            end
            if ~known(k) || radii(k)>60
                observe(pos,k);
            end
        end
        unseen(:,newlyCovered) = [];
        pending = find(known & ~done);
    end
    if isempty(anchors)
        % 预计算更紧凑的 ILP 覆盖点集代替边缘圆周锚点
        rng(2026);
        cx = -1800:100:1800; cy = -1800:100:1800;
        [X,Y] = meshgrid(cx, cy);
        cand = [X(:)'; Y(:)'];
        cand = cand(:, vecnorm(cand) <= 1800);

        gx = -1800:150:1800; gy = -1800:150:1800;
        [Xg,Yg] = meshgrid(gx, gy);
        gridPts = [Xg(:)'; Yg(:)'];
        gridPts = gridPts(:, vecnorm(gridPts) <= 1800);

        D_mat = pdist2(gridPts', cand');
        A = double(D_mat <= 950);
        f = ones(size(cand, 2), 1);
        intcon = 1:length(f);
        b = -ones(size(gridPts, 2), 1);
        A_ineq = -A;
        options = optimoptions('intlinprog','Display','off');
        [x, ~, exitflag] = intlinprog(f, intcon, A_ineq, b, [], [], zeros(length(f),1), ones(length(f),1), options);
        if exitflag > 0
            anchors = cand(:, round(x) == 1);
        else
            anchorRadius=max(1200,1500-60*sum(known));
            anchors=anchorRadius*[cos((0:5)*pi/3);sin((0:5)*pi/3)];
        end
    end
    if isempty(pending) && isempty(unseen), break; end
    useful = any(hypot(unseen(1,:)'-anchors(1,:), ...
        unseen(2,:)'-anchors(2,:))<=coverR,1);

    % 把待清除目标与尚有覆盖贡献的骨架站放入同一条开放路径。
    tasks = [centers(:,pending),anchors(:,useful)];
    if isempty(tasks) && ~isempty(unseen)
        tasks = unseen(:,1);
    end
    tour = zeros(1,size(tasks,2)); left = 1:size(tasks,2); q = pos;
    for i = 1:numel(tour)
        [~,j] = min(vecnorm(tasks(:,left)-q));
        tour(i)=left(j); q=tasks(:,left(j)); left(j)=[];
    end
    improved = true;
    while improved
        improved = false;
        for i = 1:numel(tour)-1
            for j = i+1:numel(tour)
                route=[pos,tasks(:,tour)];
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
    if isempty(tour)
        disp(['pending: ', num2str(pending)]);
        disp(['size(anchors): ', num2str(size(anchors))]);
        disp(['size(unseen): ', num2str(size(unseen))]);
        disp(['useful: ', num2str(useful)]);
        disp(['size(tasks): ', num2str(size(tasks))]);
        error('tour is empty!');
    end
    j=tour(1);
    if j>numel(pending)
        q=tasks(:,j); order=[channel,setdiff(1:20,channel,'stable')];
        for k=order
            if done(k), continue; end
            if known(k)
                if min(vecnorm(regions{k} - q)) > 1500 + 1e-7
                    continue;
                end
            end
            if ~known(k) || radii(k)>60
                observe(q,k);
            end
        end
        unseen(:,vecnorm(unseen-q)<=coverR)=[];
        continue;
    end

    k = pending(j);
    for step = 1:12
        if done(k), break; end
        c = centers(:,k); r = radii(k);
        if r<=60
            if clearAt(c,k), break; end
            observe(pos,k);
        else
            u=c-pos; if norm(u)<1e-9, u=[1;0]; end
            u=u/norm(u); observe(c+min(80,r/2)*[-u(2);u(1)],k);
        end
    end
    if ~done(k)
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
    save(fullfile(fileparts(mfilename('fullpath')),['problem3_dp_run_' stamp '.mat']),'out');
    fprintf('优化版：清除%d个，总时间%.2f s，平均%.2f s，完整排查=%d\n', ...
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
