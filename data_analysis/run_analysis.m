clear all; % clear all variables from memory (needed for singleton to work properly)
clc; % clear command window

% Get matrices
%specify filename that shall be analyzed
file_name = 'simulation-24-Jan-2021 13-29-51.mat';

a = Analyzer(file_name);

%a.get_sensor_pos_alarm(tick);
%a.get_closest_sensor(location, tick);

% In order of: true_positive false_positive true_negative false_negative
system_matrix = a.calcSysPerformance();
a.saveSystemMatrix(system_matrix);

a.analyseFires();

closest_neighbors = a.getClosestNeighbor();
closest_neighbors = cell2mat(closest_neighbors);
mean_of_closest_distance_from_fire_to_sensor = mean(closest_neighbors)


