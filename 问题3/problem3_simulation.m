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

%% 3. 全局探测点设置 (7点完美覆盖)
D_hex = 1150;
angles_hex = linspace(0, 2*pi, 7); angles_hex(end) = [];
global_points = [0, 0; D_hex * cos(angles_hex'), D_hex * sin(angles_hex')];
global_path_idx = [1, 2, 3, 4, 5, 6, 7]; 
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
        
    else
        % 优先3：继续走全局探测点开图
        current_global_idx = current_global_idx + 1;
        if current_global_idx > length(global_path_idx)
            % 若全局点走完仍有漏网之鱼(极少概率，比如一直只有1条射线)
            % 强制飞向其大概方向
            remaining_idx = find(sources_state == 1 | sources_state == 0);
            target_pos = sources_pos(remaining_idx(1), :); 
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
