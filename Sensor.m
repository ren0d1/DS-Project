classdef Sensor < handle
    %SENSOR Summary of this class goes here
    %   Detailed explanation goes here
    properties (Access = public)
        % Unique ID
        uuid;
        
        % Global time stamp to synchronize data communication
        time_stamp; % {day, hour, tick}
        location; %[x, y]
                
        real_env_temperature; %degrees
        %real_env_humidity; %is denoted as relative humidity in percentage
        
        %   PROPERTIES RELATED TO LOCAL FIRE DETECTION ALGORITHM   %     
        % Necessary amount of data to start outlier detection
        weather_data_list_length = 10;
        
        % Determines how much the new value has to differ from the mean ...
        %to be considered as an outlier.
        outfactor = 1;
        
        fire_detected_local = false;
        
        temperature_list = {};
        
        
        
        % List of sensors in range to send data to (Subscription pattern ...
        %is used to notify the sensors which are in range to receive the ...
        %bluetooth packet - makes simulation easier)
        neighborly_sensors = {};
        
        dead_sensors = {};
        
        % List of data packages which is shared with other sensors.
        data_packages = {};
        % List of outlier detections
        outlier_detections = {};
        % List of data packages which has been received from other sensors
        %received_data_packages = {};
        % List of data retrieved from received data packages ( ...
        %temp, temp_deriv, timestamp)
        received_data = {};
        % Stores which time stamps have already been analyzed
        analyzed_time_instance;
        
        
        %rules to be applied. set to true if it should be considered
        local_abs_temp = 1;
        
        local_der_temp = 1;
        
        global_abs_temp = 1;
        
        global_der_temp  = 1;
        
        %number of rules applied
        no_rules = 4;
        
        %set if AND or OR mode should be used
        
        and_mode = true;
        
        %parameters to be tuned
        %temperature that is a threshold for fire detection
        local_temp_threshold = 80; %[Celsius]
        
        local_derivative_thresh = 10;
        
        %the allowed temperature difference to neighborly sensors
        global_temp_threshold = 10;  
        
        global_derivative_thresh = 10;
         
    end
    
    properties (Dependent)
        measured_temperature; %degrees
        
        derivative_temperature;
        
    end
    
    properties (Constant)
        
        base_station = BaseStation();
        
    end
    
    methods (Static)
        function notify_base_about_fire(fire)
            
            Sensor.base_station.listen_for_alert(1, fire);
            
        end 
        
        function notify_base_about_dead_sensor(sensor_uuid)
            
            Sensor.base_station.listen_for_alert(2, sensor_uuid);
            
        end 
    end
    
    
    methods  
        
        function obj = Sensor(location, temperature)
            
            obj.location = location;
            
            obj.real_env_temperature = temperature;
           
            obj.time_stamp = [1, 1, 0];
            
            obj.temperature_list{end+1} = temperature;
            
            obj.uuid = java.util.UUID.randomUUID;
        end
        
        % Getter methods
        %shouldn`t it be: get.location(obj) 
        function location = getLocation(obj)
            location = obj.location;
        end
        
        function t_dash = get.derivative_temperature(obj)
           
            if length(obj.temperature_list) >=  obj.weather_data_list_length
               
                %compute difference of last and first element of the
                %temperature stored in the temperature list
                t_dash =  obj.temperature_list{obj.weather_data_list_length} - obj.temperature_list{1};
            
            else
                
                t_dash = -1;
            end
            
        end
        
        %shouldn`t it be: get.uuid(obj)
        function uuid = getUuid(obj)
            
           uuid = erase(string(obj.uuid), "-");
           
        end
        
        % Measurements for temperature and humidity are modelled ...
        %accordingly to the sensor at this weblink:
        % https://www.sensirion.com/en/environmental-sensors/humidity-sensors/digital-humidity-sensor-shtc3-our-new-standard-for-consumer-electronics/
         
        % Models the behavior of the temperature sensor
        function measured_temperature = get.measured_temperature(obj)           
           % 125 degrees is the max. temperature which can be measured by ...
           %the sensor.
           if(obj.real_env_temperature > 125)
              
               measured_temperature = 124.6 + 0.4 * rand(); 
              
           else
               
               measured_temperature = (obj.real_env_temperature - 0.2) + ...
                                        0.4 * rand();
           end
           
        end
         

        function update(obj, real_env_temperature, ...
                        day, hour, tick)
    
            %empty received data packages from previous iteration
            obj.received_data = {};
            
            
            %need of a function that updates all relevant datapoints
            obj.update_datastructures(real_env_temperature,day, hour, tick); 
            %need a function that computes the derivative (trend) of the
            %temperature
            %--> done; get method
            
            
            %send data packages
            obj.send_data_packages();
            
            obj.compute_fireprob();

            
%             if ~isempty(obj.received_data)
%                 
%                 
%                 if obj.time_stamp(1) ~= 1 || obj.time_stamp(2) ~= 1 || ...
%                         obj.time_stamp(3) ~= 1
%                     
%                     obj.check_dead_neighbors();
%                     
%                 end
%             end
%             
            
        end
        
        function addNeighbor(obj, sensor)
            obj.neighborly_sensors{end+1} = sensor;
        end
        
        function addNeighbors(obj, sensors)
            obj.neighborly_sensors = sensors;
        end
    end

    
  methods (Access = private)
  
        function update_datastructures(obj, real_env_temperature,day, hour, tick)
            
            %update timestamp and environment temperature of the sensor
            obj.real_env_temperature = real_env_temperature;
       
            obj.time_stamp = [day, hour, tick];
       
            if length(obj.temperature_list) >=  obj.weather_data_list_length
               
                %delete first element of the list
                obj.temperature_list = obj.temperature_list(2:end); 
            end
            
            % Update temperature list 
            obj.temperature_list{end+1} = obj.measured_temperature;
            
            %update data packages
            
            if length(obj.data_packages) >= obj.weather_data_list_length
                % Delete first element of both lists
                obj.data_packages = obj.data_packages(2:end);
                obj.outlier_detections = obj.outlier_detections(2:end);
            end
                
            data_package.temp = obj.measured_temperature;
            
            data_package.temp_deriv = obj.derivative_temperature;
            
            data_package.time_stamp = obj.time_stamp;

            obj.data_packages{end + 1} = data_package;
    
        end        
        
        
         %checked if local_abs_temp = true;
        function fire_detected = check_local_threshold(obj)

            if(obj.local_temp_threshold <= obj.measured_temperature)
                
                fire_detected = 1;
                
            else
                fire_detected = 0;
            end
        end       
        
        %checked if local_der_temp = true;
        function fire_detected = check_local_derivative(obj)
            
            fire_detected = 0;
            
            if length(obj.temperature_list) >=  obj.weather_data_list_length
               
                for i = 1:length(obj.temperature_list)
                   
                    deriv = obj.measured_temperature - obj.temperature_list{i}; 
                    
                    if deriv >= obj.local_derivative_thresh
                        
                        fire_detected = 1;
                        
                        return;
                    end
                end
            end 
        end
        
        %checked if global_abs_temp = true;
        function fire_detected = check_global_temp(obj)
            
            fire_detected = 0;
            
            temp_data = zeros(1,length(obj.received_data));
            
            for i = 1:length(obj.received_data)
               
                temp_data(i) = obj.received_data{i}.temp;
            
            end
                
                
            
            temp_mean = mean(temp_data);
            
            temp_diff = obj.measured_temperature - temp_mean;
            
            if temp_diff >= obj.global_temp_threshold
                
                fire_detected = 1;
            end
        
        end
        
        
        %checked if global_der_temp = true;
        %note: in the first x < weather_data_length time instances, this
        %function will always return false; its not computing angy
        %derivative
        
        function fire_detected = check_global_derivative(obj)
            
            fire_detected = 0;
            too_early = false;
            %temp_data = obj.received_data{1}.temperature;
            temp_data = zeros(1,length(obj.received_data));
            
            for i = 1:length(obj.received_data)
               
                temp_data(i) = obj.received_data{i}.temp_deriv;
                
                if obj.received_data{i}.temp_deriv == -1
                    
                    too_early = true;
                    
                end 
            end
                
            temp_mean = mean(temp_data);
            
            temp_diff = obj.derivative_temperature - temp_mean;
            
            if temp_diff >= obj.global_derivative_thresh && too_early ==false
                
                fire_detected = 1;
                
            end
        end
        
        
        function compute_fireprob(obj)
            
           %variables needed
           obj.fire_detected_local = false;
            counter = 0;
            
            
            if obj.local_abs_temp == 1
              
               counter = counter + obj.check_local_threshold();
               
           end
           
           if obj.local_der_temp == 1
               
               counter = counter + obj.check_local_derivative;
               
           end
           
           if obj.global_abs_temp ==1
               
              counter = counter + obj.check_global_temp();
               
           end
           
           if obj.check_global_derivative == 1
               
             counter = counter + obj.check_global_derivative();
               
           end
               
           if obj.and_mode == true
              
               if obj.no_rules == counter
                  
                   obj.fire_detected_local = true;
                   
               end
           else
               
               if counter > 0
                   
               obj.fire_detected_local = true;
               
               end
               
           end
            %outlier detection arrays + time stamp
            outlier_detection.fire_detected_local = ...
                obj.fire_detected_local;
            outlier_detection.time_stamp = obj.time_stamp;

            obj.outlier_detections{end + 1} = outlier_detection; 
        end
        
    
        function check_dead_neighbors(obj)
            % Sanity check: do all retrieved messages belong to one time
            %instant?
            for d = 1 : length(obj.received_data)
                if obj.received_data{d}.time_stamp ~= ...
                        obj.received_data{1}.time_stamp
                    
                    error("not all received messages belong to the same time stamp!")
                end
            end
            
            % Check if we have the same amount of received messages ...
            %than the amount of known neighbors. If not, then we know ...
            %we might have a dead neighbor.
            if length(obj.received_data) ~= length(obj.neighborly_sensors)
                for nbi = 1 : length(obj.neighborly_sensors)
                    known_sensor_sent_message = false;
                    
                    for rdi = 1 : length(obj.received_data)
                        if obj.neighborly_sensors{nbi}.getUuid() == ...
                                obj.received_data{rdi}.uuid
                            known_sensor_sent_message = true;
                        end
                    end
                    
                    if ~known_sensor_sent_message
                        obj.dead_sensors{end+1} = ...
                            obj.neighborly_sensors{nbi}.getUuid();
                        
                        Sensor.notify_base_about_dead_sensor(...
                            obj.neighborly_sensors{nbi}.getUuid());
                    end
                end
            end
        end
        
        function send_data_packages(obj)
            % Frame config for LE Frames
            cfgL2CAP = bleL2CAPFrameConfig('ChannelIdentifier', '0035');
            
            % Data retrieval
            data_package = obj.data_packages{end};
            
            % Prepare data to send as a payload
            hex_temp = num2hex(data_package.temp);
            hex_temp_deriv = num2hex(data_package.temp_deriv);
            
            hex_day = dec2hex(data_package.time_stamp(1));
            hex_hour = dec2hex(data_package.time_stamp(2));
            hex_minute = dec2hex(data_package.time_stamp(3));

            if mod(length(hex_temp), 2) == 1
                hex_temp = strcat('0', hex_temp);
            end

            if mod(length(hex_temp_deriv), 2) == 1
                hex_temp_deriv = strcat('0', hex_temp_deriv);
            end

            if mod(length(hex_day), 2) == 1
                hex_day = strcat('0', hex_day);
            end

            if mod(length(hex_hour), 2) == 1
                hex_hour = strcat('0', hex_hour);
            end

            if mod(length(hex_minute), 2) == 1
                hex_minute = strcat('0', hex_minute);
            end
            
            uuid_to_share = erase(string(obj.uuid), "-");

            % Concatenate the data
            complete_payload_string = strcat(hex_temp, ...
                        hex_temp_deriv, ...
                        hex_day, hex_hour, hex_minute, ...
                        uuid_to_share);
            
            % Transform into char arrays because it creates a 1x1 string ...
            %array by default which creates out of boundaries exceptions.
            complete_payload_string = char(complete_payload_string);
            
            % Create the paylaod to be sent (split the payload ...
            %string into bytes. Length should ALWAYS be even!
            payload = strings(strlength(complete_payload_string) / 2, 1);

            for byte = 1 : strlength(complete_payload_string) / 2
                payload(byte) = convertStringsToChars(strcat...
                                    (complete_payload_string(byte * 2 - 1), ...
                                    complete_payload_string(byte * 2)));
            end

            % Convert string array into char array because the BLE ...
            %library expects a nx2 char array payload
            payload = char(payload);
            
            % Generate LE Frame
            LE_frame = bleL2CAPFrame(cfgL2CAP, payload);
            
            % Collects bluetooth messages for simulation purposes, but ...
            %in reality it would be processed in parallel.
            for s = 1 : length(obj.neighborly_sensors)
                obj.neighborly_sensors{s}.receive_data_package(LE_frame);
            end
            
        end
        
        function receive_data_package(obj, LE_frame)
            % Second argument is L2CAP config
            [leFrameDecodeStatus, ~, payload] = bleL2CAPFrameDecode(LE_frame);
            
            % Checks decoding status
            if strcmp(leFrameDecodeStatus, 'Success') % Decoding is successful 
                % Prepare the data needed for data extraction from the ...
                %payload
                neighborly_sensor_information.time_stamp = [0, 0, 0];
                
                % Processes the payload from the received data ...
                %package to extract the sensor informations formatted as ...
                %(relative temperature, relative humidity, ...
                %timestamp_day, timestamp_hour, timestamp_minute)
                %and then stores them in the sensor list received_data.
                
                % Retrieve temperature
                transformed_data = join(string(...
                    payload(1 : 8, :)), '');

                neighborly_sensor_information.temp = ...
                    hex2num(transformed_data);
                
                % Retrieve temperatur change
                transformed_data = join(string(payload(...
                    9 : 16, :)), '');

                neighborly_sensor_information.temp_deriv = ...
                    hex2num(transformed_data);
                
                % Retrieve timestamp
                payload_length = length(payload(:, 1));
                
                % Minute timestamp (1 byte max)
                transformed_data = string(payload(payload_length - 16, :));
                
                neighborly_sensor_information.time_stamp(3) = ...
                    hex2dec(transformed_data);
                
                % Hour timestamp (1 byte max)
                transformed_data = string(payload(payload_length - 17, :));
                
                neighborly_sensor_information.time_stamp(2) = ...
                    hex2dec(transformed_data);
                
                % Day timestamp (1 byte max)
                transformed_data = join(string(payload(...
                    17 : payload_length - 18, :)), '');
                
                neighborly_sensor_information.time_stamp(1) = ...
                    hex2dec(transformed_data);
                
                % UUID (32 bytes)
                transformed_data = join(string(payload(payload_length - 15 : ...
                                            payload_length, :)), '');
                neighborly_sensor_information.uuid = transformed_data;
                                        
                                        
                obj.received_data{end+1} = neighborly_sensor_information;
            else
                % Notify that the decoding failed
                % Handle this case (todo)
                fprintf('L2CAP decoding status is: %s\n', leFrameDecodeStatus);
            
            end
            
          end
  end
    
end

