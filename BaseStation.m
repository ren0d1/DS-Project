classdef BaseStation < handle
    %BASESTATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        fires_info;
        dead_sensors_info;
    end
    
    methods (Access = private)
        function obj = BaseStation()
            %BASESTATION Construct an instance of this class
            %   Detailed explanation goes here
        end
    end
    
    methods(Static)
        % Concrete implementation.  See Singleton superclass.
        function obj = getInstance()
            persistent uniqueInstance;
            
            if isempty(uniqueInstance) || ~isvalid(uniqueInstance)
                uniqueInstance = BaseStation();
            end
            
            obj = uniqueInstance;
        end
    end
    
    methods        
        function listen_for_alert(obj, alert_type, information)
            switch alert_type
               case 1
                  obj.fires_info{end+1} = information;
               case 2
                  dead_sensor_already_known = false;
                  
                  for dsii = 1 : length(obj.dead_sensors_info)
                      % If Xs match
                      if obj.dead_sensors_info{dsii}(1) == information(1)
                          % Check if Ys match
                          if obj.dead_sensors_info{dsii}(2) == information(2)
                              dead_sensor_already_known = true;
                              break;
                          end
                      end
                  end
                  
                  if ~dead_sensor_already_known
                      obj.dead_sensors_info{end+1} = information;
                  end
               otherwise
                  error('Alert type unknown.')
            end
        end
        
        function sensors_info = get_sensors_to_replace(obj)
            sensors_info = obj.dead_sensors_info;
            obj.dead_sensors_info = {};
        end
    end
end

