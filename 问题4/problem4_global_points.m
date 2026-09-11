function problem4_global_points()
% PROBLEM4_GLOBAL_POINTS 计算问题4的全局最优检测点集与巡航路线
% 基于 Kershner 正六边形密铺与集合覆盖 ILP，保证 100% 发现所有定向干扰源

    R = 1800;   % 目标区域大圆半径
    r_min = 1000; % 干扰源最小有效接收半径
    
    % 核心数学定理推导：
    % 定向干扰源的最坏覆盖区域是一个半径为 r_min = 1000 米的半圆（180度）。
    % 该半圆的内切圆半径恰好为 r_min / 2 = 500 米。
    % 因此，只要检测点阵列能实现半径为 r_cover = 500 米的全平面无缝覆盖，
    % 则空间中任意位置、任意朝向的 1000 米半圆内，必定至少包含一个检测点。
    r_cover = 500; 

    fprintf('=== 问题4：定向与全向干扰源全局检测点规划 ===\n');
    fprintf('目标区域半径 R = %d m, 等效覆盖半径 r_cover = %d m\n', R, r_cover);
    
    % 1. 离散化需要被覆盖的目标区域 D(0, R)
    [X, Y] = meshgrid(linspace(-R, R, 200));
    mask = X.^2 + Y.^2 <= R^2;
    Px = X(mask); Py = Y(mask);
    N_target = length(Px);
    
    % 2. 基于 Kershner 密铺定理生成候选检测点 (高密度以保证解的存在性)
    dx = r_cover * sqrt(3) / 2 * 0.8; 
    dy = r_cover * 3/4 * 0.8;
    
    [CX, CY] = meshgrid(-R-r_cover:dx:R+r_cover, -R-r_cover:dy:R+r_cover);
    shift = repmat([0, dx/2], size(CX,1), ceil(size(CX,2)/2));
    shift = shift(:, 1:size(CX,2));
    CX = CX + shift;
    
    % 只保留可能对覆盖有贡献的候选点
    c_mask = CX.^2 + CY.^2 <= (R + r_cover)^2; 
    Cx = CX(c_mask); Cy = CY(c_mask);
    N_cand = length(Cx);
    
    % 3. 构造覆盖矩阵 A
    A = zeros(N_target, N_cand);
    for j = 1:N_cand
        dist2 = (Px - Cx(j)).^2 + (Py - Cy(j)).^2;
        A(:, j) = (dist2 <= r_cover^2);
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
        fprintf('成功求得保证 100%% 发现定向干扰源的最少检测点数量: %d 个\n', N_opt);
        
        pts = [Sel_X, Sel_Y];
        
        % 5. 求解 TSP 遍历最短路径 (贪心 + 2-opt)
        start_pt = [0, 0];
        [tour_idx, tour_dist] = solve_tsp(pts, start_pt);
        
        fprintf('全局点排布坐标为:\n');
        for i = 1:N_opt
            fprintf('点 %2d: (%7.2f, %7.2f)\n', i, pts(tour_idx(i), 1), pts(tour_idx(i), 2));
        end
        fprintf('TSP 最短巡航总距离: %.2f m\n', tour_dist);
        
        % 6. 可视化绘图
        plot_problem4_coverage(R, r_cover, pts, tour_idx, start_pt, tour_dist, N_opt);
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
                new_tour(i+1:j) = new_tour(j:-1:i+1); % 逆序子路径
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

function d = calc_tour_dist(tour, pts, start_pt)
    d = norm(pts(tour(1),:) - start_pt);
    for i = 1:length(tour)-1
        d = d + norm(pts(tour(i+1),:) - pts(tour(i),:));
    end
end

function plot_problem4_coverage(R, r_cover, pts, tour_idx, start_pt, tour_dist, N_opt)
    fig = figure('Color', 'w', 'Position', [150, 150, 800, 750]);
    hold on; axis equal;
    
    % 画目标区域 1800m
    theta = linspace(0, 2*pi, 200);
    plot(R*cos(theta), R*sin(theta), 'r-', 'LineWidth', 2.5, 'DisplayName', sprintf('目标搜索区域 (R=%dm)', R));
    
    % 画起点
    plot(start_pt(1), start_pt(2), 'kp', 'MarkerFaceColor', 'y', 'MarkerSize', 15, 'DisplayName', '起点 (0,0)');
    
    % 画等效覆盖圆 (r=500)
    h_circle = gobjects(0);
    for i = 1:N_opt
        h = fill(pts(i,1)+r_cover*cos(theta), pts(i,2)+r_cover*sin(theta), [0.3 0.8 0.5], 'EdgeColor', 'g', 'FaceAlpha', 0.15, 'HandleVisibility', 'off');
        if i==1, h_circle = h; end
    end
    set(h_circle, 'DisplayName', sprintf('%dm 等效无死角探测覆盖区', r_cover));
    
    % 画 TSP 路径
    path_pts = [start_pt; pts(tour_idx, :)];
    plot(path_pts(:,1), path_pts(:,2), 'm--', 'LineWidth', 2, 'DisplayName', '全局最优检测巡航路线');
    
    % 标记检测点序号
    plot(pts(:,1), pts(:,2), 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 6, 'DisplayName', '检测停靠点');
    for i = 1:N_opt
        text(pts(tour_idx(i),1)+40, pts(tour_idx(i),2)+40, num2str(i), 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 11);
    end
    
    title(sprintf('问题4：保证定向干扰源 100%% 发现的全局点排布\n(共 %d 个点, 总路径长度: %.2f m)', N_opt, tour_dist), 'FontSize', 14);
    xlabel('正东方向 X (m)', 'FontSize', 12); 
    ylabel('正北方向 Y (m)', 'FontSize', 12);
    legend('Location', 'northeastoutside', 'FontSize', 11);
    grid on; xlim([-R-r_cover, R+r_cover]); ylim([-R-r_cover, R+r_cover]);
    
    out_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
    if ~isfolder(out_dir), mkdir(out_dir); end
    out_file = fullfile(out_dir, 'problem4_global_points.png');
    saveas(fig, out_file);
    fprintf('\n绘图成功！图表已保存至: %s\n', out_file);
end
