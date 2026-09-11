% problem3_coverage_tsp.m
% 问题三：探测点覆盖与最短路径(TSP)求解与可视化
clear; clc; close all;

%% 1. 参数设置
R_big = 1800; % 大圆半径 (目标区域)
r_small = 1000; % 小圆半径 (探测有效半径)

% ---------------------------------------------------------
% 【数学预警】: 6个点(1中心+5外围)最大能无缝覆盖的半径约为 1701 米。
% 若大圆半径强制为 1800 米，6个点会出现覆盖盲区。
% 想要完美覆盖 1800 米大圆，至少需要 7个点 (1中心+6外围正六边形)。
% 此处提供两种模式切换：
% mode = 6 : 演示你提到的6点五边形(展示最短路径，但外围有小盲区)
% mode = 7 : 演示7点六边形(完美覆盖1800m大圆)
% ---------------------------------------------------------
mode = 7; % 建议使用 7，可修改为 6 查看五边形排布

if mode == 6
    N = 6;
    D = 1350; % 外围点到圆心的距离 (经过优化计算，使内外盲区最小化)
    angles = linspace(0, 2*pi, 6);
    angles(end) = []; % 5个外围点
    points = [0, 0; D * cos(angles'), D * sin(angles')];
elseif mode == 7
    N = 7;
    D = 1150; % 完美覆盖1800m圆的合理距离
    angles = linspace(0, 2*pi, 7);
    angles(end) = []; % 6个外围点
    points = [0, 0; D * cos(angles'), D * sin(angles')];
end

%% 2. 求解TSP (最短路径)
% 由于点数 N 很少(6或7)，直接使用全排列暴力求解绝对最优解
all_perms = perms(1:N);
min_dist_center_start = inf;
best_path_center_start = [];

for i = 1:size(all_perms, 1)
    current_path = all_perms(i, :);
    
    % 强制规定必须从中心点(编号1)出发，符合无人机从中心往外扩的逻辑
    if current_path(1) ~= 1
        continue;
    end
    
    dist = 0;
    for j = 1:(N-1)
        p1 = points(current_path(j), :);
        p2 = points(current_path(j+1), :);
        dist = dist + norm(p1 - p2);
    end
    
    if dist < min_dist_center_start
        min_dist_center_start = dist;
        best_path_center_start = current_path;
    end
end

%% 3. 可视化绘图
figure('Position', [100, 100, 800, 800], 'Color', 'w');
hold on; axis equal; grid on;
title(sprintf('问题三：%d点覆盖模型与最短探测路径 (总距离: %.1fm)', N, min_dist_center_start), 'FontSize', 14);
xlabel('X (m)'); ylabel('Y (m)');

% 绘制 1800m 大圆
theta = linspace(0, 2*pi, 200);
plot(R_big*cos(theta), R_big*sin(theta), 'k-', 'LineWidth', 2, 'DisplayName', '目标区域 (1800m)');

% 绘制探测小圆及其中心
colors = lines(N);
for i = 1:N
    cx = points(best_path_center_start(i), 1);
    cy = points(best_path_center_start(i), 2);
    % 绘制 1000m 覆盖范围
    fill(cx + r_small*cos(theta), cy + r_small*sin(theta), colors(i,:), 'FaceAlpha', 0.2, 'EdgeColor', colors(i,:), 'LineWidth', 1.5, 'HandleVisibility','off');
    % 标记探测点
    plot(cx, cy, 'o', 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'DisplayName', sprintf('探测点 %d', i));
end

% 绘制最短路径 (按顺序)
path_points = points(best_path_center_start, :);
plot(path_points(:,1), path_points(:,2), 'r--x', 'LineWidth', 2.5, 'MarkerSize', 10, 'DisplayName', '最短遍历路径');

% 标注起点和终点
text(path_points(1,1), path_points(1,2)+150, '起点(Start)', 'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(path_points(end,1), path_points(end,2)+150, '终点(End)', 'Color', 'b', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

legend('Location', 'northeastoutside');
xlim([-2800 2800]); ylim([-2800 2800]);
drawnow;

% 输出结果到命令行
fprintf('===================================================\n');
fprintf('布局模式: %d 个点 (1中心 + %d外围)\n', N, N-1);
fprintf('大圆半径: %d m, 探测半径: %d m\n', R_big, r_small);
fprintf('中心出发的最短遍历路径节点顺序: ');
fprintf('%d ', best_path_center_start);
fprintf('\n');
fprintf('该路径总长度: %.2f m\n', min_dist_center_start);
fprintf('===================================================\n');
