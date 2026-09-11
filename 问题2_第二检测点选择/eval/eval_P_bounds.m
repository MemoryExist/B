function res = eval_P_bounds(P, cfg, state)
%EVAL_P_BOUNDS 固定第二检测点 P 的最坏定位半径 f1(P) 的上下界
%   角度区间自适应细分:
%     可行读数范围 Θ(P) 安全覆盖后分成角度箱 I_j=[β_j-η_j, β_j+η_j];
%     箱上界: J_j^+ = D ∩ W(P, β_j; δ+η_j) 的外多边形近似覆盖半径 U_j
%             (含区间内所有实际读数对应的定位区域, 故 max U_j ≥ f1(P));
%     箱中点采样: J(β) 的内多边形近似覆盖半径 → 下界 L;
%     另有点对下界与弦下界(理论下界)。每次细分上界最大的箱。
%   终止: (1) U-L ≤ cfg.eval_tol; (2) L > cfg.kill_threshold(提前淘汰);
%         (3) neval ≥ cfg.eval_budget(预算, 返回未收敛上下界与状态)。
%   state: 上次状态(继续细分), 由缓存管理。
%   返回 res: .L .U .Uw(最坏β处上界, 报告用) .worst_beta(rad) .neval
%             .status('converged'|'budget'|'pruned'|'empty') .state .log .t .P
t0 = tic;
if nargin < 3 || isempty(state)
    [lo, hi, isfull] = theta_span_P(P, cfg);
    if isfull
        nb = round(2*pi / (2*cfg.eta0));
        centers = cfg.eta0 + (0:nb-1) * (2*pi / nb);
        hw = repmat(cfg.eta0, 1, nb);
    else
        w = hi - lo;
        nb = max(1, ceil(w / (2*cfg.eta0)));
        hw = repmat(w / (2*nb), 1, nb);
        centers = lo + hw + (0:nb-1) * (2*hw(1));
    end
    Ub = zeros(1, nb);
    for k = 1:nb
        Ub(k) = region_mec(P, centers(k), cfg.delta + hw(k), 'outer', cfg);
    end
    neval = nb;
    L = 0;
    worst_beta = nan;
else
    centers = state.centers; hw = state.hw; Ub = state.Ub;
    neval = state.neval; L = state.L; worst_beta = state.worst;
end
% 理论下界并入
L = max(L, pair_lower_bound(P, cfg.witness, cfg));
L = max(L, chord_lower_bound(P, cfg));
U = max(Ub);
logU = U; logL = L; logN = neval;
status = 'running';
if L > cfg.kill_threshold
    status = 'pruned';
end
while strcmp(status, 'running') && (U - L > cfg.eval_tol) && (neval < cfg.eval_budget)
    [umax, k] = max(Ub);
    if umax <= L + cfg.eval_tol
        break;
    end
    bm = centers(k);
    Lb = region_mec(P, bm, cfg.delta, 'inner', cfg);   % 箱中点: 可行读数下界
    neval = neval + 1;
    if Lb > L
        L = Lb; worst_beta = bm;
    end
    h1 = hw(k) / 2;
    c1 = bm - h1; c2 = bm + h1;
    U1 = region_mec(P, c1, cfg.delta + h1, 'outer', cfg);
    U2 = region_mec(P, c2, cfg.delta + h1, 'outer', cfg);
    centers(k) = c1; hw(k) = h1; Ub(k) = U1;
    centers(end+1) = c2; hw(end+1) = h1; Ub(end+1) = U2; %#ok<AGROW>
    neval = neval + 2;
    U = max(Ub);
    logU(end+1) = U; logL(end+1) = L; logN(end+1) = neval; %#ok<AGROW>
    if L > cfg.kill_threshold
        status = 'pruned';
    end
end
if strcmp(status, 'running')
    if U - L <= cfg.eval_tol
        status = 'converged';
    else
        status = 'budget';
    end
end
if isnan(worst_beta)
    status = 'empty';
end
Uw = 0;
if ~isnan(worst_beta)
    Uw = region_mec(P, worst_beta, cfg.delta, 'outer', cfg);
end
res = struct('P', P, 'L', L, 'U', U, 'Uw', Uw, 'worst_beta', worst_beta, ...
    'neval', neval, 'status', status, 't', toc(t0), ...
    'log', struct('U', logU, 'L', logL, 'n', logN), ...
    'state', struct('centers', centers, 'hw', hw, 'Ub', Ub, ...
    'neval', neval, 'L', L, 'worst', worst_beta));
end
