function problem2_discrete_sweep()
% PROBLEM2_DISCRETE_SWEEP 基于 Kershner 定理和集合覆盖规划离散检测点及 TSP 最短路
    
    R = 56.5; % 最坏误差半径
    r = 20;   % 探测半径
    v = 5;    % 移动速度 5m/s (假设)
    t_measure = 5; % 每次测量耗时 5s
    
    fprintf('=== 问题2：离散检测点全覆盖路径规划 ===\n');
    fprintf('误差半径 R = %.1f m, 探测半径 r = %.1f m\n', R, r);
    
    % 1. 离散化被覆盖区域 D(0, R)
    [X, Y] = meshgrid(linspace(-R, R, 150));
    mask = X.^2 + Y.^2 <= R^2;
    Px = X(mask); Py = Y(mask);
    N_target = length(Px);
    
    % 2. 基于 Kershner 正六边形密铺定理生成候选中心
    dx = r * sqrt(3) / 2 * 0.8; 
    dy = r * 3/4 * 0.8;
    [CX, CY] = meshgrid(-R-r:dx:R+r, -R-r:dy:R+r);
    shift = repmat([0, dx/2], size(CX,1), ceil(size(CX,2)/2));
    shift = shift(:, 1:size(CX,2));
    CX = CX + shift;
    
    c_mask = CX.^2 + CY.^2 <= (R+r/4)^2; 
    Cx = CX(c_mask); Cy = CY(c_mask);
    N_cand = length(Cx);
    
    % 3. 构造覆盖矩阵 A
    A = zeros(N_target, N_cand);
    for j = 1:N_cand
        dist2 = (Px - Cx(j)).^2 + (Py - Cy(j)).^2;
        A(:, j) = (dist2 <= r^2);
    end
    
    % 4. 求解最小集合覆盖问题 (Set Cover ILP)
    f = ones(N_cand, 1);
    intcon = 1:N_cand;
    b = -ones(N_target, 1);
    
    options = optimoptions('intlinprog', 'Display', 'off');
    [x_opt, fval, exitflag] = intlinprog(f, intcon, -A, b, [], [], zeros(N_cand,1), ones(N_cand,1), options);
    
    if exitflag > 0
        N_opt = round(fval);
        sel = x_opt > 0.5;
        Sel_X = Cx(sel); Sel_Y = Cy(sel);
        fprintf('成功求得最小检测点数量: %d 个\n', N_opt);
        
        pts = [Sel_X, Sel_Y];
        
        % 5. 求解 TSP 遍历最短路径 (贪心 + 2-opt)
        start_pt = [0, 0];
        [tour_idx, tour_dist] = solve_tsp(pts, start_pt);
        
        total_time = N_opt * t_measure + tour_dist / v;
        fprintf('TSP 最短行走距离: %.2f m\n', tour_dist);
        fprintf('预估总耗时 (含 %d 次停机检测): %.2f s\n', N_opt, total_time);
        
        % 6. 可视化绘图
        plot_discrete_coverage(R, r, pts, tour_idx, start_pt, tour_dist, N_opt);
    else
        fprintf('ILP 求解失败，无法找到全覆盖子集。\n');
    end
end

function [best_tour, best_dist] = solve_tsp(pts, start_pt)
    N = size(pts, 1);
    unvisited = 1:N;
    curr = start_pt;
    tour = [];
    dist = 0;
    
    % 贪心初始化
    while ~isempty(unvisited)
        [~, idx] = min(sum((pts(unvisited,:) - curr).^2, 2));
        next = unvisited(idx);
        dist = dist + norm(pts(next,:) - curr);
        tour(end+1) = next;
        curr = pts(next,:);
        unvisited(idx) = [];
    end
    
    % 简单的 2-opt 优化
    improved = true;
    while improved
        improved = false;
        for i = 1:N-2
            for j = i+2:N
                new_tour = tour;
                new_tour(i+1:j) = wrev(tour(i+1:j)); % 逆序子路径
                new_dist = calc_tour_dist(new_tour, pts, start_pt);
                if new_dist < dist - 1e-5
                    tour = new_tour;
                    dist = new_dist;
                    improved = true;
                end
            end
        end
    end
    best_tour = tour;
    best_dist = dist;
end

function rev = wrev(arr)
    rev = arr(end:-1:1);
end

function d = calc_tour_dist(tour, pts, start_pt)
    d = norm(pts(tour(1),:) - start_pt);
    for i = 1:length(tour)-1
        d = d + norm(pts(tour(i+1),:) - pts(tour(i),:));
    end
end

function plot_discrete_coverage(R, r, pts, tour_idx, start_pt, tour_dist, N_opt)
    fig = figure('Color', 'w', 'Position', [150, 150, 750, 700]);
    hold on; axis equal;
    
    % 画目标误差圆
    theta = linspace(0, 2*pi, 200);
    plot(R*cos(theta), R*sin(theta), 'r--', 'LineWidth', 2, 'DisplayName', sprintf('最坏误差圆 (R=%.1fm)', R));
    
    % 画起点
    plot(start_pt(1), start_pt(2), 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 15, 'DisplayName', '假定第二观测点(起点)');
    
    % 画检测点的探测范围
    h_circle = gobjects(0);
    for i = 1:N_opt
        h = fill(pts(i,1)+r*cos(theta), pts(i,2)+r*sin(theta), [0.3 0.6 0.9], 'EdgeColor', 'b', 'FaceAlpha', 0.2, 'HandleVisibility', 'off');
        if i==1, h_circle = h; end
    end
    set(h_circle, 'DisplayName', '20m 探测覆盖区');
    
    % 画 TSP 路径
    path_pts = [start_pt; pts(tour_idx, :)];
    plot(path_pts(:,1), path_pts(:,2), 'm-', 'LineWidth', 2.5, 'DisplayName', '无人狗遍历检测路线');
    
    % 标记检测点序号
    plot(pts(:,1), pts(:,2), 'mo', 'MarkerFaceColor', 'm', 'MarkerSize', 8, 'HandleVisibility', 'off');
    for i = 1:N_opt
        text(pts(tour_idx(i),1)+2, pts(tour_idx(i),2)+2, num2str(i), 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12);
    end
    
    title(sprintf('基于正六边形密铺的最优离散检测点全覆盖路径\n(最少停机检测点: %d 个, 路线长度: %.2f m)', N_opt, tour_dist), 'FontSize', 13);
    xlabel('X 坐标 (m)'); ylabel('Y 坐标 (m)');
    legend('Location', 'northeastoutside', 'FontSize', 10);
    grid on; xlim([-R-r-5, R+r+5]); ylim([-R-r-5, R+r+5]);
    
    out_file = fullfile(fileparts(mfilename('fullpath')), 'results', 'problem2_discrete_coverage.png');
    saveas(fig, out_file);
    fprintf('绘图成功！已保存至: %s\n', out_file);
end
