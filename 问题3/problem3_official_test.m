function problem3_official_test()
% problem3_official_test.m
% 官方模拟器黑盒对接最终测试脚本
clear; clc;

%% 1. 参数与模拟器配置
baseUrl = 'http://127.0.0.1:2026';
robotId = '202617201282'; % 修改为你自己的队号
options = weboptions('MediaType', 'application/json', 'Timeout', 5);

req_counter = 1;

% 初始化进入赛场
enterReq = baseRequest(robotId, sprintf('enter-%d', req_counter));
req_counter = req_counter + 1;
enterResp = post(baseUrl, '/enter', enterReq, options);
if enterResp.accepted ~= true
    fprintf('【错误】未能进入赛场，请检查模拟器是否已开启并启动了"演练测试"\n');
    return;
end
fprintf('成功进入赛场！剩余限时: %d秒\n', enterResp.remaining_real_duration_s);

%% 2. 状态机与变量初始化
num_channels = 20;
sources_state = zeros(num_channels, 1); % 0=未知, 1=弱定位, 2=粗定位, 3=精准可清除, 4=已清除
est_pos = zeros(num_channels, 2);       % 估算的坐标
rays = cell(num_channels, 1);           % 记录每个频道的探测射线 [x, y, angle_deg]
cleared_count = 0;

% 最优 7 点正七边形基线 (路径 6194m)
D_heptagon = 998;
angles_hept = linspace(0, 2*pi, 8); angles_hept(end) = [];
heptagon_pts = [D_heptagon * cos(angles_hept'), D_heptagon * sin(angles_hept')];
global_points = [0, 0; heptagon_pts];
global_idx = 1;

current_pos = [0, 0];

%% 3. 黑盒主搜索循环
while true
    % 检查终止条件：如果全局图开完了，且没有剩下处于状态1、2、3的目标，则任务结束
    if global_idx > 8 && sum(sources_state == 1 | sources_state == 2 | sources_state == 3) == 0
        fprintf('=======================================\n');
        fprintf('【大满贯】全图探索完毕，所有发现的干扰源均已清除！\n');
        fprintf('共清除干扰源总数: %d\n', cleared_count);
        break;
    end
    
    % --- 动作路由判定 ---
    idx_state3 = find(sources_state == 3);
    idx_state2 = find(sources_state == 2);
    
    if ~isempty(idx_state3)
        % 【优先级1】：前往清除精确定位的目标 (连锁清除反应核心)
        % 找离当前位置最近的
        dists = vecnorm(est_pos(idx_state3,:) - current_pos, 2, 2);
        [~, min_idx] = min(dists);
        target_ch = idx_state3(min_idx);
        target_pos = est_pos(target_ch, :);
        
        current_pos = target_pos;
        fprintf('-> 前往 (%.1f, %.1f) 清除频道 %d...\n', current_pos(1), current_pos(2), target_ch);
        
        req = actionRequest(robotId, sprintf('clear-%d', req_counter), current_pos(1), current_pos(2), target_ch);
        req_counter = req_counter + 1;
        resp = post(baseUrl, '/clear', req, options);
        
        if strcmp(resp.clear_result, 'success')
            sources_state(target_ch) = 4;
            cleared_count = cleared_count + 1;
            fprintf('★★★ [虚拟耗时:%d秒] 频道 %d 清除成功！(已清除:%d个) ★★★\n', resp.virtual_time_s, target_ch, cleared_count);
            % 核心：清除成功后，机器狗直接原位驻留，开启一次原地全频段扫描以发现新目标！
            scan_at_current_pos(current_pos);
        else
            % 清除失败（极小概率误差导致目标在20m外）
            fprintf('[虚拟耗时:%d秒] 频道 %d 清除失败！(可能在20m外)，立刻就地二次探测补救...\n', resp.virtual_time_s, target_ch);
            sources_state(target_ch) = 2; % 降级为粗定位
            single_measure(target_ch, current_pos);
        end
        
    elseif ~isempty(idx_state2)
        % 【优先级2】：逼近粗定位目标，打破共线陷阱
        dists = vecnorm(est_pos(idx_state2,:) - current_pos, 2, 2);
        [~, min_idx] = min(dists);
        target_ch = idx_state2(min_idx);
        target_est = est_pos(target_ch, :);
        
        vec = target_est - current_pos;
        dist_to_est = norm(vec);
        
        if dist_to_est < 1e-3
            % 原地卡死，强制横向平移50m创造测向基线
            target_pos = current_pos + [50, 0];
        elseif dist_to_est > 250
            % 偏航30度斜切逼近，保证下次探测夹角完美
            theta_offset = 30 * pi / 180;
            rot_matrix = [cos(theta_offset), -sin(theta_offset); sin(theta_offset), cos(theta_offset)];
            vec_offset = (rot_matrix * vec')';
            target_pos = target_est - (vec_offset / norm(vec_offset)) * 250;
        else
            % 距离很近但依然没精确，大概率是一路直走共线了，切向走50m
            rot_90 = [0, -1; 1, 0];
            vec_90 = (rot_90 * vec')';
            target_pos = current_pos + (vec_90 / norm(vec_90)) * 50;
        end
        
        current_pos = target_pos;
        fprintf('-> 横向偏航逼近粗定位频道 %d，前往探测点 (%.1f, %.1f)...\n', target_ch, current_pos(1), current_pos(2));
        single_measure(target_ch, current_pos);
        
    else
        % 【优先级3】：走全局路标点开图
        if global_idx <= 8
            current_pos = global_points(global_idx, :);
            fprintf('-> 开图前往全局基站 %d (%.1f, %.1f)...\n', global_idx, current_pos(1), current_pos(2));
            scan_at_current_pos(current_pos);
            global_idx = global_idx + 1;
        else
            break;
        end
    end
end

%% 4. 退出测试
exitReq = baseRequest(robotId, sprintf('exit-%d', req_counter));
exitResp = post(baseUrl, '/exit', exitReq, options);
if exitResp.accepted == true
    fprintf('【测试结束】退出原因：%s\n', exitResp.exit_reason);
end

% ---------------- 内嵌函数区域 ----------------

    function scan_at_current_pos(pos)
        % 在当前点遍历扫描全部非清除频道 (带动态空间剪枝)
        for ch = 1:num_channels
            if sources_state(ch) == 4
                continue; % 已清除，永久跳过
            end
            
            % 空间剪枝：如果我们知道它的大概位置，且距离极远，则跳过不扫节省时间
            if (sources_state(ch) == 1 || sources_state(ch) == 2 || sources_state(ch) == 3)
                if norm(est_pos(ch,:) - pos) > 1600
                    continue; 
                end
            end
            
            single_measure(ch, pos);
        end
    end

    function single_measure(ch, pos)
        req = actionRequest(robotId, sprintf('measure-%d', req_counter), pos(1), pos(2), ch);
        req_counter = req_counter + 1;
        resp = post(baseUrl, '/measure', req, options);
        
        if strcmp(resp.measure_result, 'direction')
            % 记录射线 [x, y, angle]
            rays{ch} = [rays{ch}; pos(1), pos(2), resp.svd_deg];
            fprintf('   [虚拟耗时:%d秒] 测得频道 %d 角度: %.2f°\n', resp.virtual_time_s, ch, resp.svd_deg);
            
            % 数学解算极值误差与交叉坐标
            if size(rays{ch}, 1) >= 2
                [rho, best_pos] = solve_intersection(rays{ch});
                est_pos(ch, :) = best_pos;
                if rho <= 20
                    sources_state(ch) = 3;
                    fprintf('   => 数学解算：包围圆半径 %.1fm <= 20m！已精确定位目标 %d。\n', rho, ch);
                else
                    sources_state(ch) = 2;
                    fprintf('   => 数学解算：包围圆半径 %.1fm > 20m，仅能粗略定位目标 %d。\n', rho, ch);
                end
            else
                sources_state(ch) = max(sources_state(ch), 1);
            end
            
        elseif strcmp(resp.measure_result, 'near')
            % 距离<=5m，可以直接清除！(完美白给)
            est_pos(ch, :) = pos;
            sources_state(ch) = 3;
            fprintf('   [虚拟耗时:%d秒] 频道 %d 信号极强(near)！距目标<=5m，已锁定精确定位！\n', resp.virtual_time_s, ch);
        end
    end

    function [best_rho, best_intersection] = solve_intersection(channel_rays)
        % 根据多条射线，利用正弦定理和 1° 极值误差计算最小包围圆半径
        k = size(channel_rays, 1);
        best_rho = inf;
        best_intersection = [0, 0];
        angle_err = 1 * pi / 180;
        
        for i = 1:k
            for j = (i+1):k
                p1 = channel_rays(i, 1:2); ang1 = channel_rays(i, 3) * pi/180;
                p2 = channel_rays(j, 1:2); ang2 = channel_rays(j, 3) * pi/180;
                
                % 转换角度为极坐标系下的矢量 (与数学题目的极坐标系一致)
                % 注意：如果角度定义是北向为Y轴正方向、东向为X轴正方向
                % 那么顺时针/逆时针要根据题目。题设是“X轴正向逆时针旋转至目标”，所以角度是极角
                v1 = [cos(ang1), sin(ang1)];
                v2 = [cos(ang2), sin(ang2)];
                
                cos_alpha = dot(v1, v2);
                sin_alpha = sqrt(1 - cos_alpha^2);
                
                if sin_alpha < 0.17 % 夹角太小(共线)，直接舍弃
                    continue;
                end
                
                % 两点射线交点 (直线方程解算)
                A = [v1(2), -v1(1); v2(2), -v2(1)];
                b = [p1(1)*v1(2) - p1(2)*v1(1); p2(1)*v2(2) - p2(2)*v2(1)];
                if rcond(A) < 1e-10; continue; end
                inter_pt = (A \ b)';
                
                d1 = norm(p1 - inter_pt);
                d2 = norm(p2 - inter_pt);
                
                % 防射线反向交会判断：交点必须位于探测点射线的前方
                if dot(inter_pt - p1, v1) < 0 || dot(inter_pt - p2, v2) < 0
                    continue;
                end
                
                % 误差圆计算
                rho = (max(d1, d2) * angle_err) / sin_alpha;
                if rho < best_rho
                    best_rho = rho;
                    best_intersection = inter_pt;
                end
            end
        end
    end

    function request = baseRequest(robotId, requestId)
        request = struct('arena_id', 'default', 'robot_id', robotId, 'request_id', requestId);
    end

    function request = actionRequest(robotId, requestId, x, y, channel)
        request = baseRequest(robotId, requestId);
        request.position = struct('x', x, 'y', y);
        request.channel = channel;
    end

    function response = post(baseUrl, path, payload, options)
        % 静默重试机制防脱机
        max_retries = 3;
        for r = 1:max_retries
            try
                response = webwrite([baseUrl path], payload, options);
                return;
            catch e
                if r == max_retries
                    rethrow(e);
                end
                pause(0.5);
            end
        end
    end
end
