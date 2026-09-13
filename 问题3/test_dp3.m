function test_dp3()
addpath(fileparts(mfilename('fullpath')));
addpath(fileparts(fileparts(mfilename('fullpath'))));
disp('Testing problem3_solver_dp.m');
trials = 50;
% 每次测试使用随机种子，确保场景不同
world = RandStream('mt19937ar', 'Seed', 'shuffle');
oldRng = rng; cleanup = onCleanup(@() rng(oldRng));
times = zeros(1, trials);
complete = zeros(1, trials);

for trial = 1:trials
    n = randi(world, [10, 16]); channels = randperm(world, 20, n);
    theta = 2*pi*rand(world, 1, n); rho = 1800*sqrt(rand(world, 1, n));
    xy = [rho.*cos(theta); rho.*sin(theta)];
    radius = 1000 + 500*rand(world, 1, n);
    % 问题3所有干扰源全是全向的 (omnidirectional)
    directed = false(1, n);
    emit = 2*pi*rand(world, 1, n); % emit 虽然无所谓，但保持格式一致

    [m, ~] = runCase(@problem3_solver_dp, channels, xy, radius, directed, emit, randi(world, 1000000));
    times(trial) = m(3);
    complete(trial) = m(4);
    disp(['Trial ', num2str(trial), ' Avg Time: ', num2str(m(3)), ' Complete: ', num2str(m(4))]);
end
disp(['Overall Avg Time: ', num2str(mean(times)), ' Completion Rate: ', num2str(mean(complete))]);
end

function [metrics,errText]=runCase(solver,channels,xy,radius,directed,emit,noiseSeed)
n=numel(channels); live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4); errText=''; start=tic; result = struct();
noise=containers.Map('KeyType','char','ValueType','double');
try
    result=solver(@simulator);
catch err
    errText=getReport(err);
    disp(['Error in solver: ', errText]);
end
count=sum(~live); average=t/max(1,count); if count==0, average=inf; end
complete=~any(live)&&isfield(result,'complete')&&result.complete;
metrics=[count,t,average,complete];

    function z=simulator(path,request)
        % 真值仅封闭于此接口中；不向策略泄露个数、坐标、距离或接收半径。
        z=struct('accepted',true,'virtual_time_s',t);
        if strcmp(path,'/enter'), z.remaining_real_duration_s=800; return; end
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
                    noiseRng = RandStream('mt19937ar', 'Seed', noiseSeed + round(t*1000));
                    e=2*rand(noiseRng)-1;
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
