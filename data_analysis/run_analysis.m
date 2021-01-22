clear all; % clear all variables from memory (needed for singleton to work properly)
clc; % clear command window


file_name = 'simulation-22-Jan-2021 09-27-38.mat';

a = Analyzer(file_name);
 

location = [8 30];




tick = 481;

%a.get_sensor_pos_alarm(tick);
%a.get_closest_sensor(location, tick);

%temperature_increase = 0.6 * exp(-5.8/1.5)*(334 - 16)
%get matrix
%in order of: true_positive false_positive true_negative false_negative
%system_matrix = a.calc_sys_performance();
% 
%a.save_system_matrix(system_matrix);
% 
a.analyse_fires();
% 
% %a.analyse_fires()
% % 
%closest_neighbors = a.get_closest_neighbor();
% % 
%closest_neighbors =cell2mat(closest_neighbors);
% % 
%mean(closest_neighbors)


