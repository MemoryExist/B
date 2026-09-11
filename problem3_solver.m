function out = problem3_solver(robotId, baseUrl)
% 问题三：覆盖排查 + 就近清除 + 自适应交会（仅适用于全向源）。
% 官方模拟器就绪后：out = problem3_solver('你们的参赛队号');
% 本地仿真由 problem3_monte_carlo 调用同一策略，策略不读取场景真值。
% 复用问题一 diameter_many，问题二 wedge_planes/clip_halfplane/welzl_mec。
% 新增代码仅本文件与仿真文件；原问题一、二目录须保持在本文件旁边。
if nargin < 1, error('请传入参赛队号；本地测试请运行 problem3_monte_carlo。'); end
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

% 75 m 方格的外接半径为 75/sqrt(2)。保留所有可能与目标圆相交的格子。
% 只有整个格子处于某次全频道扫描的 1000 m 接收圆内，才从待查表删除。
% 因而这里的网格给出连续区域覆盖证书，不是只检查离散点。
h = 75; margin = h/sqrt(2);
[gx,gy] = meshgrid(-1800:h:1800);
unseen = [gx(:)';gy(:)'];
unseen = unseen(:,vecnorm(unseen)<=1800+margin);
coverR = 1000-margin-1e-6;
% 原点加半径1500m上的正六边形顶点可覆盖这些带余量的格子。
% 外层格心 r<=1853.04，距最近环站夹角<=30°，最坏距离<934<coverR。
% 固定候选点避免把补查站选到边界外侧；已被顺路扫描覆盖的站会跳过。
anchors = 1500*[cos((0:5)*pi/3);sin((0:5)*pi/3)];
a = (0:63)*2*pi/64;
domain = 1800/cos(pi/64)*[cos(a);sin(a)]; % 目标圆的外接多边形
reply = act('/enter'); limit = reply.remaining_real_duration_s;
reason = 'coverage_complete';
while true
    if toc(clock0)>limit-10, reason = 'real_time_limit'; break; end
    if sum(done)==16, reason = 'all_16_cleared'; break; end
    newlyCovered = vecnorm(unseen-pos)<=coverR;
    pending = find(known & ~done);
    % 新覆盖格子总面积至少 0.8 平方公里，或无可追踪目标时停下扫描。
    % 扫描中顺便更新已知源的交会区域，共享一次移动带来的观测机会。
    if any(newlyCovered) && (sum(newlyCovered)*h^2>=8e5 || isempty(pending))
        order = [channel,setdiff(1:20,channel,'stable')];
        for k = order
            if ~done(k) && (~known(k)||radii(k)>60), observe(pos,k); end
        end
        unseen(:,newlyCovered) = [];
        pending = find(known & ~done);
    end
    if isempty(pending) && isempty(unseen), break; end
    useful = any(hypot(unseen(1,:)'-anchors(1,:), ...
                       unseen(2,:)'-anchors(2,:))<=coverR,1);
    % 把已知目标和必要补查站排在同一条开放路径中，避免最后折返补查。
    % 最近邻给初始路线，2-opt 只做路段反转；每完成一项再更新这条路线。
    tasks = [centers(:,pending),anchors(:,useful)];
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
    j=tour(1);
    if j>numel(pending)
        q=tasks(:,j); order=[channel,setdiff(1:20,channel,'stable')];
        for k=order
            if ~done(k) && (~known(k)||radii(k)>60), observe(q,k); end
        end
        unseen(:,vecnorm(unseen-q)<=coverR)=[];
        continue;
    end
    k = pending(j);
    for step = 1:12
        if done(k), break; end
        c = centers(:,k); r = radii(k);
        if r<=60
            % 小区域先尝试光学清除；失败也确实计入 3 s，不伪装成成功。
            if clearAt(c,k), break; end
            observe(pos,k);
        else
            % 向区域中心靠近，并侧移最多 80 m 增加交会角。
            u = c-pos; if norm(u)<1e-9, u = [1;0]; end
            u = u/norm(u); q = c+min(80,r/2)*[-u(2);u(1)];
            observe(q,k);
        end
    end
    if ~done(k)
        % 极端几何退化兜底：25 m 方格的最远覆盖距离为 17.68 m < 20 m。
        % 扫描定位多边形的整个包围矩形；不用随机重测同一点来减小误差。
        V = regions{k}; lo = min(V,[],2); hi = max(V,[],2);
        for y = lo(2):25:hi(2)+25
            xs = lo(1):25:hi(1)+25;
            if abs(xs(end)-pos(1))<abs(xs(1)-pos(1)), xs = fliplr(xs); end
            for x = xs
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
    'clearTime',cleared,'history',{history},'remainingCells',size(unseen,2));
if ~local
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
    save(fullfile(root,['problem3_run_' stamp '.mat']),'out');
    fprintf('清除 %d 个，总时间 %.2f s，平均 %.2f s，完整排查=%d\n', ...
        out.cleared,out.totalTime,out.averageTime,out.complete);
end

    function observe(q,k)
        % 只从接口响应取得信息；无信号不推断距离为 1500 m 以外。
        z = act('/measure',q,k);
        if strcmp(z.measure_result,'no_signal'), return; end
        if ~known(k), known(k)=true; discovered(k)=vt; regions{k}=domain; end
        if strcmp(z.measure_result,'near')
            assert(clearAt(q,k),'near 后光学清除失败。'); return;
        end
        % 接口示向度保留两位小数：将 ±1° 加宽到 ±1.005°容纳舍入。
        th = deg2rad(z.svd_deg);
        [n1,b1,n2,b2] = wedge_planes(q,th,deg2rad(1.005));
        V = clip_halfplane(regions{k},n1,b1+1e-7);
        V = clip_halfplane(V,n2,b2+1e-7);
        u = [cos(th);sin(th)];
        V = clip_halfplane(V,u,u'*q+1500+1e-7);
        assert(~isempty(V),'交会区域为空：观测与模型不相容。');
        regions{k} = V;
        D = diameter_many({V'}); % 直接使用问题一的直径算法
        if D<=20
            c = V(:,1); r = D;   % 任一顶点到区域内所有点均不超过 D
        else
            [c,r] = welzl_mec(V,cfg); % 直接使用问题二的包围圆工具
        end
        centers(:,k)=c; radii(k)=max(r,max(vecnorm(V-c)));
    end

    function success = clearAt(q,k)
        z = act('/clear',q,k);
        success = strcmp(z.clear_result,'success');
        if success, done(k)=true; cleared(k)=vt; end
    end

    function z = act(path,q,k)
        % 一个动作一个 ID；通信失败重试同一请求，避免重复计时或移动。
        if ~strcmp(path,'/exit') && toc(clock0)>limit-5
            error('现实时间不足，停止发送新动作。');
        end
        serial = serial+1;
        request = struct('arena_id','default','robot_id',robotId, ...
            'request_id',sprintf('p3-%d',serial));
        if nargin>1
            request.position = struct('x',q(1),'y',q(2)); request.channel=k;
        end
        for attempt = 1:3
            try
                if local, z=transport(path,request);
                else, z=webwrite([baseUrl path],request,opt); end
                break;
            catch err
                if attempt==3, rethrow(err); end
            end
        end
        assert(z.accepted,'模拟器拒绝请求：%s',jsonencode(z));
        vt = z.virtual_time_s;
        if nargin>1, pos=q; end
        if strcmp(path,'/measure'), channel=k; end % clear 不切换测向频道
        history(end+1,:) = {path,request,z};
    end
end
