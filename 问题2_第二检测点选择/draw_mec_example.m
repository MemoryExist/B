% 生成 MEC 算法原理示意图

fig = figure('Name', 'MEC 原理示意图', 'Color', 'w', 'Position', [100, 100, 700, 700]);
axes('Position', [0 0 1 1]);
axis equal;
axis off;
hold on;

c = [0, 0];
rho = 5;

% 选择 3 个点在圆上，1 个点在圆内
V1 = [rho*cosd(30), rho*sind(30)];
V2 = [rho*cosd(150), rho*sind(150)];
V3 = [-1.5, -1.5];
V4 = [rho*cosd(260), rho*sind(260)];

V = [V1; V2; V3; V4];

% 绘制区域 S (多边形)
fill(V(:,1), V(:,2), [0.9 0.94 0.98], 'FaceAlpha', 0.8, 'EdgeColor', [0.4 0.6 0.8], 'LineWidth', 2);

% 绘制 MEC 圆
theta = linspace(0, 2*pi, 200);
plot(c(1) + rho*cos(theta), c(2) + rho*sin(theta), 'Color', [0.8 0.3 0.3], 'LineWidth', 2);

% 绘制圆心
plot(c(1), c(2), '.', 'Color', [0.8 0.3 0.3], 'MarkerSize', 25);
text(c(1)+0.2, c(2)-0.3, '$c$', 'Interpreter', 'latex', 'FontSize', 24);

% 绘制半径 (连接 c 和 V1)
plot([c(1), V1(1)], [c(2), V1(2)], '--', 'Color', [0.8 0.3 0.3], 'LineWidth', 1.5);
mid_r = (c + V1) / 2;
text(mid_r(1)-0.2, mid_r(2)+0.5, '$\rho$', 'Interpreter', 'latex', 'FontSize', 24, 'Color', [0.8 0.3 0.3]);

% 绘制其它圆上的点的辅助线
plot([c(1), V2(1)], [c(2), V2(2)], ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);
plot([c(1), V4(1)], [c(2), V4(2)], ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);

% 绘制所有顶点
plot(V(:,1), V(:,2), 'o', 'MarkerFaceColor', [0.2 0.4 0.6], 'MarkerEdgeColor', 'w', 'MarkerSize', 10);
text(V1(1)+0.3, V1(2)+0.3, '$V_1$', 'Interpreter', 'latex', 'FontSize', 20);
text(V2(1)-0.7, V2(2)+0.3, '$V_2$', 'Interpreter', 'latex', 'FontSize', 20);
text(V3(1)-0.7, V3(2)-0.2, '$V_3$', 'Interpreter', 'latex', 'FontSize', 20);
text(V4(1)+0.2, V4(2)-0.5, '$V_4$', 'Interpreter', 'latex', 'FontSize', 20);

% 标签 S
text(-0.5, 1, '$S$', 'Interpreter', 'latex', 'FontSize', 28, 'Color', [0.2 0.4 0.6]);

% 添加最优化公式
text(-5.5, 5.5, '$\min_{c, \rho} \quad \rho$', 'Interpreter', 'latex', 'FontSize', 20);
text(-5.5, 4.7, 's.t. $\quad \|V_i - c\| \le \rho, \quad \forall V_i \in S$', 'Interpreter', 'latex', 'FontSize', 20);

axis([-6.5 6.5 -6.5 6.5]);
exportgraphics(fig, 'MEC_原理示意图.png', 'Resolution', 300);
