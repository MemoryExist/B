function plot_problem2(cfg, out, V)
%PLOT_PROBLEM2 结果图: 概览 / 最坏区域 / 近似热图 / 收敛曲线 / 多边形分辨率 / 密采样核验
set(0, 'DefaultAxesFontSize', 11);
figdir = cfg.fig_dir;
mkdir(figdir);
[Db, W] = D_region(cfg);
[Eb, bb] = E_polygon(cfg);
st = out.statuses;
% 精评点坐标
fineP = reshape([out.fines.P], 2, [])';
isFine = false(1, numel(st));
for i = 1:numel(st)
    if strcmp(st{i}, 'converged') || strcmp(st{i}, 'budget')
        for k = 1:size(fineP, 1)
            if norm(out.Pcand(:, i) - fineP(k, :)') < 1e-3
                isFine(i) = true;
            end
        end
    end
end

% ---- fig1 概览: D / E / 候选点状态 / 最终选择 ----
f1 = figure('Color', 'w', 'Position', [60 60 920 700]); hold on;
hfill = fill(Db(1, :), Db(2, :), [0.86 0.93 1], 'EdgeColor', 'none');
hEb = plot(Eb(1, :), Eb(2, :), 'k.', 'MarkerSize', 3);
hW = plot(W(1, :), W(2, :), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 4);
% 按状态分组绘制(用 NaN 代理句柄保证图例对齐)
cat1 = []; cat2 = []; cat3 = []; cat4 = []; cat5 = [];
for i = 1:numel(st)
    p = out.Pcand(:, i);
    switch st{i}
        case 'not_evaluated', cat1 = [cat1, p]; %#ok<AGROW>
        case 'pair_pruned',   cat2 = [cat2, p]; %#ok<AGROW>
        case 'pruned',        cat3 = [cat3, p]; %#ok<AGROW>
        otherwise
            if isFine(i), cat4 = [cat4, p]; else, cat5 = [cat5, p]; end %#ok<AGROW>
    end
end
if isempty(cat1), h1 = plot(nan, nan, '.', 'Color', [0.75 0.75 0.75], 'MarkerSize', 6);
else, h1 = plot(cat1(1, :), cat1(2, :), '.', 'Color', [0.75 0.75 0.75], 'MarkerSize', 6); end
if isempty(cat2), h2 = plot(nan, nan, 'x', 'Color', [0.9 0.4 0.2], 'MarkerSize', 7, 'LineWidth', 1.2);
else, h2 = plot(cat2(1, :), cat2(2, :), 'x', 'Color', [0.9 0.4 0.2], 'MarkerSize', 7, 'LineWidth', 1.2); end
if isempty(cat3), h3 = plot(nan, nan, 'x', 'Color', [0.95 0.6 0.1], 'MarkerSize', 7, 'LineWidth', 1.2);
else, h3 = plot(cat3(1, :), cat3(2, :), 'x', 'Color', [0.95 0.6 0.1], 'MarkerSize', 7, 'LineWidth', 1.2); end
if isempty(cat4), h4 = plot(nan, nan, 'o', 'Color', [0 0.45 0.85], 'MarkerSize', 8, 'MarkerFaceColor', [0 0.45 0.85]);
else, h4 = plot(cat4(1, :), cat4(2, :), 'o', 'Color', [0 0.45 0.85], 'MarkerSize', 8, 'MarkerFaceColor', [0 0.45 0.85]); end
if isempty(cat5), h5 = plot(nan, nan, 'o', 'Color', [0.45 0.7 0.95], 'MarkerSize', 6);
else, h5 = plot(cat5(1, :), cat5(2, :), 'o', 'Color', [0.45 0.7 0.95], 'MarkerSize', 6); end
h6 = plot(out.P_hat(1), out.P_hat(2), 's', 'Color', [0.1 0.6 0.1], 'MarkerSize', 12, 'LineWidth', 2);
h7 = plot(out.P_best(1), out.P_best(2), 'p', 'Color', [0.85 0 0], 'MarkerSize', 18, 'MarkerFaceColor', [0.95 0.3 0.3]);
h8 = plot(out.P_f2(1), out.P_f2(2), 'd', 'Color', [0.75 0 0.75], 'MarkerSize', 12, 'LineWidth', 2);
h9 = plot(0, 0, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
quiver(0, 0, 400, 0, 0, 'k-', 'LineWidth', 1.5);
% 弦下界圆盘 C
C0 = [cfg.Lmax / (1 + sin(cfg.delta)); 0];
rs = cfg.Lmax * sin(cfg.delta) / (1 + sin(cfg.delta));
th = linspace(0, 2 * pi, 200);
plot(C0(1) + rs * cos(th), C0(2) + rs * sin(th), '--', 'Color', [0.4 0.4 0.4]);
legend([hfill, hEb, hW, h1, h2, h3, h5, h4, h6, h7, h8, h9], ...
    {'D 源可行域', 'E 边界', '见证点', '未评价', '点对下界排除', '提前淘汰', ...
    '粗评', '精评', '仅近似指标 P_{hat}', '最优 P_{best}', '距离最优 P_{f2}', 'S1'}, ...
    'Location', 'eastoutside', 'FontSize', 9);
axis equal; grid on;
xlim([-150 1700]); ylim([-800 800]);
xlabel('x (m)'); ylabel('y (m)');
title(sprintf('两阶段选点概览: m_{hat}=%.2f m, P_{best}=(%.0f,%.0f), P_{f2}=(%.0f,%.0f)', ...
    out.m_hat, out.P_best(1), out.P_best(2), out.P_f2(1), out.P_f2(2)));
exportgraphics(f1, fullfile(figdir, 'fig1_overview.png'), 'Resolution', 150);
close(f1);

% ---- fig2 P_best 最坏读数定位区域(内/外多边形 + 包围圆) ----
[~, bi] = min([out.fines.U]);
fb = out.fines(bi);
[polin, flin] = build_J_region(fb.P, fb.worst_beta, cfg.delta, 'inner', cfg);
[polout, flout] = build_J_region(fb.P, fb.worst_beta, cfg.delta, 'outer', cfg);
Vin = cat(2, polin{:});
[cin, rin] = welzl_mec(Vin, cfg);
f2 = figure('Color', 'w', 'Position', [100 100 860 620]); hold on;
for q = 1:numel(polin)
    K = polin{q};
    hv = 'off';
    if q == 1, hv = 'on'; end
    hfill2 = fill(K(1, :), K(2, :), [0.75 0.87 1], 'EdgeColor', 'none', 'HandleVisibility', hv);
end
for q = 1:numel(polout)
    K = polout{q};
    hv = 'off';
    if q == 1, hv = 'on'; end
    hout = plot([K(1, :), K(1, 1)], [K(2, :), K(2, 1)], 'k-', 'LineWidth', 1.2, 'HandleVisibility', hv);
end
th = linspace(0, 2 * pi, 300);
hcirc = plot(cin(1) + rin * cos(th), cin(2) + rin * sin(th), 'r-', 'LineWidth', 2);
hcen = plot(cin(1), cin(2), 'r+', 'MarkerSize', 14, 'LineWidth', 2);
hpb = plot(fb.P(1), fb.P(2), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
hs1 = plot(0, 0, 'k^', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
axis equal; grid on;
xlabel('x (m)'); ylabel('y (m)');
title(sprintf('P_{best}=(%.1f,%.1f) 最坏读数 β=%.3f° 的定位区域: 半径 ∈ [%.3f, %.3f] m', ...
    fb.P(1), fb.P(2), fb.worst_beta_deg, fb.L, fb.U));
legend([hfill2, hout, hcirc, hcen, hpb, hs1], {'内近似区域', '外近似边界', '最小包围圆', '包围圆圆心', 'P_{best}', 'S1'}, ...
    'Location', 'best', 'FontSize', 9);
exportgraphics(f2, fullfile(figdir, 'fig2_worst_region.png'), 'Resolution', 150);
close(f2);

% ---- fig3 f1_hat 热图(仅展示, 非严格评分) ----
nx = 220; ny = 220;
xs = linspace(bb(1), bb(2), nx);
ys = linspace(bb(3), bb(4), ny);
[X, Y] = meshgrid(xs, ys);
PP = [X(:)'; Y(:)'];
ok = in_E(PP, cfg);
Z = nan(size(X));
Zv = zeros(1, size(PP, 2));
for i = 1:size(PP, 2)
    Zv(i) = hat_f1(PP(:, i), cfg);
end
Z(ok) = Zv(ok);
f3 = figure('Color', 'w', 'Position', [140 140 880 640]);
pcolor(X, Y, Z); shading interp; colorbar; hold on;
plot(Eb(1, :), Eb(2, :), 'k.', 'MarkerSize', 2);
plot(out.P_best(1), out.P_best(2), 'rp', 'MarkerSize', 16, 'MarkerFaceColor', 'r');
plot(out.P_hat(1), out.P_hat(2), 'gs', 'MarkerSize', 10, 'LineWidth', 2);
axis equal tight; grid on;
xlabel('x (m)'); ylabel('y (m)');
title('一阶近似指标 f1_{hat} 在 E 上的分布(仅用于排序展示, 非严格评分)');
exportgraphics(f3, fullfile(figdir, 'fig3_hat_heatmap.png'), 'Resolution', 150);
close(f3);

% ---- fig4 收敛曲线(P_best 与 (750,600)) ----
f4 = figure('Color', 'w', 'Position', [180 180 820 560]); hold on;
key = sprintf('%.3f,%.3f', out.P_best(1), out.P_best(2));
rb = out.cache(key);
stairs(rb.log.n, rb.log.U, 'r-', 'LineWidth', 1.4);
stairs(rb.log.n, rb.log.L, 'b-', 'LineWidth', 1.4);
stairs(V.V2.res.log.n, V.V2.res.log.U, 'Color', [0.95 0.6 0.6], 'LineWidth', 1.1);
stairs(V.V2.res.log.n, V.V2.res.log.L, 'Color', [0.6 0.6 0.95], 'LineWidth', 1.1);
xlabel('角度评价次数'); ylabel('半径 (m)'); grid on;
legend({'P_{best} 上界 U', 'P_{best} 下界 L', '(750,600) 上界 U', '(750,600) 下界 L'}, 'Location', 'northeast');
title(sprintf('角度区间自适应细分收敛曲线 (P_{best} gap=%.4f m)', rb.U - rb.L));
exportgraphics(f4, fullfile(figdir, 'fig4_convergence.png'), 'Resolution', 150);
close(f4);

% ---- fig5 多边形分辨率对上下界的影响 ----
f5 = figure('Color', 'w', 'Position', [220 220 720 480]); hold on;
N = V.V6.Nlist;
plot(N, V.V6.LN, 'b-o', 'LineWidth', 1.5);
plot(N, V.V6.UN, 'r-s', 'LineWidth', 1.5);
set(gca, 'XScale', 'log');
xlabel('圆弧多边形边数 N'); ylabel('半径 (m)'); grid on;
legend({'下界 L', '上界 U'}, 'Location', 'best');
title('(750,600) 上下界随圆弧多边形分辨率收紧');
exportgraphics(f5, fullfile(figdir, 'fig5_bounds_vs_N.png'), 'Resolution', 150);
close(f5);

% ---- fig6 密角度采样一致性核验 ----
f6 = figure('Color', 'w', 'Position', [260 260 820 500]); hold on;
g = V.V7.grid;
rho = zeros(1, numel(g));
for i = 1:numel(g)
    rho(i) = region_mec([750; 600], g(i), cfg.delta, 'outer', cfg);
end
plot(rad2deg(g), rho, '.', 'Color', [0.3 0.55 0.85], 'MarkerSize', 4);
yline(V.V6.Us(3), 'r-', 'LineWidth', 1.5);
yline(V.V6.Ls(3), 'b-', 'LineWidth', 1.5);
xlabel('实际读数 β (°)'); ylabel('外近似覆盖半径 (m)'); grid on;
legend({'密采样 ρ^+(β)', sprintf('细分上界 U=%.3f', V.V6.Us(3)), ...
    sprintf('细分下界 L=%.3f', V.V6.Ls(3))}, 'Location', 'best');
title('(750,600) 独立密角度采样核验(密采样仅核验, 非连续角域证明)');
exportgraphics(f6, fullfile(figdir, 'fig6_dense_check.png'), 'Resolution', 150);
close(f6);
fprintf('图已导出至 %s/\n', figdir);
end
