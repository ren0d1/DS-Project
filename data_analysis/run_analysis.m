clear all; % clear all variables from memory (needed for singleton to work properly)
clc; % clear command window


file_name = 'simulation-12-Jan-2021 02-12-54.mat';

a = Analyzer(file_name);
 
 
%get matrix
%in order of: true_positive false_positive true_negative false_negative
system_matrix = a.calc_sys_performance();

a.save_system_matrix(system_matrix);

%a.analyse_fires();

%a.analyse_fires()
% 
% closest_neighbors = a.get_closest_neighbor();
% 
% closest_neighbors =cell2mat(closest_neighbors);
% 
%mean(closest_neighbors)


