function starts = pick_starts(cache, n_starts, min_sep)
%PICK_STARTS 从缓存中挑 U 最小且两两相距 ≥ min_sep 的 n_starts 个点作为局部搜索起点
keys = cache.keys;
r = cell(1, numel(keys));
for i = 1:numel(keys)
    r{i} = cache(keys{i});
end
Us = cellfun(@(x) x.U, r);
Ps = cellfun(@(x) x.P, r, 'UniformOutput', false);
[~, ord] = sort(Us);
starts = {};
for i = 1:numel(ord)
    p = Ps{ord(i)};
    if isinf(Us(ord(i)))
        continue;
    end
    good = true;
    for s = 1:numel(starts)
        if norm(p - starts{s}) < min_sep
            good = false; break;
        end
    end
    if good
        starts{end+1} = p; %#ok<AGROW>
    end
    if numel(starts) >= n_starts
        break;
    end
end
end
