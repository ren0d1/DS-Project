classdef WeatherGenerator
    %WEATHERGENERATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        global_temperatures_min_matrix;
        global_temperatures_max_matrix;
        global_precipitations_matrix;
        global_humidity_min_matrix;
        global_humidity_max_matrix;
        global_sunrise_time_matrix;
        global_wind_min_matrix;
        global_wind_max_matrix;
    end
    
    methods
        function obj = WeatherGenerator(file_name)
            if isstring(file_name) && contains(file_name, ".dat")
                load(file_name, "-mat", "rainfall", "minhumidity", "maxhumidity", ...
                    "mintemp", "maxtemp", "minwind", "maxwind", "sunrise");
                obj.global_temperatures_min_matrix = mintemp;
                obj.global_temperatures_max_matrix = maxtemp;
                obj.global_precipitations_matrix = rainfall;
                obj.global_humidity_min_matrix = minhumidity;
                obj.global_humidity_max_matrix = maxhumidity;
                obj.global_wind_min_matrix = minwind;
                obj.global_wind_max_matrix = maxwind;
                obj.global_sunrise_time_matrix = sunrise;
            end
        end
        
        function [regional_temperatures_min_matrix, regional_temperatures_max_matrix, ...
                regional_humidity_min_matrix, regional_humidity_max_matrix, ...
                regional_wind_min_matrix, regional_wind_max_matrix] ...
                = regionalAlteration(obj, temperature_variance, humidity_variance, wind_variance)
            %regionalAlteration
            %   Uses the global weather information of the object and the ...
            %provided variance to generate slightly different data for a ...
            %region. 
            %   The important assumption is that the variance between ...
            %regions (part of a zone) is relatively low allowing the zone ...
            %(global) data to be considered as the mean of its different ...
            %composing regions.
            
            regional_temperatures_min_matrix = obj.global_temperatures_min_matrix;
            regional_temperatures_max_matrix = obj.global_temperatures_max_matrix;
            regional_humidity_min_matrix = obj.global_humidity_min_matrix;
            regional_humidity_max_matrix = obj.global_humidity_max_matrix;
            regional_wind_min_matrix = obj.global_wind_min_matrix;
            regional_wind_max_matrix =  obj.global_wind_min_matrix;

            % CODE TO ALTER DATA %
            % Min temperature
            for t = 1 : length(regional_temperatures_min_matrix)
                
                variation_of_the_day = temperature_variance * rand();
                current_min_temperature = regional_temperatures_min_matrix(t);
                regional_temperatures_min_matrix(t) = current_min_temperature + ...
                                                        variation_of_the_day;
            end
            
            % Max temperature
            for t = 1 : length(regional_temperatures_max_matrix)
                variation_of_the_day = temperature_variance * rand();
                current_max_temperature = regional_temperatures_max_matrix(t);
                regional_temperatures_max_matrix(t) = current_max_temperature + ...
                                                        variation_of_the_day;
            end
            
            % Min humidity
            for p = 1 : length(regional_humidity_min_matrix)
                variation_of_the_day = humidity_variance * rand();
                current_min_humidity = regional_humidity_min_matrix(p);
                regional_humidity_min_matrix(p) = current_min_humidity + ...
                                                    variation_of_the_day;
            end
            
            % Max humidity
            for p = 1 : length(regional_humidity_max_matrix)
                variation_of_the_day = humidity_variance * rand();
                current_max_humidity = regional_humidity_max_matrix(p);
                regional_humidity_max_matrix(p) = current_max_humidity + ...
                                                    variation_of_the_day;
            end
            
            % Min wind
            for w = 1 : length(regional_wind_min_matrix)
                variation_of_the_day = wind_variance * rand();
                current_min_wind = regional_wind_min_matrix(w);
                regional_wind_min_matrix(w) = current_min_wind + ...
                                                        variation_of_the_day;
            end
            
            % Max wind
            for w = 1 : length(regional_wind_max_matrix)
                variation_of_the_day = wind_variance * rand();
                current_max_wind = regional_wind_max_matrix(w);
                regional_wind_max_matrix(w) = current_max_wind + ...
                                                        variation_of_the_day;
            end    
        end
        
        function [hourly_temperatures_matrix, hourly_humidity_matrix, hourly_wind_matrix] ...
                = discretizeHourlyWeatherData(obj, min_temperatures_matrix,  ...
                                                max_temperatures_matrix, ...
                                                min_humidity_matrix, ...
                                                max_humidity_matrix, ...
                                                min_wind_matrix,...
                                                max_wind_matrix)
            %discretizeHourlyWeatherData
            %   Discretize the given input matrices from daily values to ...
            %hourly following the Sin (14R-1) method. Q-Sin method was ...
            %considered but the lack of average temperature data makes ...
            %its advantage null. 
            %   The day is divided using (t ? [1..24]).
            %   This assumes that noon is the TOD for the peak humidity ...
            %and midnight is the TOD for the nadir humidity.
            %   This assumes that 14h is the TOD for the peak temperature ... 
            %and sunrise-1 is the TOD for the nadir temperature.
            
            %   Reference paper:
            %   https://www.researchgate.net/publication/245383326_New_algorithm_for_generating_hourly_temperature_values_using_daily_maximum_minimum_and_average_values_from_climate_models
            
            amount_of_days = length(min_temperatures_matrix);
            
            hourly_temperatures_matrix = zeros(amount_of_days, 24);
            hourly_humidity_matrix = zeros(amount_of_days, 24);
            hourly_wind_matrix = zeros(amount_of_days, 24);
            
            for d = 1 : amount_of_days
                
                max_daily_wind = min_wind_matrix(d);
                min_daily_wind = max_wind_matrix(d);
                
                %get time of lowest temperature
                t_lowest = obj.global_sunrise_time_matrix(d) - 1;
                
                for t = 1:24
                    %CASE 1
                    if t < t_lowest
                       %first edge case
                       if d ==1
                           temp_prev = max_temperatures_matrix(amount_of_days);
                       else
                           temp_prev = max_temperatures_matrix(d-1);
                       end
                       
                       temp_next = min_temperatures_matrix(d);
                       
                       %10 hours from the previous day have always passed,
                       %since max is always supposed to be at 14
                       t_prev = 14;
                       
                       t_next = t_lowest;
                    %CASE 2   
                    elseif t < 14
                        temp_prev = min_temperatures_matrix(d);
                        
                        temp_next = max_temperatures_matrix(d);
                        
                        t_prev = t_lowest;
                        
                        t_next = 14;
                    %CASE 3, later than 14    
                    else
                       %second edge case
                       if d ==amount_of_days
                          temp_next = min_temperatures_matrix(1);

                          t_next =  obj.global_sunrise_time_matrix(1) - 1;
                       else
                           temp_next = min_temperatures_matrix(d+1);
                           t_next =  obj.global_sunrise_time_matrix(d+1) - 1;
                       end
                       
                       temp_prev = max_temperatures_matrix(d);

                       t_prev = 14;
                    end
                    
                    temperature_at_time_t = WeatherGenerator.getValueAtTimeT(...
                            t, temp_next, temp_prev, ...
                            t_next, t_prev);
                        
                    hourly_temperatures_matrix(d, t) = temperature_at_time_t;
                                       
                    % Humidity discretization
                    if t < 12
                        humid_next = min_humidity_matrix(d);
                        humid_prev = max_humidity_matrix(d);
                        t_next = 12;
                        t_prev = 24;
                    else
                        humid_prev = min_humidity_matrix(d);
                        t_prev = 12;
                        t_next = 24;
                        if d + 1 < amount_of_days
                            humid_next = max_humidity_matrix(d + 1);
                        else
                            humid_next = max_humidity_matrix(1);
                        end
                    end
                    
                    humidity_at_time_t = WeatherGenerator.getValueAtTimeT(...
                                            t, humid_next, humid_prev, ...
                                            t_next, t_prev);
                    
                    % Corrects data to match min and max humidity
                    if humidity_at_time_t > max_humidity_matrix(d)
                        humidity_at_time_t = max_humidity_matrix(d);
                    elseif humidity_at_time_t < max_humidity_matrix(d)
                        humidity_at_time_t = max_humidity_matrix(d);
                    end
                    
                    hourly_humidity_matrix(d, t) = humidity_at_time_t;
                    
                    % Wind discretization:
                    %Deviates randomly between max wind and min wind
                    %measured.
                    wind_at_time_t = min_daily_wind + rand * (max_daily_wind - min_daily_wind);
                    hourly_wind_matrix(d,t) = wind_at_time_t;
                end
                
            end
                
        end
        
    end
    
    
    
    methods(Static)
        function value_at_time_t = getValueAtTimeT(t, value_next, value_prev, ...
                                    t_next, t_prev)
            %getTemperatureAtTimeT
            %   Uses the Sin (14R-1) method to get the temperature at the ...
            %specified time t           
            value_at_time_t = ((value_next + value_prev) / 2) - ...
                ((value_next - value_prev) / 2) * ...
                cos(pi * (t - t_prev) / (t_next - t_prev));
        end
    end
end