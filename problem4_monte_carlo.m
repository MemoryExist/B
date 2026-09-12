function [runs,sources] = problem4_monte_carlo(trials,seed,scenario)
% 问题四蒙特卡洛：只通过模拟接口调用 problem4_solver，不向策略泄露真值。
% [runs,sources] = problem4_monte_carlo(100,20260912,'uniform');
% 场景：uniform（混合随机）、edge（边界外向压力）、
%       all_directional（全定向压力）、extreme（最小半径和端点误差）。
% 主要输出每局总时长、每源平均时长、首次发现及清除时刻。
if nargin<1, trials=100; end
if nargin<2, seed=20260912; end
if nargin<3, scenario='uniform'; end
validateattributes(trials,{'numeric'},{'scalar','integer','positive'});
assert(ismember(scenario,{'uniform','edge','all_directional','extreme'}),'未知场景。');
root=fileparts(mfilename('fullpath')); addpath(root);
world=RandStream('mt19937ar','Seed',seed);
oldRng=rng; cleanup=onCleanup(@() rng(oldRng)); rng(seed);
records=zeros(trials,18); sourceRows=zeros(0,7); errors=strings(trials,1);
for trial=1:trials
    n=randi(world,[10,16]); channels=randperm(world,20,n);
    theta=2*pi*rand(world,1,n); rho=1800*sqrt(rand(world,1,n));
    xy=[rho.*cos(theta);rho.*sin(theta)]; radius=1000+500*rand(world,1,n);
    nDir=randi(world,[1,n-1]); directed=false(1,n);
    directed(randperm(world,n,nDir))=true; emit=2*pi*rand(world,1,n);
    if strcmp(scenario,'edge')
        xy=1800*[cos(theta);sin(theta)]; radius(:)=1000;
        emit(directed)=theta(directed); % 定向波束朝圆外，专门检验最难边界
    elseif strcmp(scenario,'all_directional')
        directed(:)=true;
    elseif strcmp(scenario,'extreme')
        radius(:)=1000; rho=1800*rand(world,1,n).^(1/4);
        xy=[rho.*cos(theta);rho.*sin(theta)];
        emit(directed)=theta(directed);
    end
    isDir=false(1,20); isDir(channels)=directed;
    live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4);
    noise=containers.Map('KeyType','char','ValueType','double');
    noiseRng=RandStream('mt19937ar','Seed',seed+trial); result=struct(); why="";
    start=tic; complete=false; tail=nan;
    try
        result=problem4_solver(@simulator);
        complete=result.complete&&~any(live);
        ids=find(isfinite(result.clearTime));
        [times,order]=sort(result.clearTime(ids)); ids=ids(order);
        gaps=diff([0,times]); if ~isempty(times), tail=t-times(end); end
        sourceRows=[sourceRows;[repmat(trial,numel(ids),1),ids', ...
            isDir(ids)',result.discoveryTime(ids)',times',gaps', ...
            (times-result.discoveryTime(ids))']]; %#ok<AGROW>
    catch err
        why=string(err.message); % 失败局保留在统计中，不静默删除
    end
    count=sum(~live); avg=t/max(1,count); if count==0, avg=inf; end
    stationVisited=nan; fallback=nan; raySweep=nan; observations=nan;
    globalMove=nan; localMove=nan;
    if isfield(result,'stationsVisited'), stationVisited=result.stationsVisited; end
    if isfield(result,'fallbackCount'), fallback=result.fallbackCount; end
    if isfield(result,'raySweepCount'), raySweep=result.raySweepCount; end
    if isfield(result,'observations'), observations=sum(result.observations); end
    if isfield(result,'globalDistance'), globalMove=result.globalDistance/5; end
    if isfield(result,'localDistance'), localMove=result.localDistance/5; end
    records(trial,:)=[n,sum(directed),count,t,avg,toc(start),complete,parts,tail, ...
        stationVisited,fallback,raySweep,observations,globalMove,localMove]; errors(trial)=why;
    fprintf('%4d/%d | 定向%2d/%2d | 清除%2d | 总%7.1f s | 平均%6.1f s | 全清%d\n', ...
        trial,trials,sum(directed),n,count,t,avg,complete);
    assert(abs(t-sum(parts))<1e-6,'模拟计时分项不守恒。');
end
runs=array2table(records,'VariableNames',{'N','Directional','Cleared','Total_s', ...
    'Average_s','Runtime_s','Complete','Move_s','Switch_s','Measure_s', ...
    'OpticalLaser_s','FinalCheck_s','StationsVisited','Fallbacks','RaySweeps', ...
    'DirectionObservations','GlobalMove_s','LocalMove_s'});
runs.Error=errors;
sources=array2table(sourceRows,'VariableNames',{'Trial','Channel','IsDirectional', ...
    'Discovery_s','Clear_s','ClearInterval_s','DiscoveryToClear_s'});
folder=fullfile(root,'问题4结果'); if ~isfolder(folder), mkdir(folder); end
prefix=fullfile(folder,['problem4_mc_' scenario]);
writetable(runs,[prefix '_runs.csv']); writetable(sources,[prefix '_sources.csv']);
save([prefix '.mat'],'runs','sources','seed','scenario','result');
fprintf('\n全清率 %.1f%%；逐局平均 %.2f s/源；汇总平均 %.2f s/源。\n', ...
    100*mean(runs.Complete),mean(runs.Average_s),sum(runs.Total_s)/sum(runs.Cleared));
fprintf('全清且平均<300 s：%.1f%%；最慢一局 %.2f s/源；平均兜底 %.2f 次。\n', ...
    100*mean(runs.Complete & runs.Average_s<300),max(runs.Average_s),mean(runs.Fallbacks));
fprintf('平均耗时分解：全局移动 %.1f，局部移动 %.1f，测量及切换 %.1f，光学清除 %.1f s。\n', ...
    mean(runs.GlobalMove_s),mean(runs.LocalMove_s), ...
    mean(runs.Measure_s+runs.Switch_s),mean(runs.OpticalLaser_s));
f=figure('Color','w','Visible','off','Position',[100 100 850 620]);
tiledlayout(2,1);
nexttile; plot(runs.Total_s,'o-'); ylabel('Total time (s)'); grid on;
title(sprintf('Problem 4 Monte Carlo: %s',scenario));
nexttile; plot(runs.Average_s,'o-'); yline(300,'r--','300 s');
xlabel('Trial'); ylabel('Time per source (s)'); grid on;
set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
set(findall(f,'Type','text'),'Color','k');
exportgraphics(f,[prefix '.png'],'Resolution',150); close(f);

    function z=simulator(path,request)
        % 真值封闭在接口中；定向源仅在接收半径内且检测点位于发射半平面时可见。
        z=struct('accepted',true,'virtual_time_s',t);
        if strcmp(path,'/enter'), z.remaining_real_duration_s=1200; return; end
        if strcmp(path,'/exit'), z.exit_reason='user_exit'; return; end
        q=[request.position.x;request.position.y]; k=request.channel;
        dt=norm(q-p)/5; parts(1)=parts(1)+dt; t=t+dt; p=q;
        j=find(channels==k&live,1); d=inf; covered=false;
        if ~isempty(j)
            d=norm(xy(:,j)-p); e=[cos(emit(j));sin(emit(j))];
            covered=~directed(j)||(p-xy(:,j))'*e>=-1e-9;
        end
        if strcmp(path,'/measure')
            sw=double(ch~=k); ch=k; t=t+sw+5;
            parts(2)=parts(2)+sw; parts(3)=parts(3)+5;
            if isempty(j)||d>radius(j)||~covered
                z.measure_result='no_signal';
            elseif d<=5
                z.measure_result='near';
            else
                key=sprintf('%d:%.17g:%.17g',k,p(1),p(2));
                if ~isKey(noise,key)
                    e=2*rand(noiseRng)-1;
                    if strcmp(scenario,'extreme'), e=sign(e); end
                    noise(key)=e;
                end
                v=xy(:,j)-p; z.measure_result='direction';
                z.svd_deg=mod(round(atan2d(v(2),v(1))+noise(key),2),360);
            end
        else
            ok=~isempty(j)&&d<=20; dt=3+2*ok; t=t+dt; parts(4)=parts(4)+dt;
            if ok, live(j)=false; z.clear_result='success';
            else, z.clear_result='no_target_in_range'; end
        end
        z.virtual_time_s=t;
    end
end
