clear all; % clear all variables from memory (needed for singleton to work properly)
clc; % clear command window


file_name = 'simulation-11-Jan-2021 12-12-02.mat';

a = Analyzer(file_name);
 
 
%get matrix
%in order of: true_positive false_positive true_negative false_negative
system_matrix = a.calc_sys_performance();

a.save_system_matrix(system_matrix);

%a.analyse_fires()

