% Plot the region E and E0 defined by the intersection of four circles
% For visualization clarity, we exaggerate the angle tau so the sector is visible.
tau_plot = 12 * pi/180; 
R = 1000;
theta = linspace(0, 2*pi, 1000);
r_vals = [5, 1500];
s_vals = [1, -1];

figure('Position', [100, 100, 900, 700]);
hold on;
axis equal;
grid on;

% 1. Plot E0
% E0 is a sector from r=5 to r=1500
theta_E0 = linspace(-tau_plot, tau_plot, 100);
r_inner = 5;
r_outer = 1500;
x_E0 = [r_inner*cos(theta_E0), r_outer*cos(fliplr(theta_E0))];
y_E0 = [r_inner*sin(theta_E0), r_outer*sin(fliplr(theta_E0))];

% Use a beautiful pastel orange/peach color for E0
fill(x_E0, y_E0, [1, 0.85, 0.75], 'EdgeColor', [0.9, 0.5, 0.2], 'LineWidth', 1.5, 'FaceAlpha', 0.6, 'DisplayName', 'Region E_0');

% Add text label 'E_0' slightly towards the outer edge to avoid overlap
text(1300, 0, 'E_0', 'FontSize', 18, 'FontWeight', 'bold', 'Color', [0.8, 0.4, 0.1], 'HorizontalAlignment', 'center');

% 2. Plot the four circles and intersection E
colors = lines(4);
centers_x = zeros(1,4);
centers_y = zeros(1,4);
k = 1;

p = [];
for i = 1:2
    for j = 1:2
        xc = r_vals(i) * cos(tau_plot);
        yc = s_vals(j) * r_vals(i) * sin(tau_plot);
        centers_x(k) = xc;
        centers_y(k) = yc;
        
        x_circle = xc + R * cos(theta);
        y_circle = yc + R * sin(theta);
        poly_circle = polyshape(x_circle, y_circle);
        
        % Plot the boundary of the circle with slightly muted colors and dashed lines
        plot(x_circle, y_circle, '--', 'Color', [colors(k,:), 0.6], 'LineWidth', 1.5, ...
             'DisplayName', sprintf('Circle centered at G_%d', k));
             
        if isempty(p)
            p = poly_circle;
        else
            p = intersect(p, poly_circle);
        end
        k = k + 1;
    end
end

% Fill the intersection region E with a beautiful pastel blue/purple
plot(p, 'FaceColor', [0.75, 0.85, 0.95], 'FaceAlpha', 0.8, 'EdgeColor', [0.2, 0.5, 0.8], 'LineWidth', 2, 'DisplayName', 'Region E');

% Add text label 'E' in the center of the region
[cx, cy] = centroid(p);
text(cx, cy, 'E', 'FontSize', 22, 'FontWeight', 'bold', 'Color', [0.1, 0.3, 0.6], 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');

% 3. Plot G1, G2, G3, G4 on top
G_labels = {'G_1', 'G_2', 'G_3', 'G_4'};
% To prevent overlapping, we manually set text offsets
x_offset = [-150, -150, 50, 50];
y_offset = [80, -80, 80, -80];

for k = 1:4
    plot(centers_x(k), centers_y(k), 'ko', 'MarkerFaceColor', 'r', 'MarkerSize', 6, 'HandleVisibility', 'off');
    text(centers_x(k) + x_offset(k), centers_y(k) + y_offset(k), G_labels{k}, 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'r');
    % Draw a small line connecting the text to the point
    plot([centers_x(k), centers_x(k) + x_offset(k)*0.7], [centers_y(k), centers_y(k) + y_offset(k)*0.7], 'r-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
end

xlabel('x (m)', 'FontSize', 14);
ylabel('y (m)', 'FontSize', 14);



legend('Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 12);

% Set axes limits to comfortably fit everything
axis([-1500 2800 -1800 1800]);

% Save the figure
saveas(gcf, 'region_E.png');
disp('Image saved to region_E.png');
exit;
