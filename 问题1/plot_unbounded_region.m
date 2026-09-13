% 生成有界化条件失效的极端情况（无限延伸交会区域）的图像
% 包含全局图像和局部图像
fig = figure('Name', '无限延伸极端情况', 'Color', 'w', 'Position', [100, 100, 1200, 650]);

% 参数设置
tau = 1; % 测向误差界 1 度
S1 = [-10, 0];
S2 = [10, 0];
theta1 = 89.5; % S1 示向度
theta2 = 90.5; % S2 示向度

angles1 = [theta1 - tau, theta1 + tau]; % [88.5, 90.5]
angles2 = [theta2 - tau, theta2 + tau]; % [89.5, 91.5]

L_max = 100000; % 足够长的截断距离，用于模拟无限长
ray1_L = S1 + L_max * [cosd(angles1(2)), sind(angles1(2))];
ray1_R = S1 + L_max * [cosd(angles1(1)), sind(angles1(1))];
ray2_L = S2 + L_max * [cosd(angles2(2)), sind(angles2(2))];
ray2_R = S2 + L_max * [cosd(angles2(1)), sind(angles2(1))];

% 构建多边形
W1_pts = [S1; ray1_R; ray1_L];
W2_pts = [S2; ray2_R; ray2_L];

poly1 = polyshape(W1_pts(:,1), W1_pts(:,2));
poly2 = polyshape(W2_pts(:,1), W2_pts(:,2));
poly_int = intersect(poly1, poly2);

% 计算精确交点
y_int = 10 * tand(88.5);
x_int = 0;

% ==================== 全局图像 ====================
subplot(1, 2, 1); hold on;
plot(poly1, 'FaceColor', [0.2 0.5 0.8], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(poly2, 'FaceColor', [0.8 0.5 0.1], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(poly_int, 'FaceColor', [0.8 0.2 0.2], 'FaceAlpha', 0.5, 'EdgeColor', [0.8 0 0], 'LineWidth', 2);

% 绘制边界线
plot([S1(1), ray1_L(1)], [S1(2), ray1_L(2)], '--', 'Color', [0.2 0.5 0.8]);
plot([S1(1), ray1_R(1)], [S1(2), ray1_R(2)], '--', 'Color', [0.2 0.5 0.8]);
plot([S2(1), ray2_L(1)], [S2(2), ray2_L(2)], '--', 'Color', [0.8 0.5 0.1]);
plot([S2(1), ray2_R(1)], [S2(2), ray2_R(2)], '--', 'Color', [0.8 0.5 0.1]);

% 绘制中心示向度
plot([S1(1), S1(1)+L_max*cosd(theta1)], [S1(2), S1(2)+L_max*sind(theta1)], 'b-', 'LineWidth', 1);
plot([S2(1), S2(1)+L_max*cosd(theta2)], [S2(2), S2(2)+L_max*sind(theta2)], 'r-', 'LineWidth', 1);

plot(S1(1), S1(2), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 6);
plot(S2(1), S2(2), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6);

axis([-40, 40, -50, 1500]); grid on;
title('全局图像：交会区域随距离增加而向两侧扩张', 'FontSize', 15, 'FontName', 'Microsoft YaHei');
xlabel('X 坐标', 'FontSize', 12); ylabel('Y 坐标', 'FontSize', 12);
legend('S_1 视界楔形', 'S_2 视界楔形', '交会区域 (无界)', 'Location', 'northwest', 'FontSize', 11);

% 添加文字说明
text(0, 1000, '开口越来越大，区域无界', 'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.6 0 0]);

% ==================== 局部图像 ====================
subplot(1, 2, 2); hold on;
plot(poly1, 'FaceColor', [0.2 0.5 0.8], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(poly2, 'FaceColor', [0.8 0.5 0.1], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(poly_int, 'FaceColor', [0.8 0.2 0.2], 'FaceAlpha', 0.5, 'EdgeColor', [0.8 0 0], 'LineWidth', 2);

% 绘制中心示向度
plot([S1(1), S1(1)+L_max*cosd(theta1)], [S1(2), S1(2)+L_max*sind(theta1)], 'b-', 'LineWidth', 1.5);
plot([S2(1), S2(1)+L_max*cosd(theta2)], [S2(2), S2(2)+L_max*sind(theta2)], 'r-', 'LineWidth', 1.5);

plot(S1(1), S1(2), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
plot(S2(1), S2(2), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);

text(S1(1)-12, S1(2)-10, 'S_1 (89.5^\circ)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'b');
text(S2(1)+2, S2(2)-10, 'S_2 (90.5^\circ)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'r');

% 标注交会点
plot(x_int, y_int, 'k.', 'MarkerSize', 20);
text(x_int+2, y_int-15, sprintf('起始交会点\nY=%.1f', y_int), 'FontSize', 11, 'FontWeight', 'bold');

axis([-25, 25, -20, 450]); grid on;
title('局部图像：两检测点视界楔形在远端才开始相交', 'FontSize', 15, 'FontName', 'Microsoft YaHei');
xlabel('X 坐标', 'FontSize', 12); ylabel('Y 坐标', 'FontSize', 12);

% 导出图像
exportgraphics(fig, '问题一_极端情况无界区域.png', 'Resolution', 300);
