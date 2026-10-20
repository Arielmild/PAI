clc;
clear;


focal_length = 1;
camera_position = [0, 0, 0];
orientation_deg = 0;          % rotacion respecto a Y (°)
horizontal_displacement = 0; % Traslacion respecto a X
vehicle_distance = 10;
headlight_width = 0.6;
headlight_height = 0.3;
headlight_separation = 2;     


rectangle_points = [-headlight_width/2, -headlight_height/2, 0;
                     headlight_width/2, -headlight_height/2, 0;
                     headlight_width/2,  headlight_height/2, 0;
                    -headlight_width/2,  headlight_height/2, 0];
scene_points = [rectangle_points + [-headlight_separation/2, 0, 0];
                rectangle_points + [ headlight_separation/2, 0, 0]];
faces = [1, 2, 3, 4; 5, 6, 7, 8];

rotation = [cosd(orientation_deg), 0, sind(orientation_deg);
            0, 1, 0;
           -sind(orientation_deg), 0, cosd(orientation_deg)];
scene_points = scene_points * rotation.';
scene_points = scene_points + [horizontal_displacement, 0, vehicle_distance];
if any(scene_points(:,3) <= 0)
    error('All rectangle vertices must be in front of the camera (Z > 0).');
end

% Display 3D
figure(1);
clf;
patch('Vertices', scene_points, 'Faces', faces, ...
      'FaceColor', 'y', 'FaceAlpha', 0.5, 'EdgeColor', 'b');
title('3D Scene');
xlabel('X');
ylabel('Y');
zlabel('Z');
grid on;
axis equal;
view(3);
hold on;
plot3(camera_position(1), camera_position(2), camera_position(3), 'rx', 'MarkerSize', 10);
legend('Headlights', 'Camera');
for i = 1:size(scene_points, 1)
    plot3([camera_position(1), scene_points(i,1)], [camera_position(2), scene_points(i,2)], [camera_position(3), scene_points(i,3)], 'k--');
end
hold off;

% Step 2: Apply the pinhole camera model to each rectangle vertex.
image_plane = [];
for i = 1:size(scene_points, 1)
    X = scene_points(i, 1);
    Y = scene_points(i, 2);
    Z = scene_points(i, 3);
    u = (focal_length / Z) * X; % Horizontal 1D pinhole model.
    v = (focal_length / Z) * Y; % Retained to display shape and height.
    image_plane = [image_plane; u, v];
end

% Step 3: Display the projected rectangles (perspective quadrilaterals).
figure(2);
clf;
patch('Vertices', image_plane, 'Faces', faces, ...
      'FaceColor', 'y', 'FaceAlpha', 0.5, 'EdgeColor', 'b');
title('Image Plane');
xlabel('u (Image X)');
ylabel('v (Image Y)');
grid on;
axis equal;
hold on;
xline(0, 'r');
yline(0, 'r');
hold off;
