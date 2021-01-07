classdef Sensor < handle
    %SENSOR Summary of this class goes here
    %   Detailed explanation goes here
    properties (Access = private)
        % Unique ID
        uuid;
        
        % Global time stamp to synchronize data communication
        time_stamp; % {day, hour, minute, second}
        location; %[x, y]
                
        real_env_temperature; %degrees
        real_env_humidity; %is denoted as relative humidity in percentage
        
        %   PROPERTIES RELATED TO LOCAL FIRE DETECTION ALGORITHM   %     
        % Necessary amount of data to start outlier detection
        weather_data_list_length = 10;
        
        % Determines how much the new value has to differ from the mean ...
        %to be considered as an outlier.
        outfactor = 1;
        
        fire_detected_local = false;
        temperature_list = {};
        humidity_list = {};
        
        % Rules to be applied. set to true if it should be considered
        local_abs_temp = 1;
        
        local_der_temp = 0;
        
        global_abs_temp = 0;
        
        global_der_temp  = 0;
        
        % Number of rules applied
        no_rules = 1;
        
        % Set if AND or OR mode should be used
        and_mode = false;
        
        % PARAMETERS TO BE TUNED %
        % Temperature that is a threshold for fire detection
        % set to global max temperature according to data
        local_temp_threshold = 44; %[Celsius]
        
        %max over the year according to the formula (max_temp - min_temp) /
        %8 is 3.7. putting a margin of 50%.
        local_derivative_thresh = 5.5;
        
        % The allowed temperature difference to the mean of neighborly sensors
        % temperature. Set to 5.5 as well.
        global_temp_threshold = 5.5;  
        
        %The allowed difference between the own temp derivative and the
        %temp derivative of neighborly sensors. set to 2 (since all sensors
        %should have a very similar trend)
        global_derivative_thresh = 2; 
        % END - PARAMETERS TO BE TUNED %
        
        % List of sensors in range to send data to (Subscription pattern ...
        %is used to notify the sensors which are in range to receive the ...
        %bluetooth packet - makes simulation easier)
        neighborly_sensors;
        
        % List of data packages which is shared with other sensors.
        data_packages;
        
        % List of outlier detections
        outlier_detections;
        
        % List of data packages which has been received from other sensors
        received_data_packages;
        
        % List of data retrieved from received data packages (measured ...
        %temperature, temperature_deriv, timestamp, uuid)
        received_data;
        
        % List of sign of life received
        received_sign_of_life;
        
        % Stores which time stamps have already been analyzed
        analyzed_time_instance;
    end
    
    properties (Dependent)
        measured_temperature; %degrees
        measured_humidity; %is denoted as relative humidity in percentage
        
        derivative_temperature;
    end
    
    properties (Constant)
        base_station = BaseStation.getInstance();
        
        % This represents the time allowed before the lack of sign of ...
        %life becomes problematic. (Value needs to be at least 1 due to ...
        %limitations from the simulation sequential nature).
        max_allowed_delay = 5; %minutes
    end
    
    methods (Static)
        function notify_base_about_fire(info)
            Sensor.base_station.listen_for_alert(1, info);
        end 
        
        function notify_base_about_dead_sensor(sensor_info)
            Sensor.base_station.listen_for_alert(2, sensor_info);
        end 
    end
    
    methods
        function obj = Sensor(location, temperature, humidity)
            obj.location = location;
            obj.real_env_temperature = temperature;
            obj.real_env_humidity = humidity;
            obj.time_stamp = [1, 1, 1, 0];
            obj.uuid = java.util.UUID.randomUUID;
        end
        
        % Getter methods
        function location = getLocation(obj)
            location = obj.location;
        end
        
        function uuid = getUuid(obj)
           uuid = erase(string(obj.uuid), "-");
        end
        
        function t_dash = get.derivative_temperature(obj)
            if length(obj.temperature_list) >=  obj.weather_data_list_length
                % Compute difference of last and first element of the ...
                %temperature stored in the temperature list.
                t_dash = obj.temperature_list{obj.weather_data_list_length} ...
                            - obj.temperature_list{1};
            else
                t_dash = -1;
            end
            
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
        
        function measured_humidity = get.measured_humidity(obj)
            measured_humidity = (obj.real_env_humidity -0.02) + 0.04 * rand();
            
            if measured_humidity > 1
                measured_humidity = 1;
            elseif measured_humidity < 0
                measured_humidity = 0;
            end
        end
        
        % Sanity check relative humidity
        function set.real_env_humidity(obj, value)
            
            if(value >= 0) && (value <= 1)
               obj.real_env_humidity = value;
            else
                error('Relative humidity must be in range [0,1]')
            end
            
        end
        
        function setTimeStamp(obj, day, hour, tick)
            obj.time_stamp = [day, hour, fix(tick), round(mod(tick, 1) * 60)];
        end
        
        function update(obj, real_env_temperature, real_env_humidity, ...
                        day, hour, tick)   
            % Need of a function that updates all relevant datapoints
            obj.update_datastructures(real_env_temperature, real_env_humidity, ...
                                        day, hour, tick);
                                    
            % Need a function that computes the derivative (trend) of the
            %temperature.
            %--> done; get method
            
            obj.send_data_packages();
            obj.compute_fireprob();
        end
        
        function addNeighbor(obj, sensor)
            obj.neighborly_sensors{end+1} = sensor;
        end
        
        function receive_data_package(obj, LE_frame)
            % Second argument is L2CAP config
            [leFrameDecodeStatus, ~, payload] = bleL2CAPFrameDecode(LE_frame);
            
            % Checks decoding status
            if strcmp(leFrameDecodeStatus, 'Success') % Decoding is successful
                payload_length = length(payload(:, 1));
                
                % Check if 32 bytes, then it is only a sign of life
                if payload_length == 16
                    transformed_data = join(string(payload(1 : ...
                                                payload_length, :)), '');
                                            
                    neighborly_sensor_information.uuid = transformed_data;
                    neighborly_sensor_information.time_stamp = obj.time_stamp;
                    
                    for s = 1 : length(obj.received_sign_of_life)
                        if obj.received_sign_of_life{s}.uuid == transformed_data
                            obj.received_sign_of_life(s) = [];
                            break;
                        end
                    end
                    
                    obj.received_sign_of_life{end+1} = ...
                        neighborly_sensor_information;
                else
                    % Prepare the data needed for data extraction from the ...
                    %payload
                    neighborly_sensor_information.time_stamp = [0, 0, 0, 0];

                    % Processes the payload from the received data ...
                    %package to extract the sensor informations formatted as ...
                    %(temperature, temperature derivative, ...
                    %timestamp_day, timestamp_hour, timestamp_minute)
                    %and then stores them in the sensor list received_data.

                    % Retrieve temperature
                    transformed_data = join(string(...
                        payload(1 : 8, :)), '');

                    neighborly_sensor_information.temp = ...
                        hex2num(transformed_data);

                    % Retrieve temperature derivative
                    transformed_data = join(string(payload(...
                        9 : 16, :)), '');

                    neighborly_sensor_information.temp_deriv = ...
                        hex2num(transformed_data);

                    % Retrieve timestamp
                    % Second timestamp (1 byte max)
                    transformed_data = string(payload(payload_length - 16, :));

                    neighborly_sensor_information.time_stamp(4) = ...
                        hex2dec(transformed_data);
                    
                    % Minute timestamp (1 byte max)
                    transformed_data = string(payload(payload_length - 17, :));

                    neighborly_sensor_information.time_stamp(3) = ...
                        hex2dec(transformed_data);

                    % Hour timestamp (1 byte max)
                    transformed_data = string(payload(payload_length - 18, :));

                    neighborly_sensor_information.time_stamp(2) = ...
                        hex2dec(transformed_data);

                    % Day timestamp (1 byte max)
                    transformed_data = join(string(payload(...
                        17 : payload_length - 19, :)), '');

                    neighborly_sensor_information.time_stamp(1) = ...
                        hex2dec(transformed_data);

                    % UUID (32 bytes)
                    transformed_data = join(string(payload(payload_length - 15 : ...
                                                payload_length, :)), '');
                    neighborly_sensor_information.uuid = transformed_data;


                    obj.received_data{end+1} = neighborly_sensor_information;
                end
            else
                % Notify that the decoding failed
                % Handle this case (todo)
                fprintf('L2CAP decoding status is: %s\n', leFrameDecodeStatus);
            end
        end
        
        function send_sign_of_life(obj)
            % Frame config for LE Frames
            cfgL2CAP = bleL2CAPFrameConfig('ChannelIdentifier', '0035');
            
            % Prepare data to send as a payload
            uuid_to_share = erase(string(obj.uuid), "-");
            
            % Transform into char arrays because it creates a 1x1 string ...
            %array by default which creates out of boundaries exceptions.
            complete_payload_string = char(uuid_to_share);
            
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
                 
        function check_sign_of_life(obj)
            indexes_of_missing_sensors = {};
            
            % The delay is checked to leave some room for 'lost' ...
            %connections and network problems. We loop first over ...
            %the received sign of life because the simulation expects ...
            %at least one message to be exchanged before sensors break.
            for rsli = 1 : length(obj.received_sign_of_life)
                known_sensor_sent_message = false;
                known_sensor_index = 0;
                
                for nbi = 1 : length(obj.neighborly_sensors)
                    if obj.neighborly_sensors{nbi}.getUuid() == ...
                            obj.received_sign_of_life{rsli}.uuid
                        
                        known_sensor_index = nbi;
                        
                        if TimeHelper.findIfTimeStampsAreNotTooMuchApart(...
                            obj.time_stamp, obj.max_allowed_delay, ...
                            obj.received_sign_of_life{rsli}.time_stamp)
                        
                            known_sensor_sent_message = true;
                        end
                    end
                end
                
                if ~known_sensor_sent_message
                    notification.uuid = ...
                        obj.neighborly_sensors{known_sensor_index}.getUuid();
                    notification.location = ...
                        obj.neighborly_sensors{known_sensor_index}.getLocation();
                    
                    Sensor.notify_base_about_dead_sensor(notification);
                    
                    obj.neighborly_sensors(known_sensor_index) = [];
                    
                    indexes_of_missing_sensors{end+1} = rsli;
                end
            end
            
            for rsc = 1 : length(indexes_of_missing_sensors)
                obj.received_sign_of_life(...
                        indexes_of_missing_sensors{rsc} - (rsc - 1)) = [];
            end
        end
    end
    
    methods (Access = private)
        function update_datastructures(obj, real_env_temperature, ...
                                        real_env_humidity, day, hour, tick)
            % Update timestamp and environment temperature of the sensor
            obj.real_env_temperature = real_env_temperature;
            obj.real_env_humidity = real_env_humidity;
            obj.setTimeStamp(day, hour, tick);
            
            % Remove old (~already treated) received data
            if ~isempty(obj.received_data)
                reference_time = obj.received_data{1}.time_stamp;
                time_count = 0;
                replacement_index = 1;
                for d = 1 : length(obj.received_data)
                    if obj.received_data{d}.time_stamp ~= ...
                            reference_time

                        reference_time = obj.received_data{d}.time_stamp;

                        if time_count == 0
                           replacement_index = d; 
                        end

                        time_count = time_count + 1;
                    end
                end

                if time_count == 2
                    obj.received_data = obj.received_data(...
                                                replacement_index + 1 : end);
                end
            end
       
            if length(obj.temperature_list) >=  obj.weather_data_list_length
                % Delete first element of the list
                obj.temperature_list = obj.temperature_list(2:end);
                obj.humidity_list = obj.humidity_list(2:end); 
            end
            
            % Update temperature & humidity list 
            obj.temperature_list{end+1} = obj.measured_temperature;
            obj.humidity_list{end+1} = obj.measured_humidity;
            
            % Update data packages
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
        
        % Check if local_abs_temp = true;
        function fire_detected = check_local_threshold(obj)
            if(obj.local_temp_threshold <= obj.temperature_list{end})
                fire_detected = 1;
            else
                fire_detected = 0;
            end
        end 
        
        % Check if local_der_temp = true;
        function fire_detected = check_local_derivative(obj)
            
            fire_detected = 0;
            
            if length(obj.temperature_list) >=  obj.weather_data_list_length
                for i = 1 : length(obj.temperature_list)
                    deriv = obj.temperature_list{end} - obj.temperature_list{i}; 
                    
                    if deriv >= obj.local_derivative_thresh
                        fire_detected = 1;
                        return;
                    end
                end
            end 
        end
        
        % Check if global_abs_temp = true;
        function fire_detected = check_global_temp(obj)
            
            fire_detected = 0;
            too_early = true;
            
            temp_data = zeros(1, length(obj.received_data));
            
            for d = 1 : length(obj.received_data)
                % Sanity check: do all retrieved messages belong to the ...
                %earliest time instant?
                if obj.received_data{d}.time_stamp == ...
                        obj.received_data{1}.time_stamp
                    
                    temp_data(d) = obj.received_data{d}.temp;
                else
                    too_early = false;
                end
            end
                
            temp_mean = mean(temp_data);
            
            temp_diff = obj.measured_temperature - temp_mean;
            
            if temp_diff >= obj.global_temp_threshold && ...
                    too_early == false
                fire_detected = 1;
            end
        end
        
        % Check if global_der_temp = true;
        % Note: in the first x < weather_data_length time instances, ...
        %this function will always return false; its not computing ...
        %any derivative.
        function fire_detected = check_global_derivative(obj)
            
            fire_detected = 0;
            too_early = true;
            
            %temp_data = obj.received_data{1}.temperature;
            temp_data = zeros(1, length(obj.received_data));
            
            for d = 1 : length(obj.received_data)
                % Sanity check: do all retrieved messages belong to the ...
                %earliest time instant?
                if obj.received_data{d}.time_stamp == ...
                        obj.received_data{1}.time_stamp
                    
                    temp_data(d) = obj.received_data{d}.temp_deriv;
                else
                    too_early = false;
                end
                
                if obj.received_data{d}.temp_deriv == -1
                    too_early = true;
                end
            end
                
            temp_mean = mean(temp_data);
            
            temp_diff = obj.derivative_temperature - temp_mean;
            
            if temp_diff >= obj.global_derivative_thresh && ...
                    too_early == false
                fire_detected = 1;
            end
        end
        
        % Local fire detection algorithm
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
            
            % Outlier detection arrays + time stamp
            outlier_detection.fire_detected_local = obj.fire_detected_local;
            outlier_detection.time_stamp = obj.time_stamp;

            obj.outlier_detections{end + 1} = outlier_detection;
            
            if obj.fire_detected_local
                obj.notify_base_about_fire(obj.location); 
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
            hex_second = dec2hex(data_package.time_stamp(4));

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
            
            if mod(length(hex_second), 2) == 1
                hex_second = strcat('0', hex_second);
            end
            
            uuid_to_share = erase(string(obj.uuid), "-");

            % Concatenate the data
            complete_payload_string = strcat(hex_temp, hex_temp_deriv, ...
                        hex_day, hex_hour, hex_minute, hex_second, ...
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
    end
end

