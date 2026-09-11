function V = verify_problem2()
%VERIFY_PROBLEM2 问题二完整验证套件
%   1. 最小包围圆基础测试(单点/两点/共线/等边三角形/圆上点/重复/近共线/随机对拍)
%   2. 标准候选点 P=(750,600) 回归(参考值 ≈59.3 米, 给出上下界)
%   3. 角度周期性与跨 0/360° 情形
%   4. 近共线情形 P=(750,0)(真实区域受 D 限制有界)
%   5. 空交 / 正常观测 / 近距离饱和分支区分
%   6. 上下界随精度与多边形分辨率收紧 + 随机确定性
%   7. 独立密角度采样一致性核验(不是连续角域证明)
%   8. 一阶近似模型核对(平行四边形覆盖半径交叉验证 + ρ_hat 凸性数值检验)
%   9. E 四圆盘刻画与 D 见证点合法性核对
%   结果保存至 results/verify_results.mat, 返回结构体 V
root = fileparts(mfilename('fullpath'));
proj = fileparts(root);
cd(proj);
addpath(genpath(proj));
cfg = config_problem2();
mkdir(cfg.results_dir); mkdir(cfg.fig_dir);
rng(cfg.seed);
t0 = tic;
npass = 0; nfail = 0;
fails = {};

    function check(cond, name, detail)
        if cond
            npass = npass + 1;
            fprintf('  [PASS] %s%s\n', name, detail);
        else
            nfail = nfail + 1;
            fails{end+1} = name; %#ok<AGROW>
            fprintf('  [FAIL] %s%s\n', name, detail);
        end
    end

fprintf('========== V1 最小包围圆基础测试 ==========\n');
check_close = @(a, b, tol, msg) check(abs(a - b) <= tol, msg, sprintf('  (值 %.9f vs %.9f)', a, b));
[c, r] = welzl_mec([1; 2], cfg);
check_close(norm(c - [1; 2]), 0, 1e-12, 'V1.1 单点圆心'); check_close(r, 0, 1e-12, 'V1.1 单点半径');
[c, r] = welzl_mec([0 4; 0 0], cfg);
check_close(norm(c - [2; 0]), 0, 1e-9, 'V1.2 两点圆心'); check_close(r, 2, 1e-9, 'V1.2 两点半径');
[c, r] = welzl_mec([0 2 3; 0 0 0], cfg);
check_close(norm(c - [1.5; 0]), 0, 1e-9, 'V1.3 共线三点圆心'); check_close(r, 1.5, 1e-9, 'V1.3 共线三点半径');
[c, r] = welzl_mec([0 2 1; 0 0 sqrt(3)], cfg);
check_close(norm(c - [1; sqrt(3)/3]), 0, 1e-9, 'V1.4 等边三角形圆心');
check_close(r, 2/sqrt(3), 1e-9, 'V1.4 等边三角形半径');
th = linspace(0, 2*pi, 21); th(end) = [];
Pc = [3; -2] + 5*[cos(th); sin(th)];
[c, r] = welzl_mec(Pc, cfg);
check_close(norm(c - [3; -2]), 0, 1e-9, 'V1.5 圆上点圆心');
check_close(r, 5, 1e-9, 'V1.5 圆上点半径');
[c, r] = welzl_mec(repmat([1; 1], 1, 3), cfg);
check_close(r, 0, 1e-12, 'V1.6 重复点半径');
[c, r] = welzl_mec([0 1 2; 0 0 1e-9], cfg);
check_close(r, 1, 1e-6, 'V1.7 近共线点半径');
check(all(sqrt(sum(([0 1 2; 0 0 1e-9] - c).^2, 1)) <= r + 1e-9), 'V1.7 近共线点覆盖', '');
% 随机对拍(枚举所有 ≤3 点子集的覆盖圆取最小)
rng(cfg.seed + 7);
Q = 30 * randn(2, 10);
br = brute_mec(Q);
[c, r] = welzl_mec(Q, cfg);
check_close(r, br, 1e-8, 'V1.8 随机 10 点对拍半径');
check(all(sqrt(sum((Q - c).^2, 1)) <= r + 1e-8), 'V1.8 随机 10 点覆盖', '');

fprintf('========== V2 回归: P=(750,600) ==========\n');
P2 = [750; 600];
cfg2 = cfg;
cfg2.eval_tol = 0.05; cfg2.eval_budget = 800; cfg2.kill_threshold = inf;
cfg2.witness = D_witness(cfg2);
res2 = eval_P_bounds(P2, cfg2, []);
fprintf('  结果: [L,U]=[%.6f, %.6f]  gap=%.6f  worstβ=%.6f°  neval=%d  t=%.3fs  %s\n', ...
    res2.L, res2.U, res2.U - res2.L, mod(rad2deg(res2.worst_beta), 360), res2.neval, res2.t, res2.status);
check(res2.L >= 59.0 && res2.L <= 59.5, 'V2.1 下界≈59.3', sprintf('  (L=%.4f)', res2.L));
check(res2.U >= 59.2 && res2.U <= 59.7, 'V2.2 上界≈59.3', sprintf('  (U=%.4f)', res2.U));
check(res2.U - res2.L <= 0.07, 'V2.3 上下界差≤0.07', sprintf('  (gap=%.5f)', res2.U - res2.L));
check(abs(mod(rad2deg(res2.worst_beta), 360) - 319.13) < 2.5, 'V2.4 最坏读数≈319.13°', ...
    sprintf('  (β=%.4f°)', mod(rad2deg(res2.worst_beta), 360)));
check(strcmp(res2.status, 'converged'), 'V2.5 状态收敛', sprintf('  (%s)', res2.status));
% 最坏读数处内外多边形与包围圆(供图)
bw = res2.worst_beta;
[polin, flin] = build_J_region(P2, bw, cfg.delta, 'inner', cfg);
[polout, flout] = build_J_region(P2, bw, cfg.delta, 'outer', cfg);
Vin = cat(2, polin{:});
[cin, rin] = welzl_mec(Vin, cfg);
V2 = struct('P', P2, 'res', res2, 'polin', {polin}, 'polout', {polout}, 'cin', cin, 'rin', rin, ...
    'flin', flin, 'flout', flout, 'refL', 59.336671716, 'refU', 59.420993477);

fprintf('========== V3 角度周期性与跨 0/360° ==========\n');
cfg3 = cfg;
cfg3.eval_tol = 0.5; cfg3.eval_budget = 600; cfg3.kill_threshold = inf;
cfg3.witness = D_witness(cfg3);
res_ref = eval_P_bounds(P2, cfg3, []);          % (750,600) @0.5
res_mir = eval_P_bounds([750; -600], cfg3, []); % 镜像对称
check(abs(res_ref.L - res_mir.L) <= 0.8 && abs(res_ref.U - res_mir.U) <= 0.8, ...
    'V3.1 (750,600) 与 (750,-600) 对称', sprintf('  (L %.3f/%.3f, U %.3f/%.3f)', res_ref.L, res_mir.L, res_ref.U, res_mir.U));
res_w0 = eval_P_bounds([750; 26], cfg3, []);
bw0 = mod(rad2deg(res_w0.worst_beta), 360);
check((bw0 >= 345 || bw0 <= 15), 'V3.2 (750,26) 最坏读数跨 0/360°', sprintf('  (β=%.4f°, [L,U]=[%.2f,%.2f] %s)', bw0, res_w0.L, res_w0.U, res_w0.status));
res_w1 = eval_P_bounds([750; -26], cfg3, []);
check(abs(res_w0.L - res_w1.L) <= 0.8 && abs(res_w0.U - res_w1.U) <= 0.8, ...
    'V3.3 (750,26) 与 (750,-26) 对称', sprintf('  (L %.3f/%.3f)', res_w0.L, res_w1.L));
% 楔形半平面在未卷绕角度下的周期性
[n1a, c1a, n2a, c2a] = wedge_planes([750; 600], 0.5*pi/180, 1*pi/180);
[n1b, c1b, n2b, c2b] = wedge_planes([750; 600], 0.5*pi/180 + 2*pi, 1*pi/180);
check(norm([n1a;c1a;n2a;c2a] - [n1b;c1b;n2b;c2b]) < 1e-11, 'V3.4 楔形半平面 +2π 周期性', '');

fprintf('========== V4 近共线情形 P=(750,0) ==========\n');
cfg4 = cfg;
cfg4.eval_tol = 0.5; cfg4.eval_budget = 900; cfg4.kill_threshold = inf;
cfg4.witness = D_witness(cfg4);
res4 = eval_P_bounds([750; 0], cfg4, []);
bw4 = mod(rad2deg(res4.worst_beta), 360);
fprintf('  结果: [L,U]=[%.2f,%.2f]  gap=%.3f  worstβ=%.3f°  neval=%d  t=%.2fs  %s\n', ...
    res4.L, res4.U, res4.U - res4.L, bw4, res4.neval, res4.t, res4.status);
check(strcmp(res4.status, 'converged'), 'V4.1 有界且收敛', sprintf('  (%s)', res4.status));
check(res4.L >= 340 && res4.U <= 405, 'V4.2 量级≈370(受 D 限制)', sprintf('  ([%.2f,%.2f])', res4.L, res4.U));
check(bw4 <= 4 || bw4 >= 356 || abs(bw4 - 180) <= 2.5, 'V4.3 最坏读数在 0/180° 针状区', sprintf('  (β=%.3f°)', bw4));
check(hat_f1([750; 0], cfg) >= 1e8, 'V4.4 近似式 y=0 奇异处理', '');

fprintf('========== V5 空交/正常观测/近距离饱和分支 ==========\n');
[pol_e, fl_e] = build_J_region([750; 600], deg2rad(90), cfg.delta, 'outer', cfg);
check(fl_e.empty, 'V5.1 不可行读数 β=90° 空交', '');
P5 = [700; 5];
[pol_i5, fl_i5] = build_J_region(P5, 0, cfg.delta, 'inner', cfg);
Gin = [705; 5];   % 距 P 恰 5 米(饱和分支, 应被排除)
Gout = [715; 5];  % 距 P 15 米(正常观测, 应在区域内)
inGin = false; inGout = false;
for q = 1:numel(pol_i5)
    K = pol_i5{q};
    if inpolygon(Gin(1), Gin(2), K(1, :), K(2, :)), inGin = true; end
    if inpolygon(Gout(1), Gout(2), K(1, :), K(2, :)), inGout = true; end
end
check(~inGin, 'V5.2 距 P=5m 点被内区域排除(饱和分支)', '');
check(inGout, 'V5.3 距 P=15m 点保留(正常观测)', '');
r_out5 = region_mec([750; 600], deg2rad(319), cfg.delta, 'outer', cfg);
check(r_out5 > 10, 'V5.4 可行读数 319° 非空且非零半径', sprintf('  (r=%.2f)', r_out5));

fprintf('========== V6 上下界收紧性与确定性 ==========\n');
tols = [2.0 0.5 0.1];
Ls = zeros(1, 3); Us6 = zeros(1, 3);
for i = 1:3
    cgi = cfg;
    cgi.eval_tol = tols(i); cgi.eval_budget = 900; cgi.kill_threshold = inf;
    cgi.witness = D_witness(cgi);
    ri = eval_P_bounds(P2, cgi, []);
    Ls(i) = ri.L; Us6(i) = ri.U;
    fprintf('  tol=%.1f: [L,U]=[%.4f,%.4f] gap=%.4f n=%d\n', tols(i), ri.L, ri.U, ri.U - ri.L, ri.neval);
end
check(Ls(1) <= Ls(2) + 1e-9 && Ls(2) <= Ls(3) + 1e-9, 'V6.1 L 随精度提高不降', '');
check(Us6(1) >= Us6(2) - 1e-9 && Us6(2) >= Us6(3) - 1e-9, 'V6.2 U 随精度提高不升', '');
check(Us6(3) - Ls(3) <= tols(3) + 0.02, 'V6.3 精评 gap≤tol+0.02', sprintf('  (gap=%.4f)', Us6(3) - Ls(3)));
Nlist = [256 1024 2048];
LN = zeros(1, 3); UN = zeros(1, 3);
for i = 1:3
    cgi = cfg;
    cgi.n_arc = Nlist(i);
    cgi.eval_tol = 0.1; cgi.eval_budget = 900; cgi.kill_threshold = inf;
    cgi.witness = D_witness(cgi);
    ri = eval_P_bounds(P2, cgi, []);
    LN(i) = ri.L; UN(i) = ri.U;
    fprintf('  n_arc=%d: [L,U]=[%.4f,%.4f]\n', Nlist(i), ri.L, ri.U);
end
check(LN(1) <= LN(2) + 0.05 && LN(2) <= LN(3) + 0.05, 'V6.4 L 随多边形加密不降', '');
check(UN(1) >= UN(2) - 0.05 && UN(2) >= UN(3) - 0.05, 'V6.5 U 随多边形加密不升', '');
rng(cfg.seed);
cgi = cfg; cgi.eval_tol = 0.5; cgi.eval_budget = 600; cgi.kill_threshold = inf; cgi.witness = D_witness(cgi);
ra = eval_P_bounds(P2, cgi, []);
rng(cfg.seed);
rb = eval_P_bounds(P2, cgi, []);
check(abs(ra.L - rb.L) < 1e-9 && abs(ra.U - rb.U) < 1e-9, 'V6.6 固定种子重复运行一致', '');

fprintf('========== V7 独立密角度采样一致性核验 ==========\n');
[lo7, hi7, full7] = theta_span_P(P2, cfg);
check(~full7, 'V7.1 Θ(P) 为真子区间', sprintf('  (跨度 %.1f°)', rad2deg(hi7 - lo7)));
grid7 = linspace(lo7, hi7, 1501);
dmax = 0; bestg = nan;
for i = 1:numel(grid7)
    rv = region_mec(P2, grid7(i), cfg.delta, 'outer', cfg);
    if rv > dmax, dmax = rv; bestg = grid7(i); end
end
fprintf('  密采样(1501 角)最大外半径 = %.4f m @ %.4f°\n', dmax, mod(rad2deg(bestg), 360));
check(dmax <= Us6(3) + 0.05, 'V7.2 密采样最大 ≤ 细分上界+0.05', sprintf('  (%.4f vs U=%.4f)', dmax, Us6(3)));
check(dmax >= Ls(3) - 0.2, 'V7.3 密采样最大 ≥ 细分下界-0.2', sprintf('  (%.4f vs L=%.4f)', dmax, Ls(3)));

fprintf('========== V8 一阶近似模型核对 ==========\n');
cases = {[1500 750 600], [5 750 600], [700 300 900], [1200 780 632]};
ok8 = true;
for i = 1:numel(cases)
    rv = cases{i}(1); x = cases{i}(2); y = cases{i}(3);
    d = cfg.delta; L2 = (rv - x)^2 + y^2;
    verts = zeros(2, 4); k = 0;
    for s1 = [-1 1]
        dv = s1 * rv * d;
        for s2 = [-1 1]
            du = (s2 * L2 * d - (rv - x) * dv) / y;
            k = k + 1;
            verts(:, k) = [rv + du; dv];
        end
    end
    [~, rm] = welzl_mec(verts, cfg);
    rho = d * sqrt(rv^2 + (((rv - x)^2 + y^2 + rv * abs(rv - x))^2) / y^2);
    ok8 = ok8 && abs(rm - rho) < 1e-9;
    fprintf('  (r,x,y)=(%g,%g,%g): 平行四边形覆盖半径 %.6f vs 公式 %.6f\n', rv, x, y, rm, rho);
end
check(ok8, 'V8.1 平行四边形覆盖半径=公式(4 组)', '');
Ps8 = {[750; 600], [780; 632], [750; 26], [900; 200], [750; 0.5]};
maxvio = 0;
for i = 1:numel(Ps8)
    P = Ps8{i};
    rg = 0:20:1500;
    v = zeros(1, numel(rg));
    for j = 1:numel(rg)
        v(j) = d * sqrt(rg(j)^2 + (((rg(j) - P(1))^2 + P(2)^2 + rg(j) * abs(rg(j) - P(1)))^2) / P(2)^2);
    end
    vio = max(2 * v(2:end-1) - v(1:end-2) - v(3:end));
    maxvio = max(maxvio, vio);
end
check(maxvio <= 1e-6, 'V8.2 ρ_hat 关于 r 数值凸(5 组 P)', sprintf('  (最大二阶差分违反 %.2e)', maxvio));
f1h = hat_f1(P2, cfg);
rh5 = d * sqrt(25 + (((5 - 750)^2 + 600^2 + 5 * 745)^2) / 600^2);
rh15 = d * sqrt(1500^2 + (((1500 - 750)^2 + 600^2 + 1500 * 750)^2) / 600^2);
check(abs(f1h - max(rh5, rh15)) < 1e-12, 'V8.3 f1_hat=两端点最大', sprintf('  (f1_hat=%.4f)', f1h));

fprintf('========== V9 E 四圆盘刻画与见证点合法性 ==========\n');
% 网格暴力核对: 对每个 P 用 D 边界密集采样算 max||P-G||, 与四圆盘判据比较
[Db, W] = D_region(cfg);
xs = linspace(400, 1100, 120);
ys = linspace(-700, 700, 240);
[X, Y] = meshgrid(xs, ys);
PP = [X(:)'; Y(:)'];
okE = in_E(PP, cfg);
maxd = zeros(1, size(PP, 2));
for i = 1:size(PP, 2)
    dpts = sqrt(sum((Db - PP(:, i)).^2, 1));
    maxd(i) = max(dpts);
end
bruteE = maxd <= cfg.R0 + 1e-3;
mism = sum(okE ~= bruteE);
check(mism == 0, 'V9.1 E 四圆盘=暴力最大距离判据', sprintf('  (不匹配 %d/%d)', mism, numel(okE)));
check(all(hypot(W(1, :), W(2, :)) >= 5 - 1e-12) && all(hypot(W(1, :), W(2, :)) <= 1500 + 1e-12), ...
    'V9.2 见证点半径范围合法', '');
check(all(abs(atan2(W(2, :), W(1, :))) <= cfg.delta + 1e-12), 'V9.3 见证点角度范围合法', '');
lc = chord_lower_bound([750; 600], cfg);
check(abs(lc - 1500 * sin(cfg.delta) / (1 + sin(cfg.delta))) < 1e-12 && abs(lc - 25.73) < 0.01, ...
    'V9.4 弦下界=25.73(E 内点)', sprintf('  (%.4f)', lc));
ep = pair_lower_bound([750; 600], W, cfg);
ep2 = pair_lower_bound([750; 0], W, cfg);
check(ep >= 13, 'V9.5 点对下界(750,600)', sprintf('  (%.2f)', ep));
check(ep2 >= 300, 'V9.6 点对下界(750,0) 捕捉共线退化', sprintf('  (%.2f)', ep2));
% E 内任一点的最坏接收距离 ≤ 1000(由构造保证, 抽查)
chk = max(maxd(in_E(PP, cfg)));
check(chk <= cfg.R0 + 1e-3, 'V9.7 E 内最坏接收距离≤1000', sprintf('  (%.3f)', chk));

fprintf('========== 汇总 ==========\n');
fprintf('通过 %d 项, 失败 %d 项, 总耗时 %.1f s\n', npass, nfail, toc(t0));
if nfail > 0
    disp('失败项:'); disp(fails);
end
V = struct('npass', npass, 'nfail', nfail, 'fails', {fails}, 't_total', toc(t0), ...
    'V2', V2, 'V3', struct('ref', res_ref, 'mir', res_mir, 'w0', res_w0, 'w1', res_w1), ...
    'V4', res4, 'V6', struct('tols', tols, 'Ls', Ls, 'Us', Us6, 'Nlist', Nlist, 'LN', LN, 'UN', UN), ...
    'V7', struct('grid', grid7, 'lo', lo7, 'hi', hi7, 'dmax', dmax, 'bestg', bestg), ...
    'V8', struct('maxvio', maxvio, 'f1h', f1h, 'rh5', rh5, 'rh15', rh15), ...
    'V9', struct('mism', mism, 'ep', ep, 'ep2', ep2, 'chord', lc));
save(fullfile(cfg.results_dir, 'verify_results.mat'), 'V');
end

function W = D_witness(cfg)
[~, W] = D_region(cfg);
end

function br = brute_mec(Q)
% 枚举所有 1/2/3 点子集的最小覆盖圆(对拍用)
n = size(Q, 2);
br = inf;
comb = {};
for s = 1:3
    C = nchoosek(1:n, s);
    for t = 1:size(C, 1)
        comb{end+1} = C(t, :); %#ok<AGROW>
    end
end
for i = 1:numel(comb)
    sub = Q(:, comb{i});
    m = size(sub, 2);
    if m == 1, cc = sub(:, 1); rr = 0;
    elseif m == 2, cc = mean(sub, 2); rr = norm(sub(:, 1) - sub(:, 2)) / 2;
    else
        d12 = norm(sub(:, 1) - sub(:, 2)); d13 = norm(sub(:, 1) - sub(:, 3)); d23 = norm(sub(:, 2) - sub(:, 3));
        if d12 >= d13 && d12 >= d23
            if d12^2 >= (d13^2 + d23^2) * (1 + 1e-12), cc = (sub(:, 1) + sub(:, 2)) / 2; rr = d12 / 2;
            else, [cc, rr] = circum(sub); end
        elseif d13 >= d12 && d13 >= d23
            if d13^2 >= (d12^2 + d23^2) * (1 + 1e-12), cc = (sub(:, 1) + sub(:, 3)) / 2; rr = d13 / 2;
            else, [cc, rr] = circum(sub); end
        else
            if d23^2 >= (d12^2 + d13^2) * (1 + 1e-12), cc = (sub(:, 2) + sub(:, 3)) / 2; rr = d23 / 2;
            else, [cc, rr] = circum(sub); end
        end
    end
    if all(sqrt(sum((Q - cc).^2, 1)) <= rr + 1e-9) && rr < br
        br = rr;
    end
end
end

function [c, r] = circum(b)
A = [2*(b(:, 2) - b(:, 1))'; 2*(b(:, 3) - b(:, 1))'];
rhs = [sum(b(:, 2).^2) - sum(b(:, 1).^2); sum(b(:, 3).^2) - sum(b(:, 1).^2)];
c = A \ rhs;
r = norm(b(:, 1) - c);
end
