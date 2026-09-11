function key = point_key(P)
%POINT_KEY 保留双精度坐标，避免毫米舍入合并不同的检测点。
P(P == 0) = 0;
key = sprintf('%.17g,%.17g', P(1), P(2));
end
