classdef Fire < handle
    %FIRE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        % Location of the origin of the fire
        origin;

        % Radius which is actually covered by fire
        radius; %[m]
        
        % Denotes the radius distance by which the fire spreaded over ...
        %the last minute.
        radius_increase; %[m]
        
        % Additional radius, on top of the fire radius, which denotes ...
        %the influence of the fire on the temperature
        add_temperature_radius; %[m]
        
        % Total radius, i.e the radius of the fire and add_temp_radius
        radius_influence; %[m]
    end
    
    properties (Constant) 
        % Temperature of the fire flames
        temperature = 800; %[Celsius]
        
        % Parameter which denotes how the fire influences the temperature ...
        %in its environment proportionally to its size.
        fire_temperature_influence = 1.5;
    end
    
    methods
        function obj = Fire(origin, radius, radius_increase)
            %FIRE Construct an instance of this class
            %   Detailed explanation goes here
            obj.origin = origin;
            obj.radius = radius;
            obj.radius_increase = radius_increase;
            
            obj.add_temperature_radius = obj.fire_temperature_influence * obj.radius;
            obj.radius_influence = obj.radius + obj.add_temperature_radius;
        end
        
        function increaseArea(obj, time_factor)
            % Spread rate fire according to "Otways Fire No. 22 – 1982/83 ...
            %Aspects of fire behaviour. Research Report No.20" (PDF). 
            % The fire spread is modelled with a maximum speed of 10.8km/h, ...
            %uniformely distributed and called every minute.
            obj.radius_increase = rand() * 180 * time_factor; %10.8km/h = 180m/min
            obj.radius = obj.radius + obj.radius_increase;
            obj.add_temperature_radius = obj.fire_temperature_influence * obj.radius;
            obj.radius_influence = obj.radius + obj.add_temperature_radius;
        end
        
        % Getter methods
        function location = getLocation(obj)
            location = obj.origin;
        end
        
        function radius = getRadius(obj)
            radius = obj.radius;
        end

        % Computes the temperature increase based on the respective sensor ...
        %location
        function temperature_increase = ...
                    getTemperatureIncreaseAtLocation(obj, ...
                                                     sensor_location, ...
                                                     environment_temperature)
            
            % Computes the temperature increase for a sensor with a given ...
            %distance from the origin of the fire (linear model). 
            distance = norm(sensor_location - obj.origin);
            
            if distance > obj.radius_influence
                temperature_increase = 0;
            % Checks if sensor is inside a fire
            elseif distance <= obj.radius
                temperature_increase = obj.temperature - environment_temperature;
            else
                temperature_increase = (obj.temperature - environment_temperature) ...
                                        - ((obj.temperature - environment_temperature) ...
                                             / obj.add_temperature_radius) ...
                                          * (distance - obj.radius);
            end 
        end
    end
end

