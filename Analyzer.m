classdef Analyzer
    %ANALIZER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        % Simulation states
        sensors_per_subzone_at_tick_t = {};
        fires_at_tick_t = {};
    end
    
    methods
        function obj = Analyzer(sensors_history, fires_history)
            %ANALIZER Construct an instance of this class
            %   Detailed explanation goes here
            obj.sensors_per_subzone_at_tick_t = sensors_history;
            obj.fires_at_tick_t = fires_history;
        end
        
        function tbd = analyze(obj)
            %ANALYZE Summary of this method goes here
            %   Detailed explanation goes here
            obj.sensors_per_subzone_at_tick_t
            obj.fires_at_tick_t
        end
    end
end

