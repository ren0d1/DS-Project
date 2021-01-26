classdef BaseStation < handle
    %BASESTATION Summary of this class goes here
    %   This class simulate the entity (central or not) that is ...
    %notified when a fire is detected and which then is tasked to ...
    %call the necessary entities to deal with the fires.
    
    properties (Access = private)
        location_of_sensors_which_detected_fire;
        dead_sensors_info;
        dead_sensors_needing_replacement;
    end
    
    methods (Access = private)
        function obj = BaseStation()
            %BASESTATION Construct an instance of this class
        end
    end
    
    methods(Static)
        % Singleton pattern
        function obj = getInstance()
            persistent uniqueInstance;
            
            if isempty(uniqueInstance) || ~isvalid(uniqueInstance)
                uniqueInstance = BaseStation();
            end
            
            obj = uniqueInstance;
        end
    end
    
    methods        
        function listenForAlert(obj, alert_type, information)
            switch alert_type
               case 1
                  obj.location_of_sensors_which_detected_fire{end+1} = information;
               case 2
                  dead_sensor_already_known = false;
                  
                  for dsii = 1 : length(obj.dead_sensors_info)
                      if obj.dead_sensors_info{dsii}.uuid == information.uuid
                         dead_sensor_already_known = true;
                         break;
                      end
                  end
                  
                  if ~dead_sensor_already_known
                      obj.dead_sensors_info{end+1} = information;
                      obj.dead_sensors_needing_replacement{end+1} = ...
                          information.location;
                  end
               otherwise
                  error('Alert type unknown.')
            end
        end
        
        function sensors_info = getSensorsToReplace(obj)
            sensors_info = obj.dead_sensors_needing_replacement;
            obj.dead_sensors_needing_replacement = {};
        end
        
        function location_of_sensors_which_detected_fire = ...
                    getLocationOfSensorsWhichDetectedFire(obj)
                
            location_of_sensors_which_detected_fire = ...
                obj.location_of_sensors_which_detected_fire;
            
            obj.location_of_sensors_which_detected_fire = {};
        end
    end
end

