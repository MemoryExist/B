function test_dp()
addpath(fileparts(mfilename('fullpath')));
addpath(fileparts(fileparts(mfilename('fullpath'))));
disp('Testing problem4_solver_dp.m');
trials = 100;
% 将原来的固定种子改成了随机种子，确保每次测试场景完全不同
world = RandStream('mt19937ar', 'Seed', 'shuffle');
oldRng = rng; cleanup = onCleanup(@() rng(oldRng));
times = zeros(1, trials);
complete = zeros(1, trials);

for trial = 1:trials
    n = randi(world, [10, 16]); channels = randperm(world, 20, n);
    theta = 2*pi*rand(world, 1, n); rho = 1800*sqrt(rand(world, 1, n));
    xy = [rho.*cos(theta); rho.*sin(theta)]; radius = 1000 + 500*rand(world, 1, n);
    nDir = randi(world, [1, n-1]); directed = false(1, n);
    directed(randperm(world, n, nDir)) = true; emit = 2*pi*rand(world, 1, n);

    % 使用世界流自身状态作为每次实验的独立环境，不手动指定固定种子
    [m, ~] = runCase(@problem4_solver_dp, channels, xy, radius, directed, emit, randi(world, 1000000));
    times(trial) = m(3);
    complete(trial) = m(4);
    disp(['Trial ', num2str(trial), ' Avg Time: ', num2str(m(3)), ' Complete: ', num2str(m(4))]);
end
disp(['Overall Avg Time: ', num2str(mean(times)), ' Completion Rate: ', num2str(mean(complete))]);
end

function [metrics,errText]=runCase(solver,channels,xy,radius,directed,emit,noiseSeed)
n=numel(channels); live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4); errText=''; start=tic;
try
    result=solver(@simulator);
catch err
    errText=getReport(err);
end
count=sum(~live); average=t/max(1,count); if count==0, average=inf; end
complete=~any(live)&&isfield(result,'complete')&&result.complete;
metrics=[count,t,average,complete];

    function z=simulator(path,request)
        z=struct('accepted',true,'virtual_time_s',t);
        if strcmp(path,'/enter'), z.remaining_real_duration_s=1200; return; end
        if strcmp(path,'/exit'), z.exit_reason='user_exit'; return; end
        q=[request.position.x;request.position.y]; k=request.channel;
        dt=norm(q-p)/5; parts(1)=parts(1)+dt; t=t+dt; p=q;
        j=find(channels==k&live,1); covered=false;
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
                z.measure_result='direction'; z.svd_deg=mod(round(atan2d(xy(2,j)-p(2),xy(1,j)-p(1))+err,2),360);
            end
        else
            ok=~isempty(j)&&d<=20; dt=3+2*ok; t=t+dt; parts(4)=parts(4)+dt;
            if ok, live(j)=false; z.clear_result='success'; else, z.clear_result='no_target_in_range'; end
        end
        z.virtual_time_s=t;
    end
end
