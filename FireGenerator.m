classdef FireGenerator < handle
    %FIREGENERATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        fireProbability;
    end
    
    properties (Constant)
       
        max_fire_prob = 0.01;
        
        temperature_influence = 0.5
        
        humidity_influence = 0.5
        
        %max & min temperature /humidity according to:
        % source: https://weatherspark.com/y/144563/Average-Weather-in-Newcastle-Australia-Year-Round
        
        max_temperature = 81; %[F]
        min_temperature = 66; %[F]

        max_humidity = 49; %[%]
        min_humidity = 0; %[%]  
        
        
        
    end
    
    methods
        function obj = FireGenerator()
            obj.fireProbability = 0;
        end
        
        function fire_probability = getFireProbability(obj)
            fire_probability = obj.fireProbability;
        end
        %reasoning: humidity parameter is max if current_humidty =
        %min_humidity, which is the annualy minimum of the weather data
        %and temperature parameter is max if the current_temperature =
        %max_temperature, and 0 if current_temperature = min_temperature,
        %which is the annually minimum of the weather data
        
        function updateFireProbability(obj, current_temperature, current_humidity, current_wind)
            
            humidity_parameter = obj.humidity_influence * ( 1 - ((current_humidity - obj.min_humidity) / (obj.max_humidity - obj.min_humidity)))
            
            temperature_parameter = obj.temperature_influence * ((current_temperature - obj.min_temperature) / (obj.max_temperature - obj.min_temperature))
            
            fire_prob = (humidity_parameter + temperature_parameter) * obj.max_fire_prob;
            
            
            if fire_prob < 0
                
                obj.fireProbability = obj.max_fire_prob;
                
            else
                
                obj.fireProbability = fire_prob;
                
            end
        end
        
        function generated_fire = generateFire(location, sz_num, temperature, humidity, wind)
            radius = randi([1, 5],1);
            radius_increase = radius;
            %radius = 1;
            generated_fire = Fire(location, radius, radius_increase, sz_num, temperature, humidity, wind);
        end
    end
end