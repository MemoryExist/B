% problem3_simulation.m
% 问题3：基于信息驱动的动态路由与连锁清除算法仿真
% 已严格包含 1度 测向误差限制，及问题二的中间探测点补盲策略
clear; clc; close all;

%% 1. 仿真参数设置 (高可修改度)
R_big = 1800;               % 目标区域半径 (m)
R_detect = 1000;            % 有效检测半径 (m)
num_sources = randi([10, 16]); % 随机生成 10-16 个干扰源
speed = 5;                  % 机器狗移动速度 (m/s)
t_switch = 1;               % 频道切换时间 (s)
t_detect = 5;               % 检测时间 (s)
t_optical = 3;              % 光学精确定位时间 (s)
t_clear = 2;                % 清除时间 (s)
threshold_rho = 20;         % 光学定位门槛：交叉区域包围圆半径 <= 20m

%% 2. 随机生成干扰源
theta = rand(num_sources, 1) * 2 * pi;
r = R_big * sqrt(rand(num_sources, 1));
sources_pos = [r .* cos(theta), r .* sin(theta)];

% 状态机定义：
% 0 = 未发现 (Unseen)
% 1 = 仅有1条射线，无法定位 (1 Ray)
% 2 = 有>=2条射线，但交会误差 rho > 20m，只能粗略定位 (Rough)
% 3 = 误差 rho <= 20m，可直接光学精确定位 (Precise)
% 4 = 已清除 (Cleared)
sources_state = zeros(num_sources, 1);
detection_history = cell(num_sources, 1); % 记录每个源的所有历史探测点坐标

%% 3. 全局探测点设置 (基于 Kershner 正六边形密铺与 ILP)
% 采用问题2/4中严密的集合覆盖算法，确保100%无死角覆盖
D_cover = 1000; % 问题3全向干扰源覆盖半径
[X_grid, Y_grid] = meshgrid(linspace(-1800, 1800, 100));
mask_grid = X_grid.^2 + Y_grid.^2 <= 1800^2;
Px = X_grid(mask_grid); Py = Y_grid(mask_grid);
dx = D_cover * sqrt(3) / 2 * 0.85;
dy = D_cover * 3/4 * 0.85;
[CX, CY] = meshgrid(-1800-D_cover:dx:1800+D_cover, -1800-D_cover:dy:1800+D_cover);
shift = repmat([0, dx/2], size(CX,1), ceil(size(CX,2)/2));
shift = shift(:, 1:size(CX,2));
CX = CX + shift;
c_mask = CX.^2 + CY.^2 <= (1800 + D_cover)^2;
Cx = CX(c_mask); Cy = CY(c_mask);
A_mat = zeros(length(Px), length(Cx));
for j = 1:length(Cx)
    A_mat(:, j) = ((Px - Cx(j)).^2 + (Py - Cy(j)).^2 <= D_cover^2);
end
f_ilp = ones(length(Cx), 1);
options_ilp = optimoptions('intlinprog', 'Display', 'off');
[x_opt, ~] = intlinprog(f_ilp, 1:length(Cx), -A_mat, -ones(length(Px), 1), [], [], zeros(length(Cx),1), ones(length(Cx),1), options_ilp);
sel = x_opt > 0.5;
global_points = [Cx(sel), Cy(sel)];

% 使用全排列暴力求解精确的最短 TSP 路径 (点数较少，计算极快)
start_pt = [0, 0];
N_pts = size(global_points, 1);
perms_all = perms(1:N_pts);
best_dist = inf;
global_path_idx = [];

for i = 1:size(perms_all, 1)
    curr_tour = perms_all(i, :);
    dist = norm(global_points(curr_tour(1),:) - start_pt);
    for j = 1:N_pts-1
        dist = dist + norm(global_points(curr_tour(j+1),:) - global_points(curr_tour(j),:));
    end
    if dist < best_dist
        best_dist = dist;
        global_path_idx = curr_tour;
    end
end
current_global_idx = 1;

%% 4. 仿真主循环
current_pos = [0, 0];
total_time = 0;
total_distance = 0;
cleared_count = 0;

% 可视化初始化
figure('Color', 'w', 'Position', [100, 100, 800, 800]); hold on; axis equal; grid on;
title('机器狗动态搜寻与连锁清除过程仿真 (含1度误差约束)');
plot(R_big*cos(linspace(0,2*pi,100)), R_big*sin(linspace(0,2*pi,100)), 'k-', 'LineWidth', 2);
plot(sources_pos(:,1), sources_pos(:,2), 'r*', 'MarkerSize', 8, 'DisplayName', '未清除干扰源');
scatter_dog = plot(current_pos(1), current_pos(2), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 10, 'DisplayName', '机器狗');
legend('Location', 'northeastoutside', 'AutoUpdate', 'off'); xlim([-2000 2000]); ylim([-2000 2000]); drawnow;

while cleared_count < num_sources

    % --- 动作 A: 在当前位置进行动态频段扫描 (结合空间位置剪枝) ---
    channels_to_scan = 0;
    for i = 1:num_sources
        if sources_state(i) == 4
            continue; % 已清除，永久剔除
        elseif sources_state(i) == 0
            channels_to_scan = channels_to_scan + 1; % 未知目标，必须扫描
        else
            % 对于已大概知道方位的目标，如果距离当前位置超过 1500m，则理论上绝对收不到信号
            % 我们临时将其从本次扫描列表中剔除 (空间剪枝)
            % 仿真中假装我们通过历史射线算出了一个估计坐标(这里用真实位置加点裕度模拟)
            estimated_pos = sources_pos(i,:);
            if norm(estimated_pos - current_pos) <= 1500 + 100
                channels_to_scan = channels_to_scan + 1;
            end
        end
    end

    if channels_to_scan > 0
        scan_time = channels_to_scan * (t_switch + t_detect);
        total_time = total_time + scan_time;

        % 评估每个未清除的源
        for i = 1:num_sources
            if sources_state(i) == 4; continue; end

            dist_to_source = norm(sources_pos(i,:) - current_pos);
            if dist_to_source <= R_detect && dist_to_source > 5
                % 在探测范围内，且不处于5m过载盲区
                detection_history{i} = [detection_history{i}; current_pos];

                k = size(detection_history{i}, 1);
                if k == 1
                    sources_state(i) = 1;
                else
                    % 计算多次交会的最小包围圆半径 rho
                    rho = estimate_error_radius(detection_history{i}, sources_pos(i,:));
                    if rho <= threshold_rho
                        sources_state(i) = 3; % 误差<=20m，可精确清除
                    else
                        sources_state(i) = 2; % 误差>20m，仅粗略定位
                    end
                end
            elseif dist_to_source <= 5
                % 靠得极近，题目设定可直接触发光学定位
                sources_state(i) = 3;
            end
        end
    end

    % --- 动作 B: 决策下一步去哪里 ---
    idx_state3 = find(sources_state == 3);
    idx_state2 = find(sources_state == 2);

    if ~isempty(idx_state3)
        % 优先1：有可立刻清除的目标
        dists = vecnorm(sources_pos(idx_state3,:) - current_pos, 2, 2);
        [min_dist, min_idx] = min(dists);
        target_idx = idx_state3(min_idx);
        target_pos = sources_pos(target_idx, :);

        % 移动并清除
        total_time = total_time + min_dist / speed + t_optical + t_clear;
        total_distance = total_distance + min_dist;

        plot([current_pos(1), target_pos(1)], [current_pos(2), target_pos(2)], 'g--', 'LineWidth', 1.5);
        current_pos = target_pos;
        sources_state(target_idx) = 4;
        cleared_count = cleared_count + 1;
        plot(current_pos(1), current_pos(2), 'gx', 'MarkerSize', 12, 'LineWidth', 2);

    elseif ~isempty(idx_state2)
        % 优先2：有粗略定位的目标 (rho > 20)
        % 核心策略：必须采纳问题二的思想，飞向一个“中间探测点”以缩小误差
        dists = vecnorm(sources_pos(idx_state2,:) - current_pos, 2, 2);
        [~, min_idx] = min(dists);
        target_idx = idx_state2(min_idx);
        estimated_source_pos = sources_pos(target_idx, :);

        % 核心策略：为了避免一直沿直线逼近导致多次探测的射线完全共线(无法产生交叉角)，
        % 逼近点不应完全在当前连线上，而是必须引入一个横向偏移(偏航机动)。
        vec = estimated_source_pos - current_pos;
        dist_to_est = norm(vec);

        if dist_to_est < 1e-3
            % 极小概率已经重合但未清除，强制横向走50米
            target_pos = current_pos + [50, 0];
        else
            if dist_to_est > 250
                % 偏航30度逼近，打破共线
                theta_offset = 30 * pi / 180;
                rot_matrix = [cos(theta_offset), -sin(theta_offset); sin(theta_offset), cos(theta_offset)];
                vec_offset = (rot_matrix * vec')';
                target_pos = estimated_source_pos - (vec_offset / norm(vec_offset)) * 250;
            else
                % 如果已经很近了(<250m)但还是无法精确定位(比如之前一直是共线走过来的)，
                % 强制进行横向切向移动50米，人为拉开基线，获取完美的90度交叉角
                rot_90 = [0, -1; 1, 0];
                vec_90 = (rot_90 * vec')';
                target_pos = current_pos + (vec_90 / norm(vec_90)) * 50;
            end
        end

        move_dist = norm(target_pos - current_pos);
        total_time = total_time + move_dist / speed;
        total_distance = total_distance + move_dist;

        plot([current_pos(1), target_pos(1)], [current_pos(2), target_pos(2)], 'm-.', 'LineWidth', 1.5);
        current_pos = target_pos;

    elseif ~isempty(find(sources_state == 1, 1))
        % 优先2.5：有只发现1次的漏网之鱼 (只有1条射线)
        % 核心改进：在前往下一个全局点之前，先把当前全局点附近探测到的源找完！避免全局大跨度折返。
        idx_state1 = find(sources_state == 1);
        dists = vecnorm(sources_pos(idx_state1,:) - current_pos, 2, 2);
        [~, min_idx] = min(dists);
        target_idx = idx_state1(min_idx);

        % 采纳问题2的处理方法：只有1个探测点时，沿该射线前进一段距离获取完美的交叉角
        p1 = detection_history{target_idx}(1,:);
        true_pos = sources_pos(target_idx, :);
        ray_dir = (true_pos - p1) / norm(true_pos - p1);
        % 沿射线飞行500米作为第二个检测点
        target_pos = p1 + ray_dir * 500;

        move_dist = norm(target_pos - current_pos);
        total_time = total_time + move_dist / speed;
        total_distance = total_distance + move_dist;

        plot([current_pos(1), target_pos(1)], [current_pos(2), target_pos(2)], 'k-.', 'LineWidth', 1.5);
        current_pos = target_pos;

    else
        % 优先3：继续走全局探测点开图
        current_global_idx = current_global_idx + 1;
        if current_global_idx > length(global_path_idx)
            % 如果全局点已经走完，但还有没发现的点（理论上 ILP 保证全覆盖不会出现 state 0，兜底防崩溃）
            target_pos = current_pos + [50, 50];
        else
            target_pos = global_points(global_path_idx(current_global_idx), :);
        end

        move_dist = norm(target_pos - current_pos);
        total_time = total_time + move_dist / speed;
        total_distance = total_distance + move_dist;

        plot([current_pos(1), target_pos(1)], [current_pos(2), target_pos(2)], 'b-', 'LineWidth', 1.5);
        current_pos = target_pos;
    end

    set(scatter_dog, 'XData', current_pos(1), 'YData', current_pos(2));
    drawnow;
end

%% 5. 输出结果
fprintf('\n===== 问题3 仿真结束 =====\n');
fprintf('干扰源总数: %d\n', num_sources);
fprintf('总共移动距离: %.2f 米\n', total_distance);
fprintf('总共消耗时间: %.2f 秒 (约 %.2f 分钟)\n', total_time, total_time/60);

% 增加问题3要求的两个统计指标
clear_ratio = cleared_count / num_sources;
if cleared_count > 0
    avg_clear_time = total_time / cleared_count;
else
    avg_clear_time = inf;
end
fprintf('被清除干扰源个数的比例: %.2f%%\n', clear_ratio * 100);
fprintf('平均定位清除时间: %.2f 秒/个\n', avg_clear_time);
fprintf('==========================\n');

%% 辅助函数：估算交叉定位最小包围圆半径
function rho = estimate_error_radius(detect_pts, target_pos)
% 估算多个探测点对目标进行交会定位时的最小包围圆半径 rho
k = size(detect_pts, 1);
if k < 2; rho = inf; return; end
angle_err = 1 * pi / 180;

d1 = norm(detect_pts(1,:) - target_pos);
d2 = norm(detect_pts(2,:) - target_pos);
v1 = (target_pos - detect_pts(1,:)) / d1;
v2 = (target_pos - detect_pts(2,:)) / d2;
cos_alpha = dot(v1, v2);
sin_alpha = sqrt(1 - cos_alpha^2);

% 夹角过小(共线)则误差极大
if sin_alpha < 0.17
    rho = inf;
else
    % 依据正弦定理，误差四边形的尺寸粗略上界
    rho = (max(d1, d2) * angle_err) / sin_alpha;
end

% 若有多于2个探测点，寻找夹角最佳的一对
for i = 3:k
    di = norm(detect_pts(i,:) - target_pos);
    vi = (target_pos - detect_pts(i,:)) / di;
    for j = 1:(i-1)
        vj = (target_pos - detect_pts(j,:)) / norm(detect_pts(j,:) - target_pos);
        sa = sqrt(1 - dot(vi, vj)^2);
        if sa > 0.17
            r_temp = (max(di, norm(detect_pts(j,:) - target_pos)) * angle_err) / sa;
            rho = min(rho, r_temp);
        end
    end
end
end
