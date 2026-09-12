function test_discrete_cover(R, r)
    if nargin < 1, R = 56.5; end
    if nargin < 2, r = 20; end
    
    % 1. Discretize the target region D(0, R) to be covered
    [X, Y] = meshgrid(linspace(-R, R, 150));
    mask = X.^2 + Y.^2 <= R^2;
    Px = X(mask); Py = Y(mask);
    N_target = length(Px);
    
    % 2. Generate candidate centers (Hexagonal Grid)
    dx = r * sqrt(3) / 2 * 0.8; 
    dy = r * 3/4 * 0.8;
    [CX, CY] = meshgrid(-R-r:dx:R+r, -R-r:dy:R+r);
    shift = repmat([0, dx/2], size(CX,1), ceil(size(CX,2)/2));
    shift = shift(:, 1:size(CX,2));
    CX = CX + shift;
    
    c_mask = CX.^2 + CY.^2 <= (R)^2; 
    Cx = CX(c_mask); Cy = CY(c_mask);
    N_cand = length(Cx);
    
    fprintf('R = %.1f, Target points: %d, Candidate centers: %d\n', R, N_target, N_cand);
    
    % 3. Coverage matrix
    A = zeros(N_target, N_cand);
    for j = 1:N_cand
        dist2 = (Px - Cx(j)).^2 + (Py - Cy(j)).^2;
        A(:, j) = (dist2 <= r^2);
    end
    
    % 4. Solve Set Cover using intlinprog
    f = ones(N_cand, 1);
    intcon = 1:N_cand;
    b = -ones(N_target, 1);
    
    options = optimoptions('intlinprog', 'Display', 'off');
    [x_opt, fval, exitflag] = intlinprog(f, intcon, -A, b, [], [], zeros(N_cand,1), ones(N_cand,1), options);
    
    if exitflag > 0
        N_opt = round(fval);
        fprintf('Optimal number of circles: %d\n', N_opt);
        sel = x_opt > 0.5;
        Sel_X = Cx(sel); Sel_Y = Cy(sel);
        for i=1:length(Sel_X)
            fprintf('Point %d: (%.2f, %.2f)\n', i, Sel_X(i), Sel_Y(i));
        end
        
        % Compute simple TSP
        pts = [Sel_X, Sel_Y];
        D = pdist(pts);
        D_sq = squareform(D);
        % greedy TSP starting from (0,0)
        curr = [0,0];
        unvisited = 1:N_opt;
        path = [];
        total_dist = 0;
        while ~isempty(unvisited)
            [~, idx] = min(sum((pts(unvisited,:) - curr).^2, 2));
            next = unvisited(idx);
            total_dist = total_dist + norm(pts(next,:) - curr);
            path(end+1) = next;
            curr = pts(next,:);
            unvisited(idx) = [];
        end
        fprintf('Greedy TSP distance: %.2f m\n', total_dist);
    else
        fprintf('ILP failed.\n');
    end
end
