% problem1_visualization.m
% 针对问题一，建立多点交叉定位形成交会区域 R 的可视化模型
clear; clc; close all;

%% 1. 参数设置
R_detect = 1000;         % 探测半径为 1000m
angle_err_deg = 1;       % 测向误差限制为 1 度
T = [0, 0];              % 假设真实干扰源 T 的位置在原点

% 设置 3 个探测点 S_i 的坐标 (确保在探测范围内)
S = [-600, -300; 
      500, -500; 
      100,  800];
N = size(S, 1);
colors = lines(N);

%% 2. 图形初始化
figure('Color', 'w', 'Position', [100, 100, 900, 700]);
hold on; axis equal; grid on;

% 绘制探测半径的参考外框限制
rectangle('Position', [-1500, -1500, 3000, 3000], 'EdgeColor', 'none');

%% 3. 绘制各探测点的扇形探测区域，并求解交会区域 R
poly_R = []; % 用于保存交会区域的 polyshape 对象

for i = 1:N
    % (1) 画探测点
    plot(S(i,1), S(i,2), 'o', 'MarkerEdgeColor', colors(i,:), ...
         'MarkerFaceColor', colors(i,:), 'MarkerSize', 8, ...
         'DisplayName', sprintf('探测点 S_%d', i));
    text(S(i,1)-80, S(i,2)-80, sprintf('S_%d', i), 'FontSize', 12, 'FontWeight', 'bold');
    
    % (2) 计算从 S_i 指向目标 T 的真实方位角
    theta_true = atan2(T(2) - S(i,2), T(1) - S(i,1));
    
    % 画探测中心线 (理想测向线)
    plot([S(i,1), S(i,1) + R_detect * cos(theta_true)], ...
         [S(i,2), S(i,2) + R_detect * sin(theta_true)], '--', 'Color', colors(i,:), 'HandleVisibility', 'off');
         
    % (3) 计算误差形成的扇形边界
    theta1 = theta_true - angle_err_deg * pi / 180;
    theta2 = theta_true + angle_err_deg * pi / 180;
    
    % 生成扇形的多边形轮廓
    arc_theta = linspace(theta1, theta2, 100);
    arc_x = S(i,1) + R_detect * cos(arc_theta);
    arc_y = S(i,2) + R_detect * sin(arc_theta);
    
    ps = polyshape([S(i,1), arc_x], [S(i,2), arc_y]);
    
    % 画扇形区域
    plot(ps, 'FaceColor', colors(i,:), 'FaceAlpha', 0.15, 'EdgeColor', colors(i,:), 'HandleVisibility', 'off');
    
    % (4) 求取所有扇形的交集区域 R
    if isempty(poly_R)
        poly_R = ps;
    else
        poly_R = intersect(poly_R, ps);
    end
end

%% 4. 绘制真实目标 T 和 交会区域 R
% 绘制交会区域 R
plot(poly_R, 'FaceColor', 'k', 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', '交会区域 R');

% 绘制真实目标
plot(T(1), T(2), 'kp', 'MarkerFaceColor', 'k', 'MarkerSize', 14, 'DisplayName', '目标源 T');

%% 5. 格式化图表
xlabel('X 坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y 坐标 (m)', 'FontSize', 12, 'FontWeight', 'bold');
title('问题1：多点交叉定位与交会区域 R 示意图', 'FontSize', 15, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 11);
xlim([-1200, 1200]);
ylim([-1200, 1200]);

%% 6. 创建局部放大图 (Inset axes) 展现误差细节
% 在右下角画一个嵌入的放大图
axes('Position', [0.65, 0.15, 0.25, 0.25]);
box on; hold on;
for i = 1:N
    theta_true = atan2(T(2) - S(i,2), T(1) - S(i,1));
    theta1 = theta_true - angle_err_deg * pi / 180;
    theta2 = theta_true + angle_err_deg * pi / 180;
    arc_theta = linspace(theta1, theta2, 100);
    arc_x = S(i,1) + R_detect * cos(arc_theta);
    arc_y = S(i,2) + R_detect * sin(arc_theta);
    ps = polyshape([S(i,1), arc_x], [S(i,2), arc_y]);
    
    % 画扇形和中心线
    plot(ps, 'FaceColor', colors(i,:), 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot([S(i,1), S(i,1) + R_detect * cos(theta_true)], ...
         [S(i,2), S(i,2) + R_detect * sin(theta_true)], '--', 'Color', colors(i,:));
end
% 绘制目标与区域 R
plot(poly_R, 'FaceColor', 'k', 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 1);
plot(T(1), T(2), 'kp', 'MarkerFaceColor', 'k', 'MarkerSize', 10);
title('区域 R 局部放大', 'FontSize', 10);
xlim([-30, 30]);
ylim([-30, 30]);

%% 7. 导出图像
saveas(gcf, 'Problem1_Visualization.png');
disp('绘图完成，图像已保存为 Problem1_Visualization.png');
