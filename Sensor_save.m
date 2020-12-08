classdef Sensor_save < handle
    
    
    properties (Access = private)
        %global time stamp to synchronize data communication
        time_stamp;
        temperature_env; %degrees
        temperature_add_fire = 0; %additional temperature due to fire;
        humidity; %is denoted as relative humidity in %
        location; %[meter, meter]
        
        %properties related to local fire detection algorithm
        %necessary amount of data to start outlier detection
        weather_data_list_length = 10;
        %determines how much the new value has to differ from the mean to
        %be considered as an outlier
        outfactor = 1;
        fire_detected_local = false;
        fire_detected_global = false;
        humidity_list = [1 2 3 4 5 6 7 10]; 
        temperature_list = [1 2 3 4 5 6 7 10];
        %list of data packages which is shared with other sensors.
        data_packages;
        %list of outlier detections
        outlier_detections;
        %list of data packages which has been received from other sensors
        received_data_packages
        %stores which time stamps have already been analyzed
        analyzed_time_instance;
    end
    
    properties (Dependent)
        measured_temperature; %degrees
        measured_humidity; %is denoted as relative humidity in %
    end
    
    methods
        function obj = Sensor(humidity, temperature, location)
            obj.humidity = humidity;
            obj.temperature_env = temperature;
            obj.location = location;
        end
        
        %sanity check relative humidity
        function set.humidity(obj, value)
            
            if(value >= 0) && (value <= 1)
               obj.humidity = value;
            else
                error('Relative humidity must be in range [0,1]')
            end
            
        end
        
        %getter method
        function location = getLocation(obj)
            location = obj.location;
        end
        
        %this function mimicks the input data which is needed at each time
        %step
        function update(obj, list_of_fires, temperature_env, humidity)
            %update temperature
            obj.temperature_env = temperature_env;
            
            obj.temperature_add_fire = 0;
            
            if ~isempty(list_of_fires)
                for f = 1 : length(list_of_fires)
                    fire = list_of_fires{f};
                    if ~isempty(fire)
                        obj.temperature_add_fire = obj.temperature_add_fire + fire.getTemperatureIncreaseAtLocation(obj.location, obj.temperature_env);
                    end
                end
            end
            
            %update humidity
            %sanity check
            
            if(humidity < 0) || (humidity > 1)
               error('Relative humidity must be in range [0,1]')
            end
              
            if obj.temperature_add_fire ~= 0
                
                %calculate saturation vapor density according to:
                %https://iridl.ldeo.columbia.edu/dochelp/QA/Basic/dewpoint.html
                E0 = 0.611 / 1000; %Pa
                x = 5423; %subsituted for (L/Rv), in Kelvin
                T0 = 273;
                T = obj.temperature_env + 273.15; %Kelvin
                Es_old = E0 * exp(x * ((1/T0) - (1/T)));
                T1= obj.temperature_env + obj.temperature_add_fire + 273.15; %Kelvin
                Es_new = E0 * exp(x * ((1/T0) - (1/T1)));
                
                obj.humidity = obj.humidity * (Es_old / Es_new);
                
                if obj.humidity < 0
                    obj.humidity =0;
                end
                
            else
                obj.humidity = humidity;
            end
            
        end
        
        %measurements for temperature and humidity are modelled accordingly
        %to the sensor at this weblink:
        %https://www.sensirion.com/en/environmental-sensors/humidity-sensors/digital-humidity-sensor-shtc3-our-new-standard-for-consumer-electronics/
         
        %models the behavior of the temperature sensor
        function measured_temperature = get.measured_temperature(obj)           
           %125 degrees is the max. temperature which can be measured by
           %the sensor
           if(obj.temperature_env > 125)
              measured_temperature = 124.6 + 0.4 * rand(); 
              
           else
               measured_temperature = (obj.temperature_env - 0.2) + 0.4 * rand();
           end
           
        end
        
        function measured_humidity = get.measured_humidity(obj)
            measured_humidity = (obj.humidity -0.02) + 0.04 * rand();
            
            if measured_humidity > 1
                measured_humidity = 1;
            elseif measured_humidity < 0
                measured_humidity = 0;
            end
        end
        
        %local fire detector algorithm
        function compute_fireprob(obj)
            %set local variables   
            %booleans as indicators to detect if there is a fire
            temp_anomaly = false;
            humidity_anomaly = false;
            obj.fire_detected_local = false;
            current_temperature = obj.temperature_env + obj.temperature_add_fire;


            if length(obj.humidity_list) >=  obj.weather_data_list_length

                %compute current mean and standard deviation for temperature and juge
                %if there is a fire or not
                current_temp_mean = mean(obj.temperature_list);
                current_temp_std = std(obj.temperature_list);

                temp_lowerbound = current_temp_mean - obj.outfactor * current_temp_std;
                temp_upperbound = current_temp_mean + obj.outfactor * current_temp_std;


                if(current_temperature > temp_upperbound) || (current_temperature < temp_lowerbound)

                    temp_anomaly = true;

                end   

                %compute current mean and standard deviation for temperature and juge
                %if there is a fire or not
                current_humidity_mean = mean(obj.humidity_list);
                current_humidity_std = std(obj.humidity_list);

                humidity_lowerbound = current_humidity_mean - obj.outfactor * current_humidity_std;
                humidity_upperbound = current_humidity_mean + obj.outfactor * current_humidity_std;

                if(obj.humidity > humidity_upperbound) || (obj.humidity < humidity_lowerbound)

                    humidity_anomaly = true;

                end  

                if humidity_anomaly && temp_anomaly

                    obj.fire_detected_local = true;

                end
                %delete element first elements of both lists
                obj.humidity_list(:,1) = [];
                obj.temperature_list(:,1) = [];
                
                %concatenate data which will be shared in data_package
                %determine relative position of the temperature/ humidity measurement to
                %the mean, expressed in standard deviation distance
                rel_pos_temp = (current_temperature - current_temp_mean) / current_temp_std;
                rel_pos_humidity = (obj.humidity - current_humidity_mean) / current_humidity_std;
                
                size = size(obj.data_packages);
                if size(1) >= obj.weather_data_list_length

                    obj.data_packages(1,:) = [];
                    obj.outlier_detections(1,:) = [];
                end 
                %store data to be able to send and judge if a fire wars
                %detected or not
                obj.data_packages = vertcat(obj.data_packages, [rel_pos_temp, rel_pos_humidity, obj.time_stamp]);
                obj.outlier_detections = vertcat(obj.outlier_detections, [obj.fire_detected_local obj.time_stamp]);
         
            end
            %update humidity list and temperature list 
            obj.humidity_list = [obj.humidity_list obj.humidity];
            obj.temperature_list = [obj.temperature_list current_temperature];
            
            
        end
        
        %fire detector with distributed data
        %retrieves the measurements from other sensors at a given time
        %stamp. 
        %logic: only performs data analysis if the local decision layer has detected a
        %fire.
        function fire_detector_distributed(obj)
           
            %sanity check: do all retrieved messages belong to one time
            %instant?
            if ~all((obj.received_data_packages(1,3)==obj.received_data_packages(:,3))) 
               
                error("not all received messages belong to the same time stamp!") 
            end
            
            obj.analyzed_time_instance = obj.received_data_packages(1,3);
            %find the respective local outlier detection variable
            row = find(obj.outlier_detections(:,2) == obj.received_data_packages(1,3));
            %if there was no outlier locally detected, there is no
            %analysis done.
            if obj.outlier_detections(row,1)
                
                humidity_trend_outlier = false;
                temp_trend_outlier = false;
                %prepare data received from other sensors for analysis
                temperature_data = obj.received_data_packages(:,1);
                humidity_data = obj.received_data_packages(:, 2);
                
                %calculate mean and standard deviation for both
                temp_mean = mean(temperature_data);
                temp_std_dev = std(temperature_data);
                humidity_mean = mean(humidity_data);
                humidity_std = std(humidity_data);
                
                %retrieve own temperature trend and humidity trend
                row = find(obj.data_packages(:,1) == obj.received_data_packages(1,3));
                
                local_temperature_trend = obj.data_packages(row, 1);
                local_humidity_trend = obj.data_packages(row, 2);
                
                temp_distance = (local_temperature_trend - temp_mean) / temp_std_dev;
                humidity_distane (local_humidity_trend - humidity_mean) / humidity_std_dev;
                
                if temp_distance > obj.outfactor
                    temp_trend_outlier = true;
                end
                
                
                if humidity_distance > obj.outfactor
                    humidity_trend_outlier = true;
                end
                
                if humidity_trend_outlier && temp_trend_outlier
                    
                    obj.fire_detected_global = true;
                end
                
                
            end     
            
        end
        
        %function which receives data & updates the list
        %only stores data with timestamps which have not been analyzed yet
        function received_data_update(obj, data_packages_ext)
            
            %delete packages not needed anymore
            x = size(obj.received_data_packages);
            for c = 1:x(1)
                
                if obj.received_packages(c,3) <= obj.analyzed_time_instance
                    obj.received_packages(c,:) = [];
                end
                    
            end 
            %only stores data if its referring to a time instance which hasn´t
            %been analyzed yet
            x = size(data_packages_ext);
            for c = 1:x(1)
                
                if data_packages_ext(c,3) > obj.analyzed_time_instance
                   obj.received_data_packages = vertcat(obj.received_data_packages, data_packages_ext(c,:));
                end
            end
            
            
           
        end
        
        %function which sends data
        function data_package = send_data_package(obj)
            
            x = size(obj.data_packages);
            data_package = obj.data_packages(x(1),:);
        end
    end
end

