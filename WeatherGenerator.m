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
                regional_humidity_min_matrix, regional_humidity_max_matrix] ...
                = regionalAlteration(obj, temperature_variance, humidity_variance)
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

            % Code to alter data          
            for t = 1 : length(regional_temperatures_min_matrix)
                variation_of_the_day = temperature_variance * rand();
                current_min_temperature = regional_temperatures_min_matrix(t);
                regional_temperatures_min_matrix(t) = current_min_temperature + ...
                                                        variation_of_the_day;
            end
            
            for t = 1 : length(regional_temperatures_max_matrix)
                variation_of_the_day = temperature_variance * rand();
                current_max_temperature = regional_temperatures_max_matrix(t);
                regional_temperatures_max_matrix(t) = current_max_temperature + ...
                                                        variation_of_the_day;
            end
            
            for p = 1 : length(regional_humidity_min_matrix)
                variation_of_the_day = humidity_variance * rand();
                current_min_humidity = regional_humidity_min_matrix(p);
                regional_humidity_min_matrix(p) = current_min_humidity + ...
                                                    variation_of_the_day;
            end
            
            for p = 1 : length(regional_humidity_max_matrix)
                variation_of_the_day = humidity_variance * rand();
                current_max_humidity = regional_humidity_max_matrix(p);
                regional_humidity_max_matrix(p) = current_max_humidity + ...
                                                    variation_of_the_day;
            end
        end
        
        function [hourly_temperatures_matrix, hourly_humidity_matrix] ...
                = discretizeHourlyWeatherData(obj, min_temperatures_matrix,  ...
                                                max_temperatures_matrix, ...
                                                min_humidity_matrix, ...
                                                max_humidity_matrix)
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
            
            for d = 1 : amount_of_days
                for t = 1 : 24    
                    % Temperature discretization
                    if t < 14
                        temp_next = max_temperatures_matrix(d);
                        temp_prev = min_temperatures_matrix(d);
                        t_next = 14;
                        t_prev = obj.global_sunrise_time_matrix(d) - 1;
                    else
                        temp_prev = max_temperatures_matrix(d);
                        t_prev = 14;
                        if d + 1 < amount_of_days
                            temp_next = min_temperatures_matrix(d + 1);
                            t_next = obj.global_sunrise_time_matrix(d + 1) - 1;
                        else
                            temp_next = min_temperatures_matrix(1);
                            t_next = obj.global_sunrise_time_matrix(1) - 1;
                        end
                    end
                    
                    temperature_at_time_t = WeatherGenerator.getValueAtTimeT(...
                                                t, temp_next, temp_prev, ...
                                                t_next, t_prev);
                    
                    % Corrects data to match min and max temp
                    if temperature_at_time_t > max_temperatures_matrix(d)
                        temperature_at_time_t = max_temperatures_matrix(d);
                    elseif temperature_at_time_t < min_temperatures_matrix(d)
                        temperature_at_time_t = min_temperatures_matrix(d);
                    end
                    
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