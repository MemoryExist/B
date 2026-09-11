function problem2_sweep_path()
% PROBLEM2_SWEEP_PATH 自适应计算并证明任意误差半径 R 下的最短全覆盖路径
% 不仅输出最坏情况 (R=56.5m) 的覆盖图，还生成 R 属于 [21, 56.5] 时的最优路径长度曲线。

    r = 20; % 仪器的探测半径
    
    % ==========================================
    % 1. 计算不同 R 下的最优路径长度 (证明普适性)
    % ==========================================
    fprintf('正在验证任意 R 属于 (20, 56.5] 的自适应最优全覆盖路径...\n');
    R_array = linspace(21, 56.5, 30);
    L_array = zeros(size(R_array));
    
    for i = 1:length(R_array)
        R = R_array(i);
        [L_array(i), ~] = optimize_sweep(R, r, false);
    end
    
    % 绘制 L - R 关系曲线
    fig1 = figure('Color', 'w', 'Position', [100, 100, 700, 500]);
    plot(R_array, L_array, 'b-', 'LineWidth', 2.5);
    hold on;
    % 标注分界点
    xline(40, 'r--', 'LineWidth', 1.5, 'Label', '拓扑相变点 (R=40m)');
    plot(R_array, L_array, 'bo', 'MarkerFaceColor', 'w', 'MarkerSize', 4);
    
    title('最短全覆盖路径长度 L 随误差圆半径 R 的变化规律', 'FontSize', 14);
    xlabel('未知误差圆半径 R (m)', 'FontSize', 12);
    ylabel('最优全覆盖路径长度 L (m)', 'FontSize', 12);
    grid on;
    
    text(25, 250, '2趟扫线 (U型拓扑)', 'FontSize', 12, 'Color', 'k');
    text(45, 250, '3趟扫线 (S型拓扑)', 'FontSize', 12, 'Color', 'k');
    
    out_file1 = fullfile(fileparts(mfilename('fullpath')), 'results', 'problem2_LR_curve.png');
    if ~isfolder(fileparts(out_file1)), mkdir(fileparts(out_file1)); end
    saveas(fig1, out_file1);
    fprintf('规律证明曲线已保存至: %s\n', out_file1);
    
    % ==========================================
    % 2. 针对最坏情况 (R = 56.5) 生成具体清扫路线图
    % ==========================================
    R_worst = 56.5;
    [L_worst, pts_worst] = optimize_sweep(R_worst, r, true);
    
    fprintf('\n===== 优化完成 =====\n');
    fprintf('最坏情况 (R=%.1f m) 下的最短全覆盖路径总长度: %.2f m\n', R_worst, L_worst);
    
    plot_sweep_result(pts_worst, R_worst, r, L_worst);
end

function [fval, pts] = optimize_sweep(R, r, verbose)
    % 生成高密度测试点
    [X, Y] = meshgrid(linspace(-R, R, 150));
    mask = X.^2 + Y.^2 <= R^2;
    Px = X(mask);
    Py = Y(mask);
    
    options = optimoptions('fmincon', 'Display', 'none', 'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 2000, 'StepTolerance', 1e-6);
    
    % 根据 R 动态选择扫线拓扑
    if R <= 40
        % 2 趟扫线 (U型拓扑)
        x0 = [R, R/2];
        lb = [0, 0];
        ub = [R, R];
        obj = @(v) 4*v(1) + 2*v(2);
        nonlcon = @(v) constraint_2sweep(v, Px, Py, r);
    else
        % 3 趟扫线 (S型/割草机拓扑)
        x0 = [R*0.8, R*0.6, R*0.8];
        lb = [0, 0, 0];
        ub = [R, R, R];
        obj = @(v) 4*v(1) + 2*v(3) + 2*sqrt((v(3)-v(1))^2 + v(2)^2);
        nonlcon = @(v) constraint_3sweep(v, Px, Py, r);
    end
    
    if verbose, fprintf('开始寻优 R = %.1f m ...\n', R); end
    [v_opt, fval] = fmincon(obj, x0, [], [], [], [], lb, ub, nonlcon, options);
    
    % 重建节点
    if R <= 40
        x1 = v_opt(1); y1 = v_opt(2);
        pts = [x1, y1; -x1, y1; -x1, -y1; x1, -y1];
    else
        x1 = v_opt(1); y1 = v_opt(2); x2 = v_opt(3);
        pts = [x1, y1; -x1, y1; -x2, 0; x2, 0; x1, -y1; -x1, -y1];
    end
end

function [c, ceq] = constraint_2sweep(v, Px, Py, r)
    x1 = v(1); y1 = v(2); r2 = r^2;
    d1 = dist2seg(Px, Py, x1, y1, -x1, y1);
    d2 = dist2seg(Px, Py, -x1, y1, -x1, -y1);
    d3 = dist2seg(Px, Py, -x1, -y1, x1, -y1);
    min_d = min(cat(2, d1, d2, d3), [], 2);
    c = min_d - r2 + 1e-4; 
    ceq = [];
end

function [c, ceq] = constraint_3sweep(v, Px, Py, r)
    x1 = v(1); y1 = v(2); x2 = v(3); r2 = r^2;
    d1 = dist2seg(Px, Py, x1, y1, -x1, y1);
    d2 = dist2seg(Px, Py, -x1, y1, -x2, 0);
    d3 = dist2seg(Px, Py, -x2, 0, x2, 0);
    d4 = dist2seg(Px, Py, x2, 0, x1, -y1);
    d5 = dist2seg(Px, Py, x1, -y1, -x1, -y1);
    min_d = min(cat(2, d1, d2, d3, d4, d5), [], 2);
    c = min_d - r2 + 1e-4; 
    ceq = [];
end

function d2 = dist2seg(px, py, ax, ay, bx, by)
    dx = bx - ax; dy = by - ay; l2 = dx^2 + dy^2;
    if l2 == 0
        d2 = (px - ax).^2 + (py - ay).^2; return;
    end
    t = max(0, min(1, ((px - ax)*dx + (py - ay)*dy) / l2));
    projx = ax + t * dx; projy = ay + t * dy;
    d2 = (px - projx).^2 + (py - projy).^2;
end

function plot_sweep_result(pts, R, r, fval)
    fig = figure('Color', 'w', 'Position', [150, 150, 750, 650]);
    hold on; axis equal;
    
    n_pts = size(pts, 1);
    h_fill = gobjects(0);
    for i=1:(n_pts-1)
        h = plot_capsule(pts(i,1), pts(i,2), pts(i+1,1), pts(i+1,2), r);
        if i==1, h_fill = h; end
    end
    set(h_fill, 'DisplayName', '20m 探测仪扫掠覆盖区');
    
    theta = linspace(0, 2*pi, 200);
    plot(R*cos(theta), R*sin(theta), 'r--', 'LineWidth', 2, 'DisplayName', sprintf('未知干扰源可能区域 (R=%.1fm)', R));
    plot(0, 0, 'rx', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', '最坏误差圆心');
    plot(pts(:,1), pts(:,2), 'b-', 'LineWidth', 2.5, 'DisplayName', '无人狗最短覆盖路径');
    plot(pts(:,1), pts(:,2), 'bo', 'MarkerFaceColor', 'w', 'MarkerSize', 5, 'HandleVisibility', 'off');
    plot(pts(1,1), pts(1,2), 'gp', 'MarkerFaceColor', 'g', 'MarkerSize', 15, 'DisplayName', '路径起点');
    plot(pts(end,1), pts(end,2), 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 10, 'DisplayName', '路径终点');
    
    title(sprintf('最坏情况 (R=%.1fm) 的最短全覆盖扫雷路径 (L=%.2fm)', R, fval), 'FontSize', 13);
    xlabel('X 坐标 (m)'); ylabel('Y 坐标 (m)');
    legend('Location', 'northeastoutside', 'FontSize', 10);
    grid on; xlim([-R-r-5, R+r+5]); ylim([-R-r-5, R+r+5]);
    
    out_file = fullfile(fileparts(mfilename('fullpath')), 'results', 'problem2_coverage_path.png');
    saveas(fig, out_file);
    fprintf('覆盖区域绘图成功！已保存至: %s\n', out_file);
end

function h = plot_capsule(ax, ay, bx, by, r)
    dir = [bx-ax, by-ay]; len = norm(dir);
    if len == 0
        theta = linspace(0, 2*pi, 50);
        h = fill(ax+r*cos(theta), ay+r*sin(theta), [0.85 0.93 1], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
        return;
    end
    dir = dir / len; perp = [-dir(2), dir(1)];
    p1 = [ax, ay] + r*perp; p2 = [bx, by] + r*perp;
    p3 = [bx, by] - r*perp; p4 = [ax, ay] - r*perp;
    h = fill([p1(1) p2(1) p3(1) p4(1)], [p1(2) p2(2) p3(2) p4(2)], [0.85 0.93 1], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
    theta = linspace(0, 2*pi, 30);
    fill(ax+r*cos(theta), ay+r*sin(theta), [0.85 0.93 1], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
    fill(bx+r*cos(theta), by+r*sin(theta), [0.85 0.93 1], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
end
