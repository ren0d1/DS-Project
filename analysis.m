



%load respective matrices.
load('simulation-09-Jan-2021 02-22-28.mat', 'sensors_history', 'fires_history');

%fire_struct = ret_fire_data(fires_history);


%system_matrix = calc_sys_performance(fires_history, sensors_history)

%length(fire_struct);
%time_alives = zeros(1,length(fire_struct)); 

%radia = zeros(1,length(fire_struct)); 
    
%for s = 1:length(fire_struct)
   
%    time_alives(1,s) = fire_struct{s}.time_alive;
%    radia(1,s) = fire_struct{s}.radius;
%end
    
%mean(radia)

sensor_uuids = retrieve_uuids(sensors_history);



performances = retrieve_sensor_performances(sensor_uuids, sensors_history, fires_history)

function performances = retrieve_sensor_performances(sensor_uuids, sensors_history, fires_history)

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
              
              if sensor.alarm_status && distance < 10
                  
                  true_positives(1,index) =  true_positives(1,index) + 1;
                  
              elseif sensor.alarm_status && distance > 10
                  
                  false_positives(1,index) = false_positives(1,index) + 1;
              %if the sensor hasn´t detected the fire till then, its considered as too late.    
              elseif ~sensor.alarm_status && distance <= 1
                  
                   false_negatives(1,index) = false_negatives(1,index) + 1;
                   
              elseif ~sensor.alarm_status && distance > 1
                  
                  true_negatives(1,index) = true_negatives(1,index) + 1;
              end
              
               
           end
       end
    end
      
    performances = [true_positives false_positives true_negatives false_negatives];    
end




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
      



function system_matrix = calc_sys_performance(fires_history, sensors_history)

    true_positive = 0;
    false_positive = 0;
    true_negative = 0;
    false_negative = 0;
    
    %time
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
              
              if sensor.alarm_status && distance < 10
                  
                  true_positive = true_positive + 1;
                  
              elseif sensor.alarm_status && distance > 10
                  
                  false_positive = false_positive + 1;
              %if the sensor hasn´t detected the fire till then, its considered as too late.    
              elseif ~sensor.alarm_status && distance <= 1
                  
                   false_negative = false_negative + 1;
                   
              elseif ~sensor.alarm_status && distance > 1
                  
                  true_negative = true_negative + 1;
              end

           end
       end
        
    end
    
    system_matrix = [true_positive false_positive true_negative false_negative]; 
end




function fire_struct = ret_fire_data(fires_history)
        
    fire_struct = {};
    
    for t = 1:length(fires_history)
        
       %if there is a fire at time instance t, check it 
       if ~isempty(fires_history{t})
           

            for f = 1:length(fires_history{t})

                %check if already exists in list
                already_known = false;
                
                for s = 1:length(fire_struct)
                    
                    if isequal(fire_struct{s}.location, fires_history{t}{f}.location)
                        
                        %already in list
                        already_known = true;
                        
                        %update radius and time alive
                        fire_struct{s}.time_alive = fires_history{t}{f}.time_alive;
                        fire_struct{s}.radius = fires_history{t}{f}.radius;
                        
                    end
                    
                end
                
                if ~already_known
                    
                    %retrieve data and insert
                    current_fire.location = fires_history{t}{f}.location;
                
                    current_fire.time_alive = fires_history{t}{f}.time_alive;
                
                    current_fire.radius = fires_history{t}{f}.radius;                   
                    
                    fire_struct{end+1} = current_fire;
                
                end

            end 
            
       end
        
    end
  
end
