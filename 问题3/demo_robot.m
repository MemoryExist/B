function demo_robot()
% 模拟器通信演示程序 (提取自附件)
% 请将此处修改为你们的实际队号
baseUrl = 'http://127.0.0.1:2026';
robotId = '202617201282';

options = weboptions('MediaType', 'application/json', 'Timeout', 5);

% 1. 进入目标区域
enterRequest = baseRequest(robotId, 'enter-1');
enterResponse = post(baseUrl, '/enter', enterRequest, options);
if enterResponse.accepted ~= true
    fprintf('进入失败\n');
    return;
end
remainingTime = enterResponse.remaining_real_duration_s;
fprintf('剩余实际时间：%d秒\n', remainingTime);

% 2. 执行演示动作 (请根据你们的算法替换此处逻辑)
actions = {
    '/measure', actionRequest(robotId, 'measure-1', 300, 400, 1);
    '/measure', actionRequest(robotId, 'measure-2', 300, 400, 2);
    '/clear', actionRequest(robotId, 'clear-1', 300, 0, 3);
    '/measure', actionRequest(robotId, 'measure-3', 300, 0, 2)
    };

for i = 1:size(actions, 1)
    path = actions{i, 1};
    payload = actions{i, 2};

    response = post(baseUrl, path, payload, options);
    if response.accepted ~= true
        fprintf('指令未执行\n');
        return;
    end

    if strcmp(path, '/measure')
        if strcmp(response.measure_result, 'direction')
            fprintf('[耗时: %d秒] 示向度：%.2f度\n', response.virtual_time_s, response.svd_deg);
        elseif strcmp(response.measure_result, 'near')
            fprintf('[耗时: %d秒] 信号过强无示向度 (距离<=5m)\n', response.virtual_time_s);
        else
            fprintf('[耗时: %d秒] 未收到信号\n', response.virtual_time_s);
        end
    else
        if strcmp(response.clear_result, 'success')
            fprintf('[耗时: %d秒] 清除成功\n', response.virtual_time_s);
        else
            fprintf('[耗时: %d秒] 清除失败 (目标不在范围内或频道不对)\n', response.virtual_time_s);
        end
    end
end

% 3. 退出测试
exitRequest = baseRequest(robotId, 'exit-1');
exitResponse = post(baseUrl, '/exit', exitRequest, options);
if exitResponse.accepted == true
    fprintf('退出原因：%s\n', exitResponse.exit_reason);
end

end

%% 辅助函数 (API 封装)
function request = baseRequest(robotId, requestId)
request = struct( ...
    'arena_id', 'default', ...
    'robot_id', robotId, ...
    'request_id', requestId);
end

function request = actionRequest(robotId, requestId, x, y, channel)
request = baseRequest(robotId, requestId);
request.position = struct('x', x, 'y', y);
request.channel = channel;
end

function response = post(baseUrl, path, payload, options)
response = webwrite([baseUrl path], payload, options);
% 注释掉下方这一行，不再向控制台打印长串的原始 JSON 乱码
% fprintf('POST %s  -> %s\n', path, jsonencode(response));
end
