function viz = problem3_visualize_simulation(solverFile,seed,scenario,makeVideo)
% 问题三算法过程可视化：更换solverFile即可比较不同算法。
% 示例：problem3_visualize_simulation('problem3_solver_shared.m',20260912,'uniform');
% 同一seed和scenario生成完全相同的源、频道、接收半径及测向误差场。
%
% ===== 直接点击“运行”时，只需修改下面四个默认值 =====
if nargin<1, solverFile='problem3_solver_shared.m'; end
if nargin<2, seed=20260912; end
if nargin<3, scenario='uniform'; end       % uniform/edge/cluster/extreme
if nargin<4, makeVideo=true; end           % true同时生成MP4，false只生成末帧PNG

root=fileparts(mfilename('fullpath')); addpath(root);
validateattributes(seed,{'numeric'},{'scalar','integer','nonnegative'});
scenario=char(lower(string(scenario)));
assert(ismember(scenario,{'uniform','edge','cluster','extreme'}),'未知场景。');
[solverDir,solverName,ext]=fileparts(char(string(solverFile)));
if isempty(ext), ext='.m'; end
assert(strcmpi(ext,'.m'),'solverFile必须是MATLAB .m文件。');
if ~isempty(solverDir), addpath(solverDir,'-begin'); end
assert(exist(solverName,'file')==2,'找不到算法文件：%s',solverFile);
solver=str2func(solverName); makeVideo=logical(makeVideo);

%% 由数字种子生成一次封闭场景；真值不会传入算法
world=RandStream('mt19937ar','Seed',seed);
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
noiseSeed=seed+104729;

% 仿真器状态及逐动作日志
live=true(1,n); p=[0;0]; ch=1; t=0; parts=zeros(1,4);
events=struct('action',{},'fromPos',{},'toPos',{},'channel',{}, ...
    't0',{},'t1',{},'move_s',{},'switch_s',{},'measure_s',{}, ...
    'optical_s',{},'outcome',{},'bearing_deg',{},'sourceIndex',{}, ...
    'clearedCount',{});
oldRng=rng; rng(seed); restoreRng=onCleanup(@()rng(oldRng));
solverError=""; solverOut=struct();
try
    solverOut=solver(@simulator);
catch err
    solverError=string(err.message);
end

%% 整理可复核的数据文件
nEvents=numel(events); complete=~any(live) && isfield(solverOut,'complete') && solverOut.complete;
cleared=n-sum(live); average=t/max(1,cleared); if cleared==0, average=inf; end
truth=table((1:n)',channels',xy(1,:)',xy(2,:)',radius', ...
    'VariableNames',{'Source','Channel','X_m','Y_m','ReceiveRadius_m'});
if nEvents>0
    from=[events.fromPos]; to=[events.toPos];
    eventTable=table((1:nEvents)',string({events.action})',string({events.outcome})', ...
        [events.channel]',from(1,:)',from(2,:)',to(1,:)',to(2,:)', ...
        [events.t0]',[events.t1]',[events.move_s]',[events.switch_s]', ...
        [events.measure_s]',[events.optical_s]',[events.bearing_deg]', ...
        [events.sourceIndex]',[events.clearedCount]', ...
        'VariableNames',{'Step','Action','Outcome','Channel','FromX_m','FromY_m', ...
        'ToX_m','ToY_m','Start_s','End_s','Move_s','Switch_s','Measure_s', ...
        'OpticalClear_s','Bearing_deg','SourceIndex','ClearedCount'});
    increments=[[events.move_s]',[events.switch_s]',[events.measure_s]',[events.optical_s]'];
else
    eventTable=table(); increments=zeros(0,4);
end

folder=fullfile(root,'问题3仿真可视化'); if ~isfolder(folder), mkdir(folder); end
tag=sprintf('%s_%s_seed%d',regexprep(solverName,'[^a-zA-Z0-9_]','_'),scenario,seed);
pngPath=fullfile(folder,[tag '.png']); videoPath=fullfile(folder,[tag '.mp4']);
matPath=fullfile(folder,[tag '.mat']); eventPath=fullfile(folder,[tag '_events.csv']);
sourcePath=fullfile(folder,[tag '_sources.csv']);
writetable(truth,sourcePath); if nEvents>0, writetable(eventTable,eventPath); end

%% 按动作日志回放，不参与算法决策和虚拟计时
fig=figure('Color','w','Position',[80 80 1280 720],'Name',tag);
axMap=axes(fig,'Position',[.06 .10 .60 .83],'Color','w','XColor','k','YColor','k');
axTime=axes(fig,'Position',[.71 .56 .26 .35],'Color','w','XColor','k','YColor','k');
axInfo=axes(fig,'Position',[.71 .10 .26 .36],'Color','w','XColor','k','YColor','k');
clearedStep=inf(1,n);
for ii=1:nEvents
    if strcmp(events(ii).action,'clear') && strcmp(events(ii).outcome,'success') ...
            && events(ii).sourceIndex>0
        clearedStep(events(ii).sourceIndex)=ii;
    end
end
palette=[0 .447 .741; .929 .694 .125; 0 .62 .45; .835 .369 0];
videoOut='';
if makeVideo
    writer=VideoWriter(videoPath,'MPEG-4'); writer.FrameRate=8; writer.Quality=95; open(writer);
    for frame=0:nEvents
        drawFrame(frame); drawnow; writeVideo(writer,getframe(fig));
    end
    for ii=1:8, writeVideo(writer,getframe(fig)); end
    close(writer);
    videoOut=videoPath;
else
    drawFrame(nEvents); drawnow;
end
exportgraphics(fig,pngPath,'Resolution',180,'BackgroundColor','white');

viz=struct('solver',solverName,'seed',seed,'scenario',scenario,'sourceCount',n, ...
    'cleared',cleared,'complete',complete,'totalTime_s',t,'averageTime_s',average, ...
    'timeParts_s',parts,'solverError',solverError,'solverOutput',solverOut, ...
    'truth',truth,'events',eventTable,'png',pngPath,'video',videoOut, ...
    'mat',matPath,'eventCsv',eventPath,'sourceCsv',sourcePath);
save(matPath,'viz');
fprintf('%s | seed=%d | %s | 清除%d/%d | 总时间%.2f s | 平均%.2f s/源 | 完整=%d\n', ...
    solverName,seed,scenario,cleared,n,t,average,complete);
fprintf('末帧：%s\n',pngPath);
if makeVideo, fprintf('过程视频：%s\n',videoPath); end
if strlength(solverError)>0, warning('算法运行异常：%s',solverError); end

    function z=simulator(path,request)
        z=struct('accepted',true,'virtual_time_s',t);
        if strcmp(path,'/enter'), z.remaining_real_duration_s=1200; return; end
        if strcmp(path,'/exit'), z.exit_reason='user_exit'; return; end

        q=[request.position.x;request.position.y]; k=request.channel;
        p0=p; t0=t; moveTime=norm(q-p)/5; t=t+moveTime; p=q;
        switchTime=0; measureTime=0; opticalTime=0; bearing=nan;
        jAll=find(channels==k,1); j=find(channels==k & live,1); d=inf;
        if ~isempty(j), d=norm(xy(:,j)-p); end
        if strcmp(path,'/measure')
            action='measure'; switchTime=double(ch~=k); measureTime=5;
            ch=k; t=t+switchTime+measureTime;
            if isempty(j)||d>radius(j)
                outcome='no_signal'; z.measure_result=outcome;
            elseif d<=5
                outcome='near'; z.measure_result=outcome;
            else
                w=sin(q(1)*12.9898+q(2)*78.233+k*37.719+noiseSeed*.013)*43758.5453;
                e=2*(w-floor(w))-1; if strcmp(scenario,'extreme'), e=sign(e); end
                v=xy(:,j)-p; bearing=mod(round(atan2d(v(2),v(1))+e,2),360);
                outcome='direction'; z.measure_result=outcome; z.svd_deg=bearing;
            end
        else
            action='clear'; ok=~isempty(j) && d<=20; opticalTime=3+2*ok; t=t+opticalTime;
            if ok
                live(j)=false; outcome='success'; z.clear_result=outcome;
            else
                outcome='no_target_in_range'; z.clear_result=outcome;
            end
        end
        parts=parts+[moveTime,switchTime,measureTime,opticalTime];
        z.virtual_time_s=t;
        events(end+1)=struct('action',action,'fromPos',p0,'toPos',q,'channel',k, ...
            't0',t0,'t1',t,'move_s',moveTime,'switch_s',switchTime, ...
            'measure_s',measureTime,'optical_s',opticalTime,'outcome',outcome, ...
            'bearing_deg',bearing,'sourceIndex',double(~isempty(jAll))*valueOrZero(jAll), ...
            'clearedCount',sum(~live));
    end

    function drawFrame(i)
        cla(axMap); hold(axMap,'on');
        ang=linspace(0,2*pi,400);
        plot(axMap,1800*cos(ang),1800*sin(ang),'k-','LineWidth',1.4,'DisplayName','目标区域');
        if i>0
            to=[events(1:i).toPos]; trail=[[0;0],to];
            plot(axMap,trail(1,:),trail(2,:),'-','Color',[.35 .35 .35], ...
                'LineWidth',1.1,'DisplayName','机器狗轨迹');
            isMeasure=strcmp({events(1:i).action},'measure');
            isClear=strcmp({events(1:i).action},'clear');
            if any(isMeasure), scatter(axMap,to(1,isMeasure),to(2,isMeasure),13,palette(1,:),'o','filled'); end
            if any(isClear), scatter(axMap,to(1,isClear),to(2,isClear),24,palette(4,:),'s'); end
            ev=events(i); current=ev.toPos;
            plot(axMap,[ev.fromPos(1),ev.toPos(1)],[ev.fromPos(2),ev.toPos(2)], ...
                '-','Color',palette(2,:),'LineWidth',2.3);
        else
            current=[0;0]; ev=[];
            plot(axMap,0,0,'-','Color',[.35 .35 .35],'DisplayName','机器狗轨迹');
        end
        active=clearedStep>i;
        hActive=scatter(axMap,xy(1,active),xy(2,active),55,[.78 .12 .12],'^','filled', ...
            'DisplayName','未清除源');
        hCleared=scatter(axMap,xy(1,~active),xy(2,~active),65,[0 .50 0],'x', ...
            'LineWidth',1.8,'DisplayName','已清除源');
        for jj=1:n
            text(axMap,xy(1,jj)+22,xy(2,jj)+22,sprintf('%02d',channels(jj)), ...
                'FontSize',8,'Color',[.15 .15 .15]);
        end
        if i>0 && strcmp(ev.action,'measure') && ev.sourceIndex>0
            jj=ev.sourceIndex; rr=radius(jj);
            plot(axMap,xy(1,jj)+rr*cos(ang),xy(2,jj)+rr*sin(ang),':', ...
                'Color',[.45 .65 .85],'LineWidth',.8);
            if isfinite(ev.bearing_deg)
                rayLength=min(700,rr); a0=deg2rad(ev.bearing_deg);
                for da=deg2rad([-1.005,0,1.005])
                    style=':'; width=.8; if da==0, style='--'; width=1.3; end
                    plot(axMap,current(1)+[0,rayLength*cos(a0+da)], ...
                        current(2)+[0,rayLength*sin(a0+da)],style, ...
                        'Color',palette(1,:),'LineWidth',width);
                end
            end
            scatter(axMap,xy(1,jj),xy(2,jj),115,'o','MarkerEdgeColor',palette(2,:), ...
                'LineWidth',1.5);
        end
        hDog=plot(axMap,current(1),current(2),'p','MarkerSize',12,'MarkerFaceColor', ...
            palette(1,:),'MarkerEdgeColor','k','DisplayName','机器狗');
        axis(axMap,'equal'); grid(axMap,'on'); box(axMap,'on');
        xlim(axMap,[-2000 2000]); ylim(axMap,[-2000 2000]);
        xlabel(axMap,'x/m'); ylabel(axMap,'y/m');
        title(axMap,sprintf('%s，%s，seed=%d：步骤 %d/%d', ...
            strrep(solverName,'_','\_'),scenario,seed,i,nEvents),'Color','k');
        lg=legend(axMap,[hActive,hCleared,hDog],'Location','southoutside', ...
            'Orientation','horizontal');
        set(lg,'Color','w','TextColor','k','EdgeColor',[.3 .3 .3]);

        cla(axTime); hold(axTime,'on');
        if i>0
            cumulative=cumsum(increments(1:i,:),1);
            stepAxis=(0:i)'; cumulative=[zeros(1,4);cumulative];
            hh=area(axTime,stepAxis,cumulative,'LineStyle','none');
            for jj=1:4, hh(jj).FaceColor=palette(jj,:); hh(jj).FaceAlpha=.82; end
            hTotal=plot(axTime,stepAxis,sum(cumulative,2),'k-','LineWidth',1.2);
        end
        xlim(axTime,[0,max(2,nEvents)]); ylim(axTime,[0,max(1,t*1.05)]);
        grid(axTime,'on'); box(axTime,'on'); xlabel(axTime,'动作序号'); ylabel(axTime,'累计虚拟时间/s');
        title(axTime,'耗时组成','Color','k');
        if i>0
            lg=legend(axTime,[hh(:);hTotal], ...
                {'移动','切换频道','测向','光学定位与清除','总时间'}, ...
                'Location','northwest','FontSize',8);
            set(lg,'Color','w','TextColor','k','EdgeColor',[.3 .3 .3]);
        end

        cla(axInfo); axis(axInfo,'off');
        if i==0
            info=sprintf(['算法：%s\n场景：%s\n随机种子：%d\n干扰源：%d个\n\n' ...
                '红色三角形表示仿真真值，\n算法本身无法读取这些坐标。'], ...
                solverName,scenario,seed,n);
        else
            moveDistance=norm(ev.toPos-ev.fromPos);
            info=sprintf(['当前动作：%s\n频道：%d\n反馈：%s\n位置：(%.1f, %.1f) m\n' ...
                '本步移动：%.1f m\n本步耗时：%.1f s\n累计时间：%.1f s\n已清除：%d/%d'], ...
                ev.action,ev.channel,ev.outcome,current(1),current(2),moveDistance, ...
                ev.t1-ev.t0,ev.t1,ev.clearedCount,n);
            if i==nEvents
                info=sprintf('%s\n\n平均时间：%.2f s/源\n完整排查：%d',info,average,complete);
            end
        end
        text(axInfo,0,1,info,'VerticalAlignment','top','FontSize',11, ...
            'Interpreter','none','Color','k');
        title(axInfo,'当前状态','Color','k');
    end
end

function x=valueOrZero(x)
% 空索引在事件日志中记为0。
if isempty(x), x=0; end
end
