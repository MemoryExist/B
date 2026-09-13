%% 问题3天眼版：已知所有干扰源精确位置的蒙特卡洛仿真
% 直接运行本脚本即可。
% 假设：机械狗从原点出发；干扰源数为 10~16；在半径1800m圆内均匀分布；
%       坐标全部已知，不需要搜索、换频和测向；每个点只计 3s 光学定位 + 2s 清除。

clear; clc; close all;
rng(20260913);                 % 固定随机种子，便于复现

numTrials = 5000;              % 蒙特卡洛次数
areaRadius = 1800;             % 目标区域半径 (m)
speed = 5;                     % 机械狗速度 (m/s)
clearTimePerSource = 3 + 2;    % 单个干扰源的定位+清除时间 (s)

numSources = zeros(numTrials,1);
routeDistance = zeros(numTrials,1);
totalTime = zeros(numTrials,1);
timePerSource = zeros(numTrials,1);

for trial = 1:numTrials
    n = randi([10,16]);

    % 在圆内按面积均匀生成干扰源，r 必须取 R*sqrt(U)
    theta = 2*pi*rand(n,1);
    r = areaRadius*sqrt(rand(n,1));
    points = [r.*cos(theta), r.*sin(theta)];

    % 已知全部坐标：先最近邻，再用 2-opt 简单缩短开放路径
    order = nearest_neighbor(points);
    order = two_opt_open(points, order);
    path = [[0,0]; points(order,:)];
    distance = sum(vecnorm(diff(path),2,2));

    numSources(trial) = n;
    routeDistance(trial) = distance;
    totalTime(trial) = distance/speed + n*clearTimePerSource;
    timePerSource(trial) = totalTime(trial)/n;
end

meanTime = mean(timePerSource);
ciHalfWidth = 1.96*std(timePerSource)/sqrt(numTrials);

fprintf('\n===== 问题3天眼版 =====\n');
fprintf('蒙特卡洛次数：%d\n', numTrials);
fprintf('平均每个点耗时：%.2f s/点\n', meanTime);
fprintf('95%% 置信区间（以每轮为重复单位）：[%.2f, %.2f] s/点\n', ...
    meanTime-ciHalfWidth, meanTime+ciHalfWidth);
fprintf('其中每点固定清除时间：%.2f s，其余为移动时间。\n', clearTimePerSource);

results = table((1:numTrials)', numSources, routeDistance, totalTime, timePerSource, ...
    'VariableNames', {'Trial','NumSources','Route_m','Total_s','TimePerSource_s'});
writetable(results, fullfile(fileparts(mfilename('fullpath')), 'omniscient_mc_results.csv'));

fig = figure('Color','w','Visible','off');
ax = axes(fig);
histogram(ax, timePerSource, 30, 'FaceColor',[0.20,0.55,0.80], 'EdgeColor','w');
xline(ax, meanTime, 'r--', 'LineWidth',1.8, ...
    'Label',sprintf('Mean = %.2f s/source',meanTime));
xlabel(ax, 'Time per source (s)', 'Color','k');
ylabel(ax, 'Number of trials', 'Color','k');
title(ax, 'Problem 3 omniscient Monte Carlo benchmark', 'Color','k');
grid(ax,'on');
set(ax, 'Color','w', 'XColor','k', 'YColor','k', ...
    'GridColor',[0.75,0.75,0.75], 'GridAlpha',0.45);
ax.Toolbar.Visible = 'off';
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), ...
    'omniscient_time_per_source.png'), 'Resolution',300, 'BackgroundColor','white');
close(fig);

%% 局部函数：最近邻开放路径
function order = nearest_neighbor(points)
n = size(points,1);
unused = true(n,1);
order = zeros(1,n);
current = [0,0];
for k = 1:n
    d = vecnorm(points-current,2,2);
    d(~unused) = inf;
    [~,idx] = min(d);
    order(k) = idx;
    unused(idx) = false;
    current = points(idx,:);
end
end

%% 局部函数：2-opt（从原点出发，终点不要求返回原点）
function order = two_opt_open(points, order)
n = numel(order);
improved = true;
while improved
    improved = false;
    for i = 1:n-1
        if i == 1
            before = [0,0];
        else
            before = points(order(i-1),:);
        end
        for j = i+1:n
            first = points(order(i),:);
            last = points(order(j),:);
            oldLength = norm(before-first);
            newLength = norm(before-last);
            if j < n
                after = points(order(j+1),:);
                oldLength = oldLength + norm(last-after);
                newLength = newLength + norm(first-after);
            end
            if newLength < oldLength-1e-9
                order(i:j) = order(j:-1:i);
                improved = true;
                break;
            end
        end
        if improved
            break;
        end
    end
end
end
