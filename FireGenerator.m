classdef FireGenerator < handle
    %FIREGENERATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        fireProbability;
    end
    
    properties (Constant)
        max_fire_prob = 0.5;
        
        temperature_influence = 0.33;
        
        humidity_influence = 0.33;
        
        wind_influence = 0.33;
        % Min & max temperature/humidity according to:
        %https://weatherspark.com/y/144563/Average-Weather-in-Newcastle-Australia-Year-Round
        
        max_temperature = 43.6; %[Celsius]
        min_temperature = -4.6; %[Celsius]

        max_humidity = 92; %[%]
        min_humidity = 9; %[%]  
    end
    
    methods (Static)
        function wind_parameter = retrieve_windpar(wind)
            if wind < 2 
                wind_parameter = 0;
            elseif wind <= 5
                wind_parameter = 0.2;
            elseif wind <= 11
                wind_parameter = 0.4;
            elseif wind <= 19
                wind_parameter = 0.6;
            elseif wind <= 28
                wind_parameter = 0.8;
            elseif wind <= 38
                wind_parameter = 1.0;
            elseif wind <= 49
                wind_parameter = 0.86;
            elseif wind <= 61
                wind_parameter = 0.71;
            elseif wind <= 74
                wind_parameter = 0.57;
            elseif wind <= 88
                wind_parameter = 0.43;
            elseif wind <= 102 
                wind_parameter = 0.29;
            elseif wind <= 117
                wind_parameter = 0.14;
            else
                wind_parameter = 0;
            end
        end
    end
    
    methods
        function obj = FireGenerator()
            obj.fireProbability = 0;
        end
        
        function fire_probability = getFireProbability(obj)
            fire_probability = obj.fireProbability;
        end
        
        function updateFireProbability(obj, current_temperature, current_humidity, current_wind)
            % Reasoning: humidity parameter is max if current_humidty =
            %min_humidity, which is the annualy minimum of the weather data
            %and temperature parameter is max if the current_temperature =
            %max_temperature, and 0 if current_temperature = min_temperature,
            %which is the annually minimum of the weather data
            
            
            wind_parameter = FireGenerator.retrieve_windpar(current_wind);
            
            %Humidity is scaled to %, thats why its divided by 100
            humidity_parameter = 1 - ((current_humidity - obj.min_humidity) / ...
                       (obj.max_humidity - obj.min_humidity));
            
            temperature_parameter = (current_temperature - obj.min_temperature) / ...
                 (obj.max_temperature - obj.min_temperature);
            
             
            fire_prob = (humidity_parameter * obj.humidity_influence + ...
                        temperature_parameter * obj.temperature_influence + ...
                        wind_parameter * obj.wind_influence) * obj.max_fire_prob;
             
            if fire_prob < 0
                obj.fireProbability = obj.max_fire_prob;
            else
                obj.fireProbability = fire_prob;
            end
        end
        
        function generated_fire = generateFire(~, location, sz_num, ...
                                                humidity, wind, temperature)
            radius = 0.3 + 0.5 * rand;
            radius_increase = radius;
            %radius = 1;
            generated_fire = Fire(location, sz_num, radius, radius_increase, ...
                                    humidity, wind, temperature);
        end
    end
end