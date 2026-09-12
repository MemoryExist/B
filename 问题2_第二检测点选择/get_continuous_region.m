% get_continuous_region.m
% 读取 results/out.mat，利用真实的评价函数 eval_P_bounds 在候选点附近进行密集网格采样，
% 从而找出严格满足精度容差 (U(P) <= m_hat + epsilon) 的连续可行区域，并绘制热力图。
% 输出两张图：局部图（fig4_continuous_region_local.png）和全局图（fig4_continuous_region_global.png）

function get_continuous_region()
    root = fileparts(mfilename('fullpath'));
    old = pwd; cleanup = onCleanup(@() cd(old));
    cd(root); addpath(genpath(root));
    
    fprintf('正在加载结果数据...\n');
    load('results/out.mat', 'out', 'cfg');
    
    P_fines = [out.fines.P];
    Q = P_fines(:, out.near_indices);
    
    % 目标阈值
    threshold = out.m_hat + cfg.tau_m;
    fprintf('真实的最优上界基准 m_hat = %.4f m\n', out.m_hat);
    fprintf('寻找满足 U(P) <= %.4f m (m_hat + %.1f) 的连续区域\n', threshold, cfg.tau_m);
    
    cfg.kill_threshold = threshold;
    cfg.eval_tol = cfg.tol_fine;
    cfg.eval_budget = 400;
    
    [Eb,~] = E_polygon(cfg);
    
    % ================= 1. 局部图计算 =================
    if out.P_f2(2) > 0
        Q_local = Q(:, Q(2,:) > 0);
    else
        Q_local = Q(:, Q(2,:) < 0);
    end
    
    margin_l = 15;
    min_x_l = min(Q_local(1,:)) - margin_l; max_x_l = max(Q_local(1,:)) + margin_l;
    min_y_l = min(Q_local(2,:)) - margin_l; max_y_l = max(Q_local(2,:)) + margin_l;
    
    grid_size_l = 50;
    x_vec_l = linspace(min_x_l, max_x_l, grid_size_l);
    y_vec_l = linspace(min_y_l, max_y_l, grid_size_l);
    [X_l, Y_l] = meshgrid(x_vec_l, y_vec_l);
    Z_U_l = NaN(size(X_l));
    
    fprintf('开始对局部的 %dx%d 网格进行严密计算...\n', grid_size_l, grid_size_l);
    tic;
    for i = 1:numel(X_l)
        P_test = [X_l(i); Y_l(i)];
        if ~inpolygon(P_test(1), P_test(2), Eb(1,:), Eb(2,:)), continue; end
        res = eval_P_bounds(P_test, cfg);
        Z_U_l(i) = res.U;
    end
    fprintf('局部网格计算完成，耗时 %.2f 秒。\n', toc);
    
    % ================= 2. 全局图计算 =================
    margin_g = 15;
    min_x_g = min(Eb(1,:)) - margin_g; max_x_g = max(Eb(1,:)) + margin_g;
    min_y_g = min(Eb(2,:)) - margin_g; max_y_g = max(Eb(2,:)) + margin_g;
    
    grid_size_g = 60;
    x_vec_g = linspace(min_x_g, max_x_g, grid_size_g);
    y_vec_g = linspace(min_y_g, max_y_g, grid_size_g);
    [X_g, Y_g] = meshgrid(x_vec_g, y_vec_g);
    Z_U_g = NaN(size(X_g));
    
    fprintf('开始对全局的 %dx%d 网格进行严密计算...\n', grid_size_g, grid_size_g);
    tic;
    for i = 1:numel(X_g)
        P_test = [X_g(i); Y_g(i)];
        if ~inpolygon(P_test(1), P_test(2), Eb(1,:), Eb(2,:)), continue; end
        res = eval_P_bounds(P_test, cfg);
        Z_U_g(i) = res.U;
    end
    fprintf('全局网格计算完成，耗时 %.2f 秒。\n', toc);
    
    levels = linspace(out.m_hat, threshold, 6);
    
    % ================= 绘制局部图 =================
    fl = figure('Color', 'w', 'Position', [100 100 850 650], 'Visible', 'off');
    hold on;
    contourf(X_l, Y_l, Z_U_l, levels, 'LineStyle', 'none');
    colormap(flipud(parula));
    colorbar('Ticks', levels, 'TickLabels', arrayfun(@(x) sprintf('%.2f', x), levels, 'UniformOutput', false));
    [~, h_cl] = contour(X_l, Y_l, Z_U_l, [threshold, threshold], 'LineColor', 'r', 'LineWidth', 2, 'DisplayName', 'Optimal Region Boundary');
    plot(Eb(1,:), Eb(2,:), 'k.', 'MarkerSize', 2, 'DisplayName', 'Region E Boundary');
    scatter(Q(1,:), Q(2,:), 40, 'mo', 'filled', 'MarkerEdgeColor', 'w', 'DisplayName', 'Discrete Candidates');
    plot(out.P_f2(1), out.P_f2(2), 'wp', 'MarkerSize', 14, 'MarkerFaceColor', 'r', 'DisplayName', 'Selected Point P');
    axis equal; grid on;
    xlim([min_x_l, max_x_l]); ylim([min_y_l, max_y_l]);
    xlabel('x (m)'); ylabel('y (m)');
    legend('Location', 'best');
    
    save_path_l = fullfile(cfg.fig_dir, 'fig4_continuous_region_local.png');
    exportgraphics(fl, save_path_l, 'Resolution', 250, 'BackgroundColor', 'white');
    close(fl);
    
    % ================= 绘制全局图 =================
    fg = figure('Color', 'w', 'Position', [200 200 850 650], 'Visible', 'off');
    hold on;
    contourf(X_g, Y_g, Z_U_g, levels, 'LineStyle', 'none');
    colormap(flipud(parula));
    colorbar('Ticks', levels, 'TickLabels', arrayfun(@(x) sprintf('%.2f', x), levels, 'UniformOutput', false));
    [~, h_cg] = contour(X_g, Y_g, Z_U_g, [threshold, threshold], 'LineColor', 'r', 'LineWidth', 2, 'DisplayName', 'Optimal Region Boundary');
    plot(Eb(1,:), Eb(2,:), 'k-', 'LineWidth', 1.5, 'DisplayName', 'Region E Boundary');
    scatter(Q(1,:), Q(2,:), 20, 'mo', 'filled', 'MarkerEdgeColor', 'w', 'DisplayName', 'Discrete Candidates');
    
    plot(out.P_f2(1), out.P_f2(2), 'wp', 'MarkerSize', 14, 'MarkerFaceColor', 'r', 'DisplayName', 'Selected Point P');
    plot(out.P_f2(1), -out.P_f2(2), 'wp', 'MarkerSize', 14, 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');
    
    axis equal; grid on;
    xlim([min_x_g, max_x_g]); ylim([min_y_g, max_y_g]);
    xlabel('x (m)'); ylabel('y (m)');
    legend('Location', 'best');
    
    save_path_g = fullfile(cfg.fig_dir, 'fig4_continuous_region_global.png');
    exportgraphics(fg, save_path_g, 'Resolution', 250, 'BackgroundColor', 'white');
    close(fg);
    
    fprintf('已将全局和局部的连续区域分布图保存至 figures 目录\n');
end
