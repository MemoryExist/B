%% 示例：问题1 定位区域直径计算
%  输入项（两项都要用户自行输入）：
%     S     - 检测点坐标 (x,y)，每行一个点，单位：米
%     theta - 各检测点的示向度（方位角），单位：度，范围 [0,360)
clc; clear;

% ================== 自行修改：检测点坐标 与 示向度 ==================
% 每一行是一个检测点 (x, y)，对应 theta 里同一行的示向度（度）
% 想增加/减少检测点，只需同步增删 S 与 theta 的行数

% --- 示例1：两个检测点 ---
S = [   0,   0;      % 检测点1 坐标
     1000,   0 ];    % 检测点2 坐标
theta = [90; 135];   % 检测点1、2 的示向度（度）

% --- 示例2：三个检测点（取消注释即可用）---
% S = [   0,   0;
%      1000,   0;
%        0, 800 ];
% theta = [90; 135; 30];

% --- 示例3：交互式输入（取消注释即可用）---
% n = input('请输入检测点个数 n = ');
% S = zeros(n, 2); theta = zeros(n, 1);
% for i = 1:n
%     fprintf('检测点 %d:\n', i);
%     S(i,:)     = input('   坐标 [x, y]（米）= ');
%     theta(i)   = input('   示向度（度 [0,360)）= ');
% end

% ==================================================================

[D, V, flag, AB] = position_diameter(S, theta);

fprintf('========================================\n');
fprintf('定位区域直径  D = %.4f 米\n', D);
fprintf('有界性  flag = %d（1=有界，0=无界）\n', flag);
fprintf('定位区域顶点（逆时针，m×2）:\n');
disp(V);
fprintf('直径两端点 AB（旋转卡壳求出）:\n');
disp(AB);
fprintf('========================================\n');

% 可视化（可选）
figure; hold on; axis equal;
if ~isempty(V)
    plot([V(:,1); V(1,1)], [V(:,2); V(1,2)], 'k-', 'LineWidth', 1.5); % 定位区域边界
    fill(V(:,1), V(:,2), [0.9 0.95 1]);                                % 填充
end
plot(S(:,1), S(:,2), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 7);   % 检测点
for i = 1:size(S,1)
    text(S(i,1)+20, S(i,2)+20, sprintf('S%d', i));
    u = [cosd(theta(i)), sind(theta(i))];
    quiver(S(i,1), S(i,2), 300*u(1), 300*u(2), 0, 'r--', 'LineWidth', 1);
end
% 画出直径线段（旋转卡壳求出的两个端点连线）
if ~isempty(AB) && size(AB,1) == 2
    plot(AB(:,1), AB(:,2), 'b-', 'LineWidth', 2.5);
    plot(AB(:,1), AB(:,2), 'bs', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
end
title(sprintf('定位区域直径 D = %.2f m（蓝线为直径）', D));
grid on;
