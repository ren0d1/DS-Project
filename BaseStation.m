classdef BaseStation
    %BASESTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        fires;
        dead_sensors_uuid;
    end
    
    methods
        function obj = BaseStation()
            %BASESTATION Construct an instance of this class
            %   Detailed explanation goes here
        end
        
        function listen_for_alert(obj, alert_type, information)
            switch alert_type
               case 1
                  obj.fires{end+1} = information;
               case 2
                  obj.dead_sensors_uuid{end+1} = information;
                ...
               otherwise
                  error('Alert type unknown.')
            end
        end
    end
end

