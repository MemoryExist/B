function res = eval_P_bounds(P, cfg, state)
%EVAL_P_BOUNDS 对固定 P 给出最坏包围半径的几何上下界，并支持继续细分。
% 预算按包围圆计算次数计；初始化必须完整覆盖读数范围。
P = P(:);
if ~isfield(cfg, 'eval_tol'), cfg.eval_tol = cfg.tol_fine; end
if ~isfield(cfg, 'eval_budget'), cfg.eval_budget = cfg.budget_fine; end
if ~isfield(cfg, 'kill_threshold'), cfg.kill_threshold = inf; end
if ~isfield(cfg, 'witness'), [~, cfg.witness] = D_region(cfg); end
assert(cfg.eval_tol > 0 && cfg.eta0 > 0 && cfg.delta + cfg.eta0 < pi/2);
signature = [P; cfg.delta; cfg.Lmax; cfg.r_inner; cfg.n_arc; cfg.n_crop; ...
    cfg.n_hole_gon; cfg.hole_margin; cfg.crop_enabled; cfg.crop_center(:); cfg.crop_radius; ...
    cfg.R0; cfg.mec_tol; cfg.mec_tol_rel];
t0 = tic;
if nargin < 3 || isempty(state) || ~isequal(state.signature, signature)
    [lo, hi] = theta_span_P(P, cfg);
    nb = max(1, ceil((hi-lo)/(2*cfg.eta0)));
    assert(cfg.eval_budget >= nb, '角度预算不足以覆盖初始角度区间。');
    edges = linspace(lo, hi, nb+1);
    centers = (edges(1:end-1)+edges(2:end))/2;
    hw = diff(edges)/2;
    Ub = zeros(1, nb);
    for k = 1:nb
        Ub(k) = region_mec(P, centers(k), cfg.delta+hw(k), 'outer', cfg);
    end
    neval = nb; L = 0; sample_L = -inf; worst_beta = nan;
    elapsed = 0;
    logU = []; logL = []; logN = [];
else
    centers = state.centers; hw = state.hw; Ub = state.Ub;
    neval = state.neval; L = state.L;
    sample_L = state.sample_L; worst_beta = state.worst;
    elapsed = state.elapsed;
    logU = state.log.U; logL = state.log.L; logN = state.log.n;
end
L = max([L, pair_lower_bound(P, cfg.witness, cfg), chord_lower_bound(P, cfg)]);
U = max(Ub);
logU(end+1) = U; logL(end+1) = L; logN(end+1) = neval;
while true
    assert(L <= U+1e-5, '上下界矛盾，请检查几何或数值容差。');
    if U-L <= cfg.eval_tol
        status = 'converged'; break;
    elseif L > cfg.kill_threshold
        status = 'pruned'; break;
    elseif neval+3 > cfg.eval_budget
        status = 'budget'; break;
    end
    [parentU, k] = max(Ub);
    beta = centers(k);
    lower = region_mec(P, beta, cfg.delta, 'inner', cfg);
    neval = neval+1;
    if lower > sample_L
        sample_L = lower; worst_beta = beta;
    end
    L = max(L, lower);
    if L <= cfg.kill_threshold && U-L > cfg.eval_tol
        h = hw(k)/2;
        c1 = beta-h; c2 = beta+h;
        u1 = region_mec(P, c1, cfg.delta+h, 'outer', cfg);
        u2 = region_mec(P, c2, cfg.delta+h, 'outer', cfg);
        % 父箱同样包含子箱，取二者较小上界可抑制舍入造成的回升。
        centers(k) = c1; hw(k) = h; Ub(k) = min(parentU, u1);
        centers(end+1) = c2; hw(end+1) = h; Ub(end+1) = min(parentU, u2); %#ok<AGROW>
        neval = neval+2;
        U = max(Ub);
    end
    logU(end+1) = U; logL(end+1) = L; logN(end+1) = neval; %#ok<AGROW>
end
history = struct('U', logU, 'L', logL, 'n', logN);
elapsed = elapsed+toc(t0);
state = struct('signature', signature, 'centers', centers, 'hw', hw, 'Ub', Ub, ...
    'neval', neval, 'L', L, 'sample_L', sample_L, 'worst', worst_beta, ...
    'elapsed', elapsed, 'log', history);
res = struct('P', P, 'L', L, 'U', U, 'worst_beta', worst_beta, ...
    'neval', neval, 'status', status, 't', elapsed, 'log', history, 'state', state);
end
