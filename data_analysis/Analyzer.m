classdef Analyzer < handle
   
    properties (Access = private)
        
        sensors_history;
        
        fires_history;
        
        file_name; 
    end
    
    properties (Constant)
       
        threshold = 10;
    end
    
    
    methods (Static)
        %helper function to retrieve the sensors present throughout the
        %simulation
        function sensor_uuids = retrieve_uuids(sensors_history)

              % Retrieve all sensors

              sensor_uuids = {};

              for tick = 1:length(sensors_history)

                % Retrieve amount of subzones
                sensors_per_subzone_data = sensors_history{tick};

                subzones = size(sensors_per_subzone_data);
                subzones = subzones(1);

                for sz=1:subzones

                   sensors_placeholder = size(sensors_per_subzone_data);

                   sensors_placeholder = sensors_placeholder(2); 

                   for s =1:sensors_placeholder

                      if isempty(sensors_per_subzone_data{sz,s})

                          continue
                      end

                      uuid = sensors_per_subzone_data{sz,s}.uuid;

                      already_known = false;

                      for u = 1:length(sensor_uuids)

                          if isequal(sensor_uuids{u}, uuid)

                              already_known = true;
                          end

                      end

                      if ~already_known

                          sensor_uuids{end+1} = uuid;

                      end


                    end 
                end

              end
        end         
     
        
    end
    

    methods 
        
        function obj =  Analyzer(file_string)
            
           load(file_string, 'sensors_history', 'fires_history')
           
           obj.sensors_history = sensors_history;
           obj.fires_history = fires_history;
           
           obj.file_name = file_string;
            
        end
        
        function saveSystemMatrix(obj,system_matrix)

            name = split(obj.file_name, ".");

            name_array = ["system_matrix_", name{1}, ".txt"];
            filename = join(name_array, "");
            
            dlmwrite(filename,system_matrix)


        end 
        %returns the closest sensor for each fire occured during simulation
        function closest_neighbors = getClosestNeighbor(obj)
            
           closest_neighbors = {};
           fire_list = {};
           
           for t = 1:length(obj.fires_history)
               
               if ~isempty(obj.fires_history{t})
                   
                    for f = 1:length(obj.fires_history{t})

                        % Check if already exists in list
                        already_known = false;

                        for s = 1:length(fire_list)

                            if isequal(fire_list{s}.location, obj.fires_history{t}{f}.location)

                                % Already in list
                                already_known = true;   
                                
                            end
                            
                        end
                        
                        if ~already_known
                            % Insert new fire
                            cur_fire_loc = obj.fires_history{t}{f}.location;
                            cur_fire_radius = obj.fires_history{t}{f}.radius;
                            
                            cur_fire.location = cur_fire_loc;
                            fire_list{end+1} = cur_fire;
                            
                            

                            % Loop over all sensors and get closest one.
                            sensors_per_subzone_data = obj.sensors_history{t};

                            subzones = size(obj.sensors_history{t},1);

                            distance = 10000;
                            for sz=1:subzones

                                sensors_placeholder = size(obj.sensors_history{t},2);

                                for s = 1:sensors_placeholder

                                    if isempty(sensors_per_subzone_data{sz,s})

                                        continue
                                    end

                                  sensor = sensors_per_subzone_data{sz,s};

                                  curr_distance = norm(sensor.location - cur_fire_loc) - cur_fire_radius;
                                  
                                  if curr_distance < distance
                                     
                                     distance = curr_distance;
                                  end
                                  
                                  
                                end
                                
                            end
                            
                            closest_neighbors{end+1} = distance;
 
                            
                        end
                        
                    end
               end
               
           end
            
        end
        
        function getSensorPosAlarm(obj,tick)
            for sz =  1:2
               counter = 0; 
               for s = 1:20
                   
                  sensor = obj.sensors_history{1,tick}{sz,s}; 
                    
                  if isempty(sensor) | counter > 0
                        
                    continue
                  end 
                  
                  if sensor.alarm_status

                      counter = counter +1;
                      sensor.temperature_list

                  end 
                  
               end
                
            end
            
        end
        
        %returns the closest sensor for a fire at tick t; used for system
        %matrix
        function curr_sensor = getClosestSensor(obj, location, tick)
            
            distance = 1000;
            
            curr_sensor = {};
            for sz = 1:2
                
               
                for s = 1:20
                    
                    sensor = obj.sensors_history{1,tick}{sz,s};
                    
                    if isempty(sensor)
                        
                        continue
                        
                    end
                    dist = norm(sensor.location - location);
                    
                    if dist < distance
                        
                        distance = dist;
                        
                        curr_sensor = sensor;
                        
                    end
                    
                end
                
            end
            
            curr_sensor.temperature_list
            
            curr_sensor.location
            
            distance
            
            
        end
        
        
  
        %returns the total number of fires during simulation, and their
        %respective time alives, and the radius till they were detected.
        function fire_struct = retrieveFireData(obj)

            fire_struct = {};

            for t = 1:length(obj.fires_history)

               % If there is a fire at time instance t, check it 
               if ~isempty(obj.fires_history{t})


                    for f = 1:length(obj.fires_history{t})

                        % Check if already exists in list
                        already_known = false;

                        for s = 1:length(fire_struct)

                            if isequal(fire_struct{s}.location, obj.fires_history{t}{f}.location)

                                % Already in list
                                already_known = true;

                                % Update radius and time alive
                                fire_struct{s}.time_alive = obj.fires_history{t}{f}.time_alive;
                                fire_struct{s}.radius = obj.fires_history{t}{f}.radius;

                            end

                        end

                        if ~already_known

                            % Retrieve data and insert
                            current_fire.location = obj.fires_history{t}{f}.location;

                            current_fire.time_alive = obj.fires_history{t}{f}.time_alive;

                            current_fire.radius = obj.fires_history{t}{f}.radius;                   

                            fire_struct{end+1} = current_fire;
                        end
                    end 
               end
            end
        end 
        %outputs relevant numbers to the user.
        function analyseFires(obj)
        
            fire_struct = obj.retrieveFireData();
            
            % Get number of fires
            disp('number of fires');
            num_fires = length(fire_struct)
            
            % Prepare data for plotting
            radia = zeros(1,num_fires);
            time_alives = zeros(1,num_fires);
            
            for f =1:num_fires
                radia(1,f) = fire_struct{f}.radius;
                
                time_alives(1,f) = fire_struct{f}.time_alive;               
            end
            
            % Obtain x axis
            x = linspace(1,num_fires, num_fires);
            
            %scatter(x,time_alives)
            
            %scatter(x,radia)
            disp('mean of time alives')
            mean(time_alives)
            
            disp('mean of radia')
            mean(radia)
            
            disp('max time alive')
            
            max(time_alives)
            
            disp('max_fire_size')
            
            max(radia)          
        end

        %retrieves the performance matrices for each sensor.
        function performances = retrieveSensorPerformances(obj,sensor_uuids, sensors_history, fires_history)
              % Set up data to be returned

              true_positives = zeros(1,length(sensor_uuids));

              false_positives = zeros(1,length(sensor_uuids));

              true_negatives = zeros(1,length(sensor_uuids));

              false_negatives = zeros(1,length(sensor_uuids));

            % Time
            for tick = 1:length(sensors_history)

               % Retrieve amount of subzones
               sensors_per_subzone_data = sensors_history{tick};

               subzones = size(sensors_history{tick},1);


               for sz=1:subzones

                   sensors_placeholder = size(sensors_history{tick},2);

                   for s = 1:sensors_placeholder

                      if isempty(sensors_per_subzone_data{sz,s})

                          continue
                      end

                      sensor = sensors_per_subzone_data{sz,s};

                      distance = 1000;
                      % Get, if existing, the distance to the closest ...
                      %firefront
                      for f = 1:length(fires_history{tick})

                          fire = fires_history{tick}{f};

                          f_distance = norm(sensor.location - fire.location) - fire.radius;

                          if f_distance < distance

                              distance = f_distance;
                          end

                      end


                      for i = 1:size(sensor_uuids,2)

                          if isequal(sensor_uuids{i}, sensor.uuid)

                              index = i;

                          end
                      end

                      if sensor.alarm_status && distance < obj.threshold

                          true_positives(1,index) =  true_positives(1,index) + 1;

                      elseif sensor.alarm_status && distance > obj.threshold

                          false_positives(1,index) = false_positives(1,index) + 1;
                      
                      % If the sensor hasn´t detected the fire till ...
                      %then, its considered as too late.    
                      elseif ~sensor.alarm_status && distance <= obj.threshold

                           false_negatives(1,index) = false_negatives(1,index) + 1;

                      elseif ~sensor.alarm_status && distance > obj.threshold

                          true_negatives(1,index) = true_negatives(1,index) + 1;
                      end


                   end
               end
            end
            
            performances = [true_positives false_positives true_negatives false_negatives];
        end 
        %calculates the overal systemperformance accordingly to the
        %established rules.
        function system_matrix = calcSysPerformance(obj)

            true_positive = 0;
            false_positive = 0;
            true_negative = 0;
            false_negative = 0;
            
            false_positives_history = zeros(1,length(obj.sensors_history));
            false_positives_sz_1 = 0;
            
            false_positives_sz_2 = 0;
            % Time
            for tick = 1:length(obj.sensors_history)

               % Retrieve amount of subzones
               sensors_per_subzone_data = obj.sensors_history{tick};

               subzones = size(sensors_per_subzone_data);
               subzones = subzones(1);

               for sz=1:subzones

                   sensors_placeholder = size(sensors_per_subzone_data);

                   sensors_placeholder = sensors_placeholder(2); 


                   for s =1:sensors_placeholder

                      if isempty(sensors_per_subzone_data{sz,s})

                          continue
                      end

                      sensor = sensors_per_subzone_data{sz,s};

                      distance = 1000;
                      % Get, if existing, the distance to the closest ...
                      %firefront
                      for f = 1:length(obj.fires_history{tick})

                          fire = obj.fires_history{tick}{f};

                          f_distance = norm(sensor.location - fire.location) - fire.radius;

                          if f_distance < distance

                              distance = f_distance;
                          end

                      end

                      if sensor.alarm_status == 1 && distance <= obj.threshold
                       
                          true_positive = true_positive + 1;

                      elseif sensor.alarm_status == 1 && distance > obj.threshold

                          false_positive = false_positive + 1;
                          false_positives_history(1,tick) = false_positives_history(1,tick)+1;
                          
                          if sz ==1
                             
                              false_positives_sz_1 = false_positives_sz_1 +1; 
                              
                          else
                              
                              false_positives_sz_2 = false_positives_sz_2 +1;
                          end
                          
                      % If the sensor hasn´t detected the fire till then, its considered as too late.    
                      elseif ~sensor.alarm_status && distance <= obj.threshold

                           false_negative = false_negative + 1;

                      elseif ~sensor.alarm_status && distance > obj.threshold

                          true_negative = true_negative + 1;
                      end

                   end
               end

            end
            
            % Obtain x axis
            x = linspace(1,length(obj.sensors_history), length(obj.sensors_history));
            
            scatter(x,false_positives_history);

            system_matrix = [true_positive false_positive true_negative false_negative]; 
            
%             disp("subzones 1")
%             false_positives_sz_1
%             disp("subzones 2")
%             false_positives_sz_2     
        end
    end
end