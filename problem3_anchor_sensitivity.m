function [runs, summary, comparison] = problem3_anchor_sensitivity( ...
    trials, seed, coefficients, scenarios, saveOutputs)
% 问题三六边形收缩系数的配对灵敏度分析。
%
% 默认用法：
%   [runs,summary,comparison] = problem3_anchor_sensitivity();
%
% 粗搜索示例：
%   ;problem3_anchor_sensitivity(100,20260913,[0 20 40 60 80 100])
%
% 细搜索示例：
%   problem3_anchor_sensitivity(500,20261913,35:5:65);
%
% coefficients的单位为m/频道。系数0对应固定1500 m骨架。
% 每个随机案例在所有系数下共享源、频道、接收半径、误差场和随机数状态，
% 因而配对差值只反映骨架收缩系数的影响。

if nargin < 1 || isempty(trials), trials = 100; end
if nargin < 2 || isempty(seed), seed = 20260913; end
if nargin < 3 || isempty(coefficients)
    coefficients = [0 20 40 60 80 100];
end
if nargin < 4 || isempty(scenarios)
    scenarios = ["uniform" "edge" "cluster" "extreme"];
end
if nargin < 5 || isempty(saveOutputs), saveOutputs = true; end

validateattributes(trials,{'numeric'},{'scalar','integer','positive'});
validateattributes(seed,{'numeric'},{'scalar','integer','nonnegative','finite'});
validateattributes(coefficients,{'numeric'},{'vector','real','finite','nonnegative'});
validateattributes(saveOutputs,{'logical','numeric'},{'scalar'});

coefficients = unique(double(coefficients(:)'),'stable');
if ~any(coefficients == 0)
    coefficients = [0 coefficients];
    warning('已自动加入系数0，作为固定1500 m骨架的配对基准。');
end
scenarios = string(scenarios(:)');
allowed = ["uniform" "edge" "cluster" "extreme"];
assert(all(ismember(scenarios,allowed)),'场景只能为uniform、edge、cluster或extreme。');

root = fileparts(mfilename('fullpath'));
addpath(root);
oldRng = rng;
cleanup = onCleanup(@() rng(oldRng)); %#ok<NASGU>

nRows = numel(scenarios)*trials*numel(coefficients);
values = zeros(nRows,16);
scenarioColumn = strings(nRows,1);
errorColumn = strings(nRows,1);
row = 0;
caseId = 0;

for s = 1:numel(scenarios)
    scenario = scenarios(s);
    world = RandStream('mt19937ar','Seed',scenarioSeed(seed,scenario));
    progressStep = max(1,ceil(trials/10));

    for trial = 1:trials
        caseId = caseId + 1;
        [channels,xy,radius] = generateCase(world,scenario);
        n = numel(channels);
        noiseSeed = seed + 104729*caseId;
        solverSeed = mod(seed + caseId,2^32-1);

        for c = 1:numel(coefficients)
            coefficient = coefficients(c);
            rng(solverSeed,'twister');
            [metrics,errText] = runCase( ...
                coefficient,channels,xy,radius,noiseSeed,scenario);

            row = row + 1;
            values(row,:) = [trial,caseId,n,metrics];
            scenarioColumn(row) = scenario;
            errorColumn(row) = errText;
        end

        if trial == 1 || mod(trial,progressStep) == 0 || trial == trials
            fprintf('%s场景：%d/%d个案例完成。\n',scenario,trial,trials);
        end
    end
end

runs = array2table(values,'VariableNames',{ ...
    'Trial','CaseId','N','Cleared','Total_s','Average_s','Runtime_s', ...
    'Complete','Move_s','Switch_s','Measure_s','OpticalLaser_s', ...
    'FinalCheck_s','InitialFound','AnchorRadius_m','AnchorCoefficient'});
runs.Scenario = scenarioColumn;
runs.Error = errorColumn;
runs = movevars(runs,{'Scenario','Error'},'After','Trial');

summary = summarizeByScenario(runs,scenarios,coefficients);
comparison = compareCoefficients(runs,summary,coefficients);

fprintf('\n全部候选系数的平均时间对比（单位见变量名）：\n');
disp(comparison);

if logical(saveOutputs)
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
    folder = fullfile(root,'问题3参数灵敏度结果', ...
        sprintf('%s_seed%d_trials%d',stamp,seed,trials));
    if ~isfolder(folder), mkdir(folder); end
    prefix = fullfile(folder,'problem3_anchor_sensitivity');
    writetable(runs,[prefix '_runs.csv']);
    writetable(summary,[prefix '_summary.csv']);
    writetable(comparison,[prefix '_comparison.csv']);
    save([prefix '.mat'],'runs','summary','comparison','trials','seed', ...
        'coefficients','scenarios');
    fprintf('结果已保存至：%s\n',folder);
end
end

function summary = summarizeByScenario(runs,scenarios,coefficients)
% 分场景汇总，并计算相对系数0的配对节省量。
nRows = numel(scenarios)*numel(coefficients);
scenarioColumn = strings(nRows,1);
coefficientColumn = zeros(nRows,1);
trialColumn = zeros(nRows,1);
fullClearColumn = zeros(nRows,1);
meanAverageColumn = nan(nRows,1);
averageLowColumn = nan(nRows,1);
averageHighColumn = nan(nRows,1);
meanTotalColumn = nan(nRows,1);
meanMoveColumn = nan(nRows,1);
meanMeasureColumn = nan(nRows,1);
meanRadiusColumn = nan(nRows,1);
meanInitialColumn = nan(nRows,1);
meanSavingColumn = nan(nRows,1);
savingLowColumn = nan(nRows,1);
savingHighColumn = nan(nRows,1);
winRateColumn = nan(nRows,1);

row = 0;
for s = 1:numel(scenarios)
    scenario = scenarios(s);
    base = sortrows(runs( ...
        runs.Scenario == scenario & runs.AnchorCoefficient == 0,:),'Trial');

    for c = 1:numel(coefficients)
        coefficient = coefficients(c);
        current = sortrows(runs( ...
            runs.Scenario == scenario & ...
            runs.AnchorCoefficient == coefficient,:),'Trial');
        assert(isequal(base.Trial,current.Trial),'配对案例编号不一致。');

        valid = logical(current.Complete) & strlength(current.Error) == 0 & ...
            isfinite(current.Average_s);
        validPair = valid & logical(base.Complete) & strlength(base.Error) == 0 & ...
            isfinite(base.Average_s);

        row = row + 1;
        scenarioColumn(row) = scenario;
        coefficientColumn(row) = coefficient;
        trialColumn(row) = height(current);
        fullClearColumn(row) = mean(logical(current.Complete) & ...
            strlength(current.Error) == 0);
        [meanAverageColumn(row),averageLowColumn(row),averageHighColumn(row)] = ...
            meanCI(current.Average_s(valid));
        meanTotalColumn(row) = finiteMean(current.Total_s(valid));
        meanMoveColumn(row) = finiteMean(current.Move_s(valid));
        meanMeasureColumn(row) = finiteMean(current.Measure_s(valid));
        meanRadiusColumn(row) = finiteMean(current.AnchorRadius_m(valid));
        meanInitialColumn(row) = finiteMean(current.InitialFound(valid));

        delta = base.Average_s(validPair)-current.Average_s(validPair);
        [meanSavingColumn(row),savingLowColumn(row),savingHighColumn(row)] = ...
            meanCI(delta);
        if ~isempty(delta), winRateColumn(row) = mean(delta > 0); end
    end
end

summary = table(scenarioColumn,coefficientColumn,trialColumn,fullClearColumn, ...
    meanAverageColumn,averageLowColumn,averageHighColumn,meanTotalColumn, ...
    meanMoveColumn,meanMeasureColumn,meanRadiusColumn,meanInitialColumn, ...
    meanSavingColumn,savingLowColumn,savingHighColumn,winRateColumn, ...
    'VariableNames',{'Scenario','AnchorCoefficient','Trials','FullClearRate', ...
    'MeanAverage_s','AverageCI95Low_s','AverageCI95High_s','MeanTotal_s', ...
    'MeanMove_s','MeanMeasure_s','MeanAnchorRadius_m','MeanInitialFound', ...
    'MeanSavingVsFixed_s','SavingCI95Low_s','SavingCI95High_s', ...
    'PairedWinRateVsFixed'});
end

function comparison = compareCoefficients(runs,summary,coefficients)
% 按系数列出全部平均指标，不替用户自动选取“最优值”。
n = numel(coefficients);
coefficientColumn = coefficients(:);
fullClearColumn = zeros(n,1);
overallMeanColumn = nan(n,1);
worstMeanColumn = nan(n,1);
uniformMeanColumn = nan(n,1);
edgeMeanColumn = nan(n,1);
clusterMeanColumn = nan(n,1);
extremeMeanColumn = nan(n,1);
meanTotalColumn = nan(n,1);
meanMoveColumn = nan(n,1);
meanMeasureColumn = nan(n,1);
meanRadiusColumn = nan(n,1);
meanSavingColumn = nan(n,1);

for c = 1:n
    coefficient = coefficients(c);
    currentRuns = runs(runs.AnchorCoefficient == coefficient,:);
    currentSummary = summary(summary.AnchorCoefficient == coefficient,:);
    valid = logical(currentRuns.Complete) & strlength(currentRuns.Error) == 0 & ...
        isfinite(currentRuns.Average_s);

    fullClearColumn(c) = mean(logical(currentRuns.Complete) & ...
        strlength(currentRuns.Error) == 0);
    overallMeanColumn(c) = finiteMean(currentRuns.Average_s(valid));
    meanTotalColumn(c) = finiteMean(currentRuns.Total_s(valid));
    meanMoveColumn(c) = finiteMean(currentRuns.Move_s(valid));
    meanMeasureColumn(c) = finiteMean(currentRuns.Measure_s(valid));
    meanRadiusColumn(c) = finiteMean(currentRuns.AnchorRadius_m(valid));
    meanSavingColumn(c) = finiteMean(currentSummary.MeanSavingVsFixed_s);

    for s = 1:height(currentSummary)
        value = currentSummary.MeanAverage_s(s);
        switch char(currentSummary.Scenario(s))
            case 'uniform', uniformMeanColumn(c) = value;
            case 'edge', edgeMeanColumn(c) = value;
            case 'cluster', clusterMeanColumn(c) = value;
            case 'extreme', extremeMeanColumn(c) = value;
        end
    end
    scenarioMeans = [uniformMeanColumn(c),edgeMeanColumn(c), ...
        clusterMeanColumn(c),extremeMeanColumn(c)];
    worstMeanColumn(c) = finiteMax(scenarioMeans);
end

comparison = table(coefficientColumn,uniformMeanColumn,edgeMeanColumn, ...
    clusterMeanColumn,extremeMeanColumn,overallMeanColumn,worstMeanColumn, ...
    meanTotalColumn,meanMoveColumn,meanMeasureColumn,meanRadiusColumn, ...
    fullClearColumn,meanSavingColumn, ...
    'VariableNames',{'AnchorCoefficient','UniformMean_sPerSource', ...
    'EdgeMean_sPerSource','ClusterMean_sPerSource', ...
    'ExtremeMean_sPerSource','OverallMean_sPerSource', ...
    'WorstScenarioMean_sPerSource','MeanTotal_s','MeanMove_s', ...
    'MeanMeasure_s','MeanAnchorRadius_m','FullClearRate', ...
    'MeanSavingVsFixed_sPerSource'});
comparison = sortrows(comparison,'AnchorCoefficient','ascend');
end

function [channels,xy,radius] = generateCase(world,scenario)
% 与现有问题三配对蒙特卡洛保持相同的四类场景口径。
n = randi(world,[10,16]);
channels = randperm(world,20,n);
theta = 2*pi*rand(world,1,n);
rho = 1800*sqrt(rand(world,1,n));
xy = [rho.*cos(theta);rho.*sin(theta)];
radius = 1000+500*rand(world,1,n);

if scenario == "edge"
    xy = 1800*[cos(theta);sin(theta)];
    radius(:) = 1000;
elseif scenario == "cluster"
    center = 1400*[cos(theta(1));sin(theta(1))];
    xy = center+150*randn(world,2,n);
    xy = xy.*min(1,1800./vecnorm(xy));
elseif scenario == "extreme"
    xy(:,1) = [0;0];
    xy(:,2) = [1800;0];
    radius(:) = 1000;
end
end

function [metrics,errText] = runCase( ...
    coefficient,channels,xy,radius,noiseSeed,scenario)
% 封闭模拟器只通过enter/measure/clear/exit向策略提供反馈。
n = numel(channels);
live = true(1,n);
p = [0;0];
ch = 1;
t = 0;
parts = zeros(1,4);
clearTimes = [];
errText = "";
result = struct();
start = tic;

try
    result = problem3_solver_shared(@simulator,'',coefficient);
catch err
    errText = string(err.message);
end

count = sum(~live);
average = t/max(1,count);
if count == 0, average = inf; end
complete = ~any(live) && isfield(result,'complete') && result.complete;
tail = nan;
if ~isempty(clearTimes), tail = t-max(clearTimes); end
initialFound = nan;
anchorRadius = nan;
appliedCoefficient = coefficient;
if isfield(result,'initialFound'), initialFound = result.initialFound; end
if isfield(result,'anchorRadius'), anchorRadius = result.anchorRadius; end
if isfield(result,'anchorCoefficient')
    appliedCoefficient = result.anchorCoefficient;
end
assert(abs(t-sum(parts))<1e-6,'模拟计时分项不守恒。');
metrics = [count,t,average,toc(start),complete,parts,tail, ...
    initialFound,anchorRadius,appliedCoefficient];

    function z = simulator(path,request)
        z = struct('accepted',true,'virtual_time_s',t);
        if strcmp(path,'/enter')
            z.remaining_real_duration_s = 1200;
            return;
        end
        if strcmp(path,'/exit')
            z.exit_reason = 'user_exit';
            return;
        end

        q = [request.position.x;request.position.y];
        k = request.channel;
        dt = norm(q-p)/5;
        parts(1) = parts(1)+dt;
        t = t+dt;
        p = q;
        j = find(channels == k & live,1);
        d = inf;
        if ~isempty(j), d = norm(xy(:,j)-p); end

        if strcmp(path,'/measure')
            sw = double(ch ~= k);
            ch = k;
            t = t+sw+5;
            parts(2) = parts(2)+sw;
            parts(3) = parts(3)+5;

            if isempty(j) || d > radius(j)
                z.measure_result = 'no_signal';
            elseif d <= 5
                z.measure_result = 'near';
            else
                w = sin(q(1)*12.9898+q(2)*78.233+k*37.719+ ...
                    noiseSeed*.013)*43758.5453;
                e = 2*(w-floor(w))-1;
                if scenario == "extreme", e = sign(e); end
                v = xy(:,j)-p;
                z.measure_result = 'direction';
                z.svd_deg = mod(round(atan2d(v(2),v(1))+e,2),360);
            end
        else
            ok = d <= 20;
            dt = 3+2*ok;
            t = t+dt;
            parts(4) = parts(4)+dt;
            if ok
                live(j) = false;
                z.clear_result = 'success';
                clearTimes(end+1) = t; %#ok<AGROW>
            else
                z.clear_result = 'no_target_in_range';
            end
        end
        z.virtual_time_s = t;
    end
end

function value = scenarioSeed(seed,scenario)
switch char(scenario)
    case 'uniform', offset = 1009;
    case 'edge', offset = 2003;
    case 'cluster', offset = 3001;
    case 'extreme', offset = 4001;
    otherwise, error('未知场景。');
end
value = mod(seed+offset,2^32-1);
end

function [meanValue,low,high] = meanCI(values)
values = values(isfinite(values));
if isempty(values)
    meanValue = nan; low = nan; high = nan;
    return;
end
meanValue = mean(values);
if numel(values) < 2
    low = nan; high = nan;
    return;
end
halfWidth = 1.96*std(values)/sqrt(numel(values));
low = meanValue-halfWidth;
high = meanValue+halfWidth;
end

function value = finiteMean(values)
values = values(isfinite(values));
if isempty(values), value = nan; else, value = mean(values); end
end

function value = finiteMax(values)
values = values(isfinite(values));
if isempty(values), value = nan; else, value = max(values); end
end
