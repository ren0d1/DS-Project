classdef FireGenerator < handle
    %FIREGENERATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        fireProbability;
    end
    
    methods
        function obj = FireGenerator()
            obj.fireProbability = 0;
        end
        
        function fire_probability = getFireProbability(obj)
            fire_probability = obj.fireProbability;
        end
        
        function updateFireProbability(obj, current_temperature, current_humidity, current_wind)
            obj.fireProbability = 0.01; % Calculate fire probability properly (todo)
        end
        
        function generated_fire = generateFire(~, location)
            radius = randi([1, 5],1);
            radius_increase = radius;
            %radius = 1;
            generated_fire = Fire(location, radius, radius_increase);
        end
    end
end