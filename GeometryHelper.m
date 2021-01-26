classdef GeometryHelper
    %GEOMETRYHELPER Summary of this class goes here
    %   This class contains helpful geometrical functions.
    methods (Static)
        function [m, b] = findLineSlopeAndIntersect(x1, y1, x2, y2)
            m = (y2-y1) / (x2-x1);
            b = y1 - m*x1;
        end
        
        function [x, y] = findInterpolatedValue(m, b, val)
            y = m*val + b;
            x = (val - b) / m;
        end
        
        function inside = isPointInsideCircle(center_coordinates, radius, ...
                                            point_coordinates)
            inside = false;                            
                                        
            % Retrieve X, Y values for the coordinates formatted as an ...
            %array [x, y].
            center_x = center_coordinates(1);
            center_y = center_coordinates(2);
                            
            point_x = point_coordinates(1);
            point_y = point_coordinates(2);
            
            % Calculate the distance
            distance = power(radius, 2) - (power((center_x - point_x), 2) + ...
                power((center_y - point_y), 2));

            if(distance>=0)
              inside = true; % We consider any point on the circumference ...
                             %to be inside as well.
            end
        end
    end
end

