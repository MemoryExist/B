function [comparison,summary] = problem3_compare_shared_monte_carlo(trials,seed,scenario)
% 配对蒙特卡洛：比较原优化版与同点多频道共享观测版。
% 示例：[comparison,summary]=problem3_compare_shared_monte_carlo(200,20260912,'uniform');
% scenario：uniform / edge / cluster / extreme。
% 每对试验共享源数、频道、位置、接收半径及“位置-频道”固定测向误差。
if nargin<1, trials=100; end
if nargin<2, seed=20260912; end
if nargin<3, scenario='uniform'; end
validateattributes(trials,{'numeric'},{'scalar','integer','positive'});
assert(ismember(scenario,{'uniform','edge','cluster','extreme'}),'未知场景。');
root=fileparts(mfilename('fullpath')); addpath(root);
world=RandStream('mt19937ar','Seed',seed);
oldRng=rng; cleanup=onCleanup(@()rng(oldRng));

% 前两列为试验编号、源数，其余列由runCase返回。
values=zeros(2*trials,15); algorithms=strings(2*trials,1); errors=strings(2*trials,1);
solvers={@problem3_solver_optimized,@problem3_solver_shared};
labels=["optimized","shared"];
for trial=1:trials
    n=randi(world,[10,16]); channels=randperm(world,20,n);
    theta=2*pi*rand(world,1,n); rho=1800*sqrt(rand(world,1,n));
    xy=[rho.*cos(theta);rho.*sin(theta)]; radius=1000+500*rand(world,1,n);
    if strcmp(scenario,'edge')
        xy=1800*[cos(theta);sin(theta)]; radius(:)=1000;
    elseif strcmp(scenario,'cluster')
        c=1400*[cos(theta(1));sin(theta(1))];
        xy=c+150*randn(world,2,n); xy=xy.*min(1,1800./vecnorm(xy));
    elseif strcmp(scenario,'extreme')
        xy(:,1)=[0;0]; xy(:,2)=[1800;0]; radius(:)=1000;
    end
    for a=1:2
        rng(seed+trial); % 两算法的随机包围圆从相同状态开始
        [m,err]=runCase(solvers{a},channels,xy,radius,seed+104729*trial,scenario);
        row=2*(trial-1)+a; values(row,:)=[trial,n,m];
        algorithms(row)=labels(a); errors(row)=err;
    end
    o=values(2*trial-1,5); s=values(2*trial,5);
    fprintf('%4d/%d | N=%2d | 原优化 %.1f | 共享 %.1f | 节省 %.1f s/源 | 共享测量 %.0f\n', ...
        trial,trials,n,o,s,o-s,values(2*trial,14));
end

comparison=array2table(values,'VariableNames',{'Trial','N','Cleared','Total_s', ...
    'Average_s','Runtime_s','Complete','Move_s','Switch_s','Measure_s', ...
    'OpticalLaser_s','FinalCheck_s','AnchorRadius_m','SharedMeasurements','SharedStops'});
comparison.Algorithm=algorithms; comparison.Error=errors;
comparison=movevars(comparison,{'Algorithm','Error'},'After','Trial');
o=comparison(comparison.Algorithm=="optimized",:);
s=comparison(comparison.Algorithm=="shared",:);

summary=table(labels', ...
    [mean(o.Average_s);mean(s.Average_s)], ...
    [sum(o.Total_s)/sum(o.Cleared);sum(s.Total_s)/sum(s.Cleared)], ...
    [mean(o.Total_s);mean(s.Total_s)], ...
    [mean(o.Move_s);mean(s.Move_s)], ...
    [mean(o.Switch_s);mean(s.Switch_s)], ...
    [mean(o.Measure_s);mean(s.Measure_s)], ...
    [mean(o.OpticalLaser_s);mean(s.OpticalLaser_s)], ...
    [mean(o.Complete);mean(s.Complete)], ...
    [mean(o.Complete & o.Average_s<300);mean(s.Complete & s.Average_s<300)], ...
    [mean(o.SharedMeasurements);mean(s.SharedMeasurements)], ...
    [mean(o.SharedStops);mean(s.SharedStops)], ...
    'VariableNames',{'Algorithm','MeanAverage_s','PooledAverage_s','MeanTotal_s', ...
    'MeanMove_s','MeanSwitch_s','MeanMeasure_s','MeanOpticalLaser_s', ...
    'FullClearRate','Below300Rate','MeanSharedMeasurements','MeanSharedStops'});

delta=o.Average_s-s.Average_s;
fprintf('\n%s场景：原优化 %.2f，共享 %.2f s/源；平均节省 %.2f s/源（%.2f%%）。\n', ...
    scenario,mean(o.Average_s),mean(s.Average_s),mean(delta),100*mean(delta)/mean(o.Average_s));
fprintf('共享版胜率 %.1f%%；全清率 %.1f%%；全清且低于300 s比例 %.1f%%；平均共享测量 %.2f次。\n', ...
    100*mean(delta>0),100*mean(s.Complete),100*mean(s.Complete & s.Average_s<300), ...
    mean(s.SharedMeasurements));

folder=fullfile(root,'问题3共享优化结果'); if ~isfolder(folder), mkdir(folder); end
prefix=fullfile(folder,['problem3_shared_compare_' scenario]);
writetable(comparison,[prefix '_runs.csv']); writetable(summary,[prefix '_summary.csv']);
save([prefix '.mat'],'comparison','summary','seed','scenario');
f=figure('Color','w','Visible','off','Position',[100 100 900 650]);
tiledlayout(2,1);
nexttile; ho=plot(o.Average_s,'o-','DisplayName','原优化版'); hold on;
hs=plot(s.Average_s,'o-','DisplayName','共享观测版');
yline(300,'r--','300 s','HandleVisibility','off');
ylabel('每源平均时间/s'); legend([ho,hs],'Location','best'); grid on;
title(sprintf('%s场景：配对蒙特卡洛比较',scenario));
nexttile; bar(delta); yline(0,'k-'); xlabel('配对试验编号');
ylabel('原优化版-共享版/(s/源)'); grid on;
set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
set(findall(f,'Type','text'),'Color','k');
exportgraphics(f,[prefix '.png'],'Resolution',150); close(f);
end

function [metrics,errText]=runCase(solver,channels,xy,radius,noiseSeed,scenario)
% 封闭真值模拟器：策略只能通过enter/measure/clear/exit接口取得信息。
n=numel(channels); live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4);
clearTimes=[]; errText=""; result=struct(); start=tic;
try
    result=solver(@simulator);
catch err
    errText=string(err.message);
end
count=sum(~live); average=t/max(1,count); if count==0, average=inf; end
complete=~any(live) && isfield(result,'complete') && result.complete;
tail=nan; if ~isempty(clearTimes), tail=t-max(clearTimes); end
anchorRadius=nan; sharedMeasurements=0; sharedStops=0;
if isfield(result,'anchorRadius'), anchorRadius=result.anchorRadius; end
if isfield(result,'sharedMeasurements'), sharedMeasurements=result.sharedMeasurements; end
if isfield(result,'sharedStops'), sharedStops=result.sharedStops; end
assert(abs(t-sum(parts))<1e-6,'模拟计时分项不守恒。');
metrics=[count,t,average,toc(start),complete,parts,tail,anchorRadius, ...
    sharedMeasurements,sharedStops];

    function z=simulator(path,request)
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
            if isempty(j)||d>radius(j), z.measure_result='no_signal';
            elseif d<=5, z.measure_result='near';
            else
                % 相同案例、频道和坐标产生相同误差，保证配对公平。
                w=sin(q(1)*12.9898+q(2)*78.233+k*37.719+noiseSeed*.013)*43758.5453;
                e=2*(w-floor(w))-1; if strcmp(scenario,'extreme'), e=sign(e); end
                v=xy(:,j)-p; z.measure_result='direction';
                z.svd_deg=mod(round(atan2d(v(2),v(1))+e,2),360);
            end
        else
            ok=d<=20; dt=3+2*ok; t=t+dt; parts(4)=parts(4)+dt;
            if ok
                live(j)=false; z.clear_result='success'; clearTimes(end+1)=t;
            else
                z.clear_result='no_target_in_range';
            end
        end
        z.virtual_time_s=t;
    end
end
