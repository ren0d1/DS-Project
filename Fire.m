
% paper to quote for flame temperature: flame temperatur and residence time
% of fires in dry eucalypt forest. 
% justification: Eucalypts are iconic Australian forest trees. Ninety-two million hectares of the Eucalypt forest type occurs in Australia, and forms three-quarters of the total native forest area. The term 'eucalypt' includes approximately 900 species in the three genera Eucalyptus, Corymbia and Angophora.

%big_fire = Fire([0,0],2.0,1.0);



classdef Fire < handle
    %FIRE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = public)
        % Location of the origin of the fire
        origin;

        % Radius which is actually covered by fire
        radius; %[m]
        
        % Denotes the radius distance by which the fire spreaded over ...
        %the last minute.
        radius_increase; %[m]
        
        % Additional radius, on top of the fire radius, which denotes ...
        %the influence of the fire on the temperature
        add_temperature_radius = 10; %[m]
        
        % Total radius, i.e the radius of the fire and add_temp_radius
        radius_influence; %[m]
        %the height of the fire.
        %each fire is initialized with a height of 0.5 meters
        height = 0.5; %[m]
        %temperature of the fire
        temperature;
        
        time_alive = 0;
        
        %subzone to which the fire origin "belongs"
        sz_num;
        
        %denotes the wind at each time instance
        local_wind;
        %denotes the humidity at each time instance
        local_humiditiy;
    end
    
    properties (Constant) 
        % Temperature of the fire flames
        %temperature = 800; %[Celsius]
        
        % Parameter which denotes how the fire influences the temperature ...
        %in its environment proportionally to its size.
        %fire_temperature_influence = 1.5;
        
        %based on the newcastle weather data, humidity has a high
        %correlation to the 'fire season', while wind is almost constant
        %over the whole year, ranging from 6.9 to 8.2 hours. 
        %source: https://weatherspark.com/y/144563/Average-Weather-in-Newcastle-Australia-Year-Round
        
        %Thus, we put the humidity influence relatively high.
        
        humidity_influence = 0.4;
        
    end
    
    methods
        
        
        
        
        function obj = Fire(origin, radius, radius_increase, sz_num, temperature, humidity, wind)
            %FIRE Construct an instance of this class
            %   Detailed explanation goes here
            obj.origin = origin;
            
            obj.radius = radius;
            
            obj.sz_num = sz_num;
            
            obj.radius_increase = radius_increase;
            
            obj.local_humiditiy = humidity;
            
            obj.local_wind = wind;
            
            obj.temperature = 334-258 * log(0.5 / obj.height);
            
            
            % the influence of the temperature on its environment, measured
            % from the firefront
            obj.add_temperature_radius = 10; %[m]
            
            obj.radius_influence = obj.radius + obj.add_temperature_radius;
       
        end
        
        function updateWeather(obj, wind, humidity)
            
            obj.local_wind = wind;
            
            obj.local_humiditiy = humidity;
           
            
        end    
        
        
        
        function increaseArea(obj, time_factor)
            % Spread rate fire according to "Otways Fire No. 22 – 1982/83 ...
            %Aspects of fire behaviour. Research Report No.20" (PDF). 
            % The fire spread is modelled with a maximum speed of 10.8km/h, ...
            %uniformely distributed and called every minute.

            
            parameter_humidity = (1 - obj.local_humiditiy) * obj.humidity_influence;
            
            %according to the official weather data, 8.2 miles per hour is
            %the max wind speed. source: https://weatherspark.com/y/144563/Average-Weather-in-Newcastle-Australia-Year-Round
            
            parameter_wind = (obj.local_wind / 8.2) * (1 - obj.humidity_influence);
            
    
            obj.radius_increase = (parameter_wind + parameter_humidity) * 180 * time_factor ; %10.8km/h = 180m/min
            
            
            %change the height of the fire and radius increase 
            if obj.time_alive < 10
                
                %max height of 2.3 metres in the first 10 minutes
                obj.height = 0.5 + rand() * 1.8;
                
            elseif obj.time_alive <30
                
                %max height of 2.3 metres in the first 10 minutes
                obj.height = 1 + rand() * 4;
                
            else
                
                %max height of 2.3 metres in the first 10 minutes
                obj.height = 5 + rand() * 6;
                
            end                 
            
            %update temperature based on new fire height
            obj.temperature = 334-258 * log(0.5 / obj.height);
            %update radius based on obtained radius_increase
            obj.radius = obj.radius + obj.radius_increase;
            
            %obj.add_temperature_radius = obj.fire_temperature_influence * obj.radius;
            obj.radius_influence = obj.radius + obj.add_temperature_radius;
            
            obj.time_alive = obj.time_alive + 1;
            
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
                                                 
              distance = norm(sensor_location - obj.origin);
                
              if distance > obj.radius_influence

                  temperature_increase = 0;
                  
              elseif distance <= obj.radius
                      
                  temperature_increase = max([obj.temperature - environment_temperature, 0]);
      
              else
                  
                temperature_increase = (obj.temperature - environment_temperature) * (1- ((distance - obj.radius) / obj.add_temperature_radius));
              
              end
                                   
           
%             % Computes the temperature increase for a sensor with a given ...
%             %distance from the origin of the fire (linear model). 
%             distance = norm(sensor_location - obj.origin);
%             
%             if distance > obj.radius_influence
%                 temperature_increase = 0;
%             % Checks if sensor is inside a fire
%             elseif distance <= obj.radius
%                 temperature_increase = obj.temperature - environment_temperature;
%             else
%                 temperature_increase = (obj.temperature - environment_temperature) ...
%                                         - ((obj.temperature - environment_temperature) ...
%                                              / obj.add_temperature_radius) ...
%                                           * (distance - obj.radius);
            
%            end     
        end
    end
end


