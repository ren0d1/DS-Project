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
     
        function sensor_uuids = retrieve_uuids(sensors_history)

              %retrieve all sensors

              sensor_uuids = {};

              for tick = 1:length(sensors_history)

                %retrieve amount of subzones
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
        
        function save_system_matrix(obj,system_matrix)

            name = split(obj.file_name, ".");

            name_array = ["system_matrix_", name{1}, ".txt"];
            filename = join(name_array, "");
            
            dlmwrite(filename,system_matrix)


        end 
        
        function closest_neighbors = get_closest_neighbor(obj)
            
           closest_neighbors = {};
           fire_list = {};
           
           for t = 1:length(obj.fires_history)
               
               if ~isempty(obj.fires_history{t})
                   
                    for f = 1:length(obj.fires_history{t})

                        %check if already exists in list
                        already_known = false;

                        for s = 1:length(fire_list)

                            if isequal(fire_list{s}.location, obj.fires_history{t}{f}.location)

                                %already in list
                                already_known = true;   
                                
                            end
                            
                        end
                        
                        if ~already_known
                            %insert new fire
                            cur_fire_loc = obj.fires_history{t}{f}.location;
                            cur_fire_radius = obj.fires_history{t}{f}.radius;
                            
                            cur_fire.location = cur_fire_loc;
                            fire_list{end+1} = cur_fire;
                            
                            

                            %loop over all sensors and get closest one.
                                           %
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
        
        function fire_struct = ret_fire_data(obj)

            fire_struct = {};

            for t = 1:length(obj.fires_history)

               %if there is a fire at time instance t, check it 
               if ~isempty(obj.fires_history{t})


                    for f = 1:length(obj.fires_history{t})

                        %check if already exists in list
                        already_known = false;

                        for s = 1:length(fire_struct)

                            if isequal(fire_struct{s}.location, obj.fires_history{t}{f}.location)

                                %already in list
                                already_known = true;

                                %update radius and time alive
                                fire_struct{s}.time_alive = obj.fires_history{t}{f}.time_alive;
                                fire_struct{s}.radius = obj.fires_history{t}{f}.radius;

                            end

                        end

                        if ~already_known

                            %retrieve data and insert
                            current_fire.location = obj.fires_history{t}{f}.location;

                            current_fire.time_alive = obj.fires_history{t}{f}.time_alive;

                            current_fire.radius = obj.fires_history{t}{f}.radius;                   

                            fire_struct{end+1} = current_fire;
                            
                            
                            

                        end

                    end 

               end

            end

        end 
        
        function analyse_fires(obj)
        
            fire_struct = obj.ret_fire_data();
            
            
            %get number of fires
            disp('number of fires');
            num_fires = length(fire_struct)
            
            %prepare data for plotting
            radia = zeros(1,num_fires);
            time_alives = zeros(1,num_fires);
            
            for f =1:num_fires
                radia(1,f) = fire_struct{f}.radius;
                
                time_alives(1,f) = fire_struct{f}.time_alive;
                
            end
            
            %obtain x axis
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

        
        function performances = retrieve_sensor_performances(obj,sensor_uuids, sensors_history, fires_history)

              %set up data to be returned

              true_positives = zeros(1,length(sensor_uuids));

              false_positives = zeros(1,length(sensor_uuids));

              true_negatives = zeros(1,length(sensor_uuids));

              false_negatives = zeros(1,length(sensor_uuids));

            %time
            for tick = 1:length(sensors_history)

               %retrieve amount of subzones
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
                      %get, if existing, the distance to the closest firefront
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
                      
                      %if the sensor hasn´t detected the fire till then, its considered as too late.    
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
        

           
            
        
        function system_matrix = calc_sys_performance(obj)

            true_positive = 0;
            false_positive = 0;
            true_negative = 0;
            false_negative = 0;
            
            false_positives_history = zeros(1,length(obj.sensors_history));
            false_positives_sz_1 = 0;
            
            false_positives_sz_2 = 0;
            %time
            for tick = 1:length(obj.sensors_history)

               %retrieve amount of subzones
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
                      %get, if existing, the distance to the closest firefront
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
                          
                      %if the sensor hasn´t detected the fire till then, its considered as too late.    
                      elseif ~sensor.alarm_status && distance <= obj.threshold

                           false_negative = false_negative + 1;

                      elseif ~sensor.alarm_status && distance > obj.threshold

                          true_negative = true_negative + 1;
                      end

                   end
               end

            end
            
            
            %obtain x axis
            x = linspace(1,length(obj.sensors_history), length(obj.sensors_history));
            
            scatter(x,false_positives_history);

            system_matrix = [true_positive false_positive true_negative false_negative]; 
            
%             disp("subzones 1")
%             false_positives_sz_1
%             disp("subzones 2")
%             false_positives_sz_2
%             
        end
     
        
    end
        
        
    
end