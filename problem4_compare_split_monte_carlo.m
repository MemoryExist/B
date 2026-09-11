function [comparison,summary] = problem4_compare_split_monte_carlo(trials,seed,scenario)
% 同一批问题四案例上配对比较基础款与“全向优先/定向分流”优化款。
% [comparison,summary]=problem4_compare_split_monte_carlo(100,20260912,'uniform');
% scenario：uniform / edge / all_directional / extreme。
if nargin<1, trials=100; end
if nargin<2, seed=20260912; end
if nargin<3, scenario='uniform'; end
validateattributes(trials,{'numeric'},{'scalar','integer','positive'});
assert(ismember(scenario,{'uniform','edge','all_directional','extreme'}),'未知场景。');
root=fileparts(mfilename('fullpath')); addpath(root);
world=RandStream('mt19937ar','Seed',seed);
oldRng=rng; cleanup=onCleanup(@() rng(oldRng));
values=zeros(2*trials,21); algorithms=strings(2*trials,1); errors=strings(2*trials,1);
solvers={@problem4_solver,@problem4_solver_split}; labels=["base" "split"];
for trial=1:trials
    n=randi(world,[10,16]); channels=randperm(world,20,n);
    theta=2*pi*rand(world,1,n); rho=1800*sqrt(rand(world,1,n));
    xy=[rho.*cos(theta);rho.*sin(theta)]; radius=1000+500*rand(world,1,n);
    nDir=randi(world,[1,n-1]); directed=false(1,n);
    directed(randperm(world,n,nDir))=true; emit=2*pi*rand(world,1,n);
    if strcmp(scenario,'edge')
        xy=1800*[cos(theta);sin(theta)]; radius(:)=1000; emit(directed)=theta(directed);
    elseif strcmp(scenario,'all_directional')
        directed(:)=true;
    elseif strcmp(scenario,'extreme')
        radius(:)=1000; rho=1800*rand(world,1,n).^(1/4);
        xy=[rho.*cos(theta);rho.*sin(theta)]; emit(directed)=theta(directed);
    end
    for a=1:2
        rng(seed+trial);
        [m,err]=runCase(solvers{a},channels,xy,radius,directed,emit, ...
            seed+104729*trial,scenario);
        row=2*(trial-1)+a; values(row,:)=[trial,n,sum(directed),m];
        algorithms(row)=labels(a); errors(row)=err;
    end
    b=values(2*trial-1,6); s=values(2*trial,6);
    fprintf('%4d/%d | 定向%2d/%2d | 基础 %.1f | 分流 %.1f | 节省 %.1f s/源\n', ...
        trial,trials,sum(directed),n,b,s,b-s);
end
names={'Trial','N','Directional','Cleared','Total_s','Average_s','Runtime_s', ...
    'Complete','Move_s','Switch_s','Measure_s','OpticalLaser_s','StationsVisited', ...
    'Fallbacks','RaySweeps','DirectionObservations','GlobalMove_s','LocalMove_s', ...
    'DirectionalMode','CertifiedDirectional','P2Tests'};
comparison=array2table(values,'VariableNames',names);
comparison.Algorithm=algorithms; comparison.Error=errors;
comparison=movevars(comparison,{'Algorithm','Error'},'After','Trial');
b=comparison(comparison.Algorithm=="base",:); s=comparison(comparison.Algorithm=="split",:);
summary=table(labels',[mean(b.Average_s);mean(s.Average_s)], ...
    [sum(b.Total_s)/sum(b.Cleared);sum(s.Total_s)/sum(s.Cleared)], ...
    [mean(b.Total_s);mean(s.Total_s)],[mean(b.Move_s);mean(s.Move_s)], ...
    [mean(b.Measure_s+b.Switch_s);mean(s.Measure_s+s.Switch_s)], ...
    [mean(b.GlobalMove_s);mean(s.GlobalMove_s)],[mean(b.LocalMove_s);mean(s.LocalMove_s)], ...
    [mean(b.Complete);mean(s.Complete)],[mean(b.Average_s<300);mean(s.Average_s<300)], ...
    'VariableNames',{'Algorithm','MeanAverage_s','PooledAverage_s','MeanTotal_s', ...
    'MeanMove_s','MeanMeasureSwitch_s','MeanGlobalMove_s','MeanLocalMove_s', ...
    'FullClearRate','Below300Rate'});
delta=b.Average_s-s.Average_s;
fprintf('\n%s：基础 %.2f，分流 %.2f s/源；平均节省 %.2f s/源（%.1f%%）。\n', ...
    scenario,mean(b.Average_s),mean(s.Average_s),mean(delta),100*mean(delta)/mean(b.Average_s));
fprintf('全清率：基础 %.1f%%，分流 %.1f%%；分流胜出 %.1f%% 的配对案例。\n', ...
    100*mean(b.Complete),100*mean(s.Complete),100*mean(delta>0));
folder=fullfile(root,'问题4优化结果'); if ~isfolder(folder), mkdir(folder); end
prefix=fullfile(folder,['problem4_split_compare_' scenario]);
writetable(comparison,[prefix '_runs.csv']); writetable(summary,[prefix '_summary.csv']);
save([prefix '.mat'],'comparison','summary','seed','scenario');
f=figure('Color','w','Visible','off','Position',[100 100 900 650]); tiledlayout(2,1);
nexttile; plot(b.Average_s,'o-','DisplayName','基础款'); hold on;
plot(s.Average_s,'o-','DisplayName','分流款'); yline(300,'r--','300 s');
ylabel('Time per source (s)'); legend('Location','best'); title(['Problem 4: ' scenario]); grid on;
nexttile; bar(delta); yline(0,'k-'); xlabel('Paired trial');
ylabel('Base - split (s/source)'); grid on;
set(findall(f,'Type','axes'),'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
set(findall(f,'Type','text'),'Color','k'); exportgraphics(f,[prefix '.png'],'Resolution',150); close(f);
end

function [metrics,errText]=runCase(solver,channels,xy,radius,directed,emit,noiseSeed,scenario)
% 真值仅保留在封闭模拟器中；两算法接收完全相同的接口反馈规则。
n=numel(channels); live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4);
errText=""; result=struct(); start=tic;
try
    result=solver(@simulator);
catch err
    errText=string(getReport(err,'extended','hyperlinks','off'));
end
count=sum(~live); average=t/max(1,count); if count==0, average=inf; end
complete=~any(live)&&isfield(result,'complete')&&result.complete;
v=nan(1,9);
if isfield(result,'stationsVisited'), v(1)=result.stationsVisited; end
if isfield(result,'fallbackCount'), v(2)=result.fallbackCount; end
if isfield(result,'raySweepCount'), v(3)=result.raySweepCount; end
if isfield(result,'observations'), v(4)=sum(result.observations); end
if isfield(result,'globalDistance'), v(5)=result.globalDistance/5; end
if isfield(result,'localDistance'), v(6)=result.localDistance/5; end
if isfield(result,'directionalModeCount'), v(7)=result.directionalModeCount; end
if isfield(result,'certifiedDirectionalCount'), v(8)=result.certifiedDirectionalCount; end
if isfield(result,'p2Tests'), v(9)=result.p2Tests; end
metrics=[count,t,average,toc(start),complete,parts,v];
assert(abs(t-sum(parts))<1e-6,'模拟计时分项不守恒。');

    function z=simulator(path,request)
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
                w=sin(q(1)*12.9898+q(2)*78.233+k*37.719+noiseSeed*.013)*43758.5453;
                err=2*(w-floor(w))-1;
                if strcmp(scenario,'extreme'), err=sign(err); end
                u=xy(:,j)-p; z.measure_result='direction';
                z.svd_deg=mod(round(atan2d(u(2),u(1))+err,2),360);
            end
        else
            ok=~isempty(j)&&d<=20; dt=3+2*ok; t=t+dt; parts(4)=parts(4)+dt;
            if ok, live(j)=false; z.clear_result='success';
            else, z.clear_result='no_target_in_range'; end
        end
        z.virtual_time_s=t;
    end
end
