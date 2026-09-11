function [runs, sources] = problem3_monte_carlo(trials, seed, scenario)
% 蒙特卡洛仿真；仅调用 problem3_solver 的同一套策略，不复制或另写算法。
% [runs,sources] = problem3_monte_carlo(200,20260912);
% 压力场景：'edge'（边界、1000m接收）、'cluster'（聚集）、'extreme'（误差端点）。
% 默认：源数在10:16均匀取值，位置在圆内面积均匀，频道无放回抽样，
% 接收半径在[1000,1500]均匀。它们是本地实验假设，不是官方案例分布。
% 同地点同频道的误差固定；新地点误差独立均匀，且保留两位小数。
% 输出逐次总时间/平均清除时间，及逐源首次发现、清除时刻、清除间隔。
% Average_s = Total_s/Cleared，包含最后查漏；逐源清除间隔本身不含最后查漏。
if nargin<1, trials=200; end
if nargin<2, seed=20260912; end
if nargin<3, scenario='uniform'; end
validateattributes(trials,{'numeric'},{'scalar','integer','positive'});
assert(ismember(scenario,{'uniform','edge','cluster','extreme'}),'未知场景。');
root = fileparts(mfilename('fullpath'));
records = zeros(trials,11); sourceRows = zeros(0,6); errors = strings(trials,1);
% 单独的随机流确保包围圆工具内的 randperm 不会改变场景或测量噪声。
world = RandStream('mt19937ar','Seed',seed);
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); rng(seed); % 固定几何工具随机序
for trial=1:trials
    n=randi(world,[10,16]); channels=randperm(world,20,n);
    theta=2*pi*rand(world,1,n); rho=1800*sqrt(rand(world,1,n));
    xy=[rho.*cos(theta);rho.*sin(theta)]; radius=1000+500*rand(world,1,n);
    if strcmp(scenario,'edge')
        xy=1800*[cos(theta);sin(theta)]; radius(:)=1000;
    elseif strcmp(scenario,'cluster')
        c=1400*[cos(theta(1));sin(theta(1))];
        xy=c+150*randn(world,2,n);
        xy=xy.*min(1,1800./vecnorm(xy));
    elseif strcmp(scenario,'extreme')
        xy(:,1)=[0;0]; xy(:,2)=[1800;0]; radius(:)=1000;
    end
    live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4);
    noise=containers.Map('KeyType','char','ValueType','double');
    noiseRng=RandStream('mt19937ar','Seed',seed+trial);
    start=tic; complete=false; why=""; result=struct(); tail=nan;
    try
        result=problem3_solver(@simulator);
        complete=result.complete && ~any(live);
        ids=find(isfinite(result.clearTime));
        [times,order]=sort(result.clearTime(ids)); ids=ids(order);
        gaps=diff([0,times]);
        if ~isempty(times), tail=t-times(end); end % 最后一次清除后的查漏时间
        sourceRows=[sourceRows;[repmat(trial,numel(ids),1),ids', ...
            result.discoveryTime(ids)',times',gaps', ...
            (times-result.discoveryTime(ids))']]; %#ok<AGROW>
    catch err
        why=string(err.message); % 保留失败案例，不剔除后计算漂亮的均值
    end
    count=sum(~live); avg=t/max(1,count);
    if count==0, avg=inf; end
    records(trial,:)=[n,count,t,avg,toc(start),complete,parts,tail]; errors(trial)=why;
    fprintf('%4d/%d | %2d/%2d | 总 %.1f s | 平均 %.1f s | 全清 %d\n', ...
        trial,trials,count,n,t,avg,complete);
    assert(abs(t-sum(parts))<1e-6,'计时分项不守恒。');
end
runs=array2table(records,'VariableNames',{'N','Cleared','Total_s','Average_s', ...
    'Runtime_s','Complete','Move_s','Switch_s','Measure_s','OpticalLaser_s','FinalCheck_s'});
runs.Error=errors;
sources=array2table(sourceRows,'VariableNames',{'Trial','Channel','Discovery_s', ...
    'Clear_s','ClearInterval_s','DiscoveryToClear_s'});
folder=fullfile(root,'问题3结果'); if ~isfolder(folder), mkdir(folder); end
prefix=fullfile(folder,['problem3_mc_' scenario]);
writetable(runs,[prefix '_runs.csv']); writetable(sources,[prefix '_sources.csv']);
save([prefix '.mat'],'runs','sources','seed','scenario','result');
fprintf('\n全清率 %.1f%%；逐次平均耗时的均值 %.2f s；总时间/总清除数 %.2f s\n', ...
    100*mean(runs.Complete),mean(runs.Average_s),sum(runs.Total_s)/sum(runs.Cleared));
fprintf('同时满足全清且平均<300s：%.1f%%；最慢一局平均 %.2f s\n', ...
    100*mean(runs.Complete & runs.Average_s<300),max(runs.Average_s));
f=figure('Color','w','Visible','off');
tiledlayout(2,1);
nexttile; plot(runs.Total_s,'o-'); ylabel('Total time (s)'); grid on;
nexttile; plot(runs.Average_s,'o-'); yline(300,'r--','300 s');
xlabel('Trial'); ylabel('Time per cleared source (s)'); grid on;
set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
set(findall(f,'Type','text'),'Color','k');
exportgraphics(f,[prefix '.png'],'Resolution',150); close(f);

    function z=simulator(path,request)
        % 真值仅封闭于此接口中；不向策略泄露个数、坐标、距离或接收半径。
        z=struct('accepted',true,'virtual_time_s',t);
        if strcmp(path,'/enter'), z.remaining_real_duration_s=1200; return; end
        if strcmp(path,'/exit'), z.exit_reason='user_exit'; return; end
        q=[request.position.x;request.position.y]; k=request.channel;
        dt=norm(q-p)/5; parts(1)=parts(1)+dt; t=t+dt; p=q;
        j=find(channels==k & live,1); d=inf;
        if ~isempty(j), d=norm(xy(:,j)-p); end
        if strcmp(path,'/measure')
            sw=double(ch~=k); ch=k; t=t+sw+5;
            parts(2)=parts(2)+sw; parts(3)=parts(3)+5;
            if isempty(j) || d>radius(j), z.measure_result='no_signal';
            elseif d<=5, z.measure_result='near';
            else
                key=sprintf('%d:%.17g:%.17g',k,p(1),p(2));
                if ~isKey(noise,key)
                    e=2*rand(noiseRng)-1;
                    if strcmp(scenario,'extreme'), e=sign(e); end
                    noise(key)=e;
                end
                z.measure_result='direction';
                v=xy(:,j)-p;
                z.svd_deg=mod(round(atan2d(v(2),v(1))+noise(key),2),360);
            end
        else
            ok=d<=20; dt=3+2*ok; t=t+dt; parts(4)=parts(4)+dt;
            if ok, live(j)=false; z.clear_result='success';
            else, z.clear_result='no_target_in_range'; end
        end
        z.virtual_time_s=t;
    end
end
