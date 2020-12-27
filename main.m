%clear all; % clear all variables from memory
clc; % clear command window

% Configuration properties
%{
    properties (Constant)
        zones_weather_file = "newcastle_australia_weather_data.dat";
        zone_width = 80000; %m
        zone_height = 85000; %m
        years = 1; % amount of years available in the datafile
        
        % humidity_variance, temperature_variance
        subzones_variances = [3, -1; 2, 5; 5, -3];
        
        simulation_time = 5; % In days
        sensing_rate = 1; % In minutes for simulation purposes
        starting_day = 330; % [1..years * 365] ? starting_day + simulation_time <= years * 365
    end
%}

zones_weather_file = "newcastle_australia_weather_data.dat";
years = 1; % amount of years available in the datafile
%subzones_variances = [-1, 3; 5, 2; -3, 5];
subzones_variances = [-1, 3, 1;...
                    5, 2, 1]; % temperature_variance, humidity_variance, wind_variance. 
                              % each row corresponds to one subzone. 

zone_image = "sub_area_of_interest";
%zone_width = 20000; %m
%zone_height = 21250; %m
zone_width = 40; %m
zone_height = 42.5; %m

simulation_time = 5; % In days
sensing_rate = 1; % In minutes for simulation purposes

starting_day = 331; % [1..years * 365] ? starting_day + simulation_time <= years * 365

plane_mode = false; % Defines if the sensors are dropped based on chosen ...
                    %plane path or randomly scattered across the subzones.

s = Simulator(zones_weather_file, zone_image, zone_width, zone_height, ...
                years, subzones_variances, simulation_time, sensing_rate, ...
                starting_day, plane_mode);
[sensors_history, fires_history] = s.simulation();

a = Analyzer(sensors_history, fires_history);
tbd = a.analyze();
