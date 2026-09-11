% problem3_coverage_tsp.m
% 问题三：探测点覆盖与最短路径(TSP)求解与可视化
clear; clc; close all;

%% 1. 参数设置
R_big = 1800; % 大圆半径 (目标区域)
r_small = 1000; % 小圆半径 (探测有效半径)

% ---------------------------------------------------------
% 【数学预警】: 6个点(1中心+5外围)最大能无缝覆盖的半径约为 1701 米。
% 想要完美覆盖 1800 米大圆，必须使用至少 7 个点。
% 此处提供三种模式切换：
% mode = 6 : 6点排布 (1中心+5外围正五边形，外围有小盲区，作为对比)
% mode = 7 : 7点排布 (1中心+6外围正六边形，传统完美覆盖，路径较长 6900m)
% mode = 8 : 7点最优排布 (无中心点，7个点构成正七边形，经计算不仅完美覆盖，且总路径大幅缩短至 6194m！)
% ---------------------------------------------------------
mode = 8; % 建议使用最新的最优解模式 8

if mode == 6
    N = 6;
    D = 1350; 
    angles = linspace(0, 2*pi, 6); angles(end) = [];
    points = [0, 0; D * cos(angles'), D * sin(angles')];
elseif mode == 7
    N = 7;
    D = 1150; 
    angles = linspace(0, 2*pi, 7); angles(end) = [];
    points = [0, 0; D * cos(angles'), D * sin(angles')];
elseif mode == 8
    N = 7;
    D = 998; % 经过极限推导，无中心正七边形覆盖1800m区域的最小外扩距离
    angles = linspace(0, 2*pi, 8); angles(end) = [];
    points = [D * cos(angles'), D * sin(angles')];
end

%% 2. 求解TSP (最短路径)
% 如果配置中没有原点，强制将原点(0,0)作为起点
has_origin = any(vecnorm(points, 2, 2) < 1e-5);
if ~has_origin
    points = [0, 0; points]; % 把原点加在第1个位置
    N = N + 1;
    must_start_at_1 = true;
else
    must_start_at_1 = true;
end

all_perms = perms(1:N);
min_dist = inf;
best_path = [];

for i = 1:size(all_perms, 1)
    current_path = all_perms(i, :);
    if must_start_at_1 && current_path(1) ~= 1
        continue;
    end
    
    dist = 0;
    for j = 1:(N-1)
        dist = dist + norm(points(current_path(j), :) - points(current_path(j+1), :));
    end
    
    if dist < min_dist
        min_dist = dist;
        best_path = current_path;
    end
end

%% 3. 可视化绘图
figure('Position', [100, 100, 800, 800], 'Color', 'w');
hold on; axis equal; grid on;
title(sprintf('问题三：优化覆盖模型与最短探测路径 (总距离: %.1fm)', min_dist), 'FontSize', 14);
xlabel('X (m)'); ylabel('Y (m)');

% 绘制 1800m 大圆
theta = linspace(0, 2*pi, 200);
plot(R_big*cos(theta), R_big*sin(theta), 'k-', 'LineWidth', 2, 'DisplayName', '目标区域 (1800m)');

% 绘制探测小圆及其中心
colors = lines(N);
for i = 1:N
    cx = points(best_path(i), 1);
    cy = points(best_path(i), 2);
    % 只有非原点或者是真正的探测点才画覆盖圆 (如果是凑数的起点就不画)
    if ~has_origin && i == 1
        plot(cx, cy, 'k*', 'MarkerSize', 10, 'DisplayName', '机器狗起点 (0,0)');
        continue;
    end
    fill(cx + r_small*cos(theta), cy + r_small*sin(theta), colors(i,:), 'FaceAlpha', 0.2, 'EdgeColor', colors(i,:), 'LineWidth', 1.5, 'HandleVisibility','off');
    plot(cx, cy, 'o', 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'DisplayName', sprintf('探测点 %d', best_path(i)));
end

% 绘制最短路径
path_points = points(best_path, :);
plot(path_points(:,1), path_points(:,2), 'r--x', 'LineWidth', 2.5, 'MarkerSize', 10, 'DisplayName', '最短遍历路径');

% 标注起点和终点
text(path_points(1,1), path_points(1,2)+150, '起点(Start)', 'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(path_points(end,1), path_points(end,2)+150, '终点(End)', 'Color', 'b', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

legend('Location', 'northeastoutside');
xlim([-2800 2800]); ylim([-2800 2800]);
drawnow;

% 输出结果到命令行
fprintf('===================================================\n');
fprintf('布局模式: %d 个探测点\n', mode);
fprintf('大圆半径: %d m, 探测半径: %d m\n', R_big, r_small);
fprintf('最短遍历路径节点顺序: ');
fprintf('%d ', best_path);
fprintf('\n该路径总长度: %.2f m\n\n', min_dist);

fprintf('【各节点坐标输出】:\n');
for i = 1:N
    fprintf('节点 %d: (%.2f, %.2f)\n', i, points(i, 1), points(i, 2));
end
fprintf('===================================================\n');
