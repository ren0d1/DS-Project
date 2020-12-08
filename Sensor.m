classdef Sensor < handle
    %SENSOR Summary of this class goes here
    %   Detailed explanation goes here
    properties (Access = private)
        % Unique ID
        uuid;
        
        % Global time stamp to synchronize data communication
        time_stamp; % {day, hour, tick}
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
        fire_detected_global = false;
        temperature_list = [1 2 3 4 5 6 7 8 9 10];
        humidity_list = [1 2 3 4 5 6 7 8 9 10]; 
        
        % List of sensors in range to send data to (Subscription pattern ...
        %is used to notify the sensors which are in range to receive the ...
        %bluetooth packet - makes simulation easier)
        neighborly_sensors;
        dead_sensors;
        
        % List of data packages which is shared with other sensors.
        data_packages;
        % List of outlier detections
        outlier_detections;
        % List of data packages which has been received from other sensors
        received_data_packages;
        % List of data retrieved from received data packages (measured ...
        %temperature, measured humidity, timestamp)
        received_data;
        % Stores which time stamps have already been analyzed
        analyzed_time_instance;
    end
    
    properties (Dependent)
        measured_temperature; %degrees
        measured_humidity; %is denoted as relative humidity in percentage
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
        function obj = Sensor(location, temperature, humidity)
            obj.location = location;
            obj.real_env_temperature = temperature;
            obj.real_env_humidity = humidity;
            obj.time_stamp = [1, 1, 0];
            obj.uuid = java.util.UUID.randomUUID;
        end
        
        % Getter methods
        function location = getLocation(obj)
            location = obj.location;
        end
        
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
        
        function update(obj, real_env_temperature, real_env_humidity, ...
                        day, hour, tick)
            % Update temperature and humidity
            obj.real_env_temperature = real_env_temperature;
            obj.real_env_humidity = real_env_humidity;
            obj.time_stamp = [day, hour, tick];
            
            obj.compute_fireprob();
            obj.send_data_packages();
            
            if ~isempty(obj.received_data)
                obj.compute_fireprob_distributed();
                
                if obj.time_stamp(1) ~= 1 || obj.time_stamp(2) ~= 1 || ...
                        obj.time_stamp(3) ~= 1
                    obj.check_dead_neighbors();
                end
            end
        end
        
        function addNeighbor(obj, sensor)
            obj.neighborly_sensors{end+1} = sensor;
        end
        
        function addNeighbors(obj, sensors)
            obj.neighborly_sensors = sensors;
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

                neighborly_sensor_information.temperature = ...
                    hex2num(transformed_data);
                
                % Retrieve humidity
                transformed_data = join(string(payload(...
                    9 : 16, :)), '');

                neighborly_sensor_information.humidity = ...
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
    
    methods (Access = private)
        % Local fire detection algorithm
        function compute_fireprob(obj)
            % Set local variables   
            % Booleans as indicators to detect if there is a fire
            temp_anomaly = false;
            humidity_anomaly = false;
            obj.fire_detected_local = false;

            if length(obj.temperature_list) >=  obj.weather_data_list_length
                % Fix temperature and humidity measurements for processing.
                current_temperature = obj.measured_temperature;
                current_humidity = obj.measured_humidity;
                
                % Compute current mean and standard deviation for ... 
                %temperature and judge if there is an anomaly or not.
                current_temp_mean = mean(obj.temperature_list);
                current_temp_std = std(obj.temperature_list);

                temp_lowerbound = current_temp_mean - obj.outfactor * ...
                                                        current_temp_std;
                temp_upperbound = current_temp_mean + obj.outfactor * ...
                                                        current_temp_std;

                % Check if the measured temperature is outside expected ...
                %boundaries.
                if(current_temperature > temp_upperbound) || ...
                        (current_temperature < temp_lowerbound)
                    temp_anomaly = true;
                end   

                % Compute current mean and standard deviation for ...
                %humidity and judge if there is an anomaly or not.
                current_humidity_mean = mean(obj.humidity_list);
                current_humidity_std = std(obj.humidity_list);

                humidity_lowerbound = current_humidity_mean - ...
                                        obj.outfactor * current_humidity_std;
                humidity_upperbound = current_humidity_mean + ...
                                        obj.outfactor * current_humidity_std;

                % Check if the measured humidity is outside expected ...
                %boundaries.
                if(current_humidity > humidity_upperbound) || ...
                        (current_humidity < humidity_lowerbound)
                    humidity_anomaly = true;
                end  

                if humidity_anomaly && temp_anomaly
                    obj.fire_detected_local = true;
                end
                
                % Determine relative position of the temperature/ humidity ...
                %measurement to the mean, expressed in standard deviation ...
                %distance.
                rel_pos_temp = (current_temperature - ...
                                    current_temp_mean) / current_temp_std;
                rel_pos_humidity = (current_humidity - ...
                                        current_humidity_mean) / ...
                                            current_humidity_std;

                % Check if we are keeping a list of data_packages ...
                %matching size requirements.
                if length(obj.data_packages) >= obj.weather_data_list_length
                    % Delete first element of both lists
                    obj.data_packages(1) = [];
                    obj.outlier_detections(1) = [];
                end
                
                data_package.rel_pos_temp = rel_pos_temp;
                data_package.rel_pos_humidity = rel_pos_humidity;
                data_package.time_stamp = obj.time_stamp;
                
                obj.data_packages{end + 1} = data_package;
                                        
                outlier_detection.fire_detected_local = ...
                    obj.fire_detected_local;
                outlier_detection.time_stamp = obj.time_stamp;
                                            
                obj.outlier_detections{end + 1} = outlier_detection;
         
                % Delete first element of both lists
                obj.humidity_list(:,1) = [];
                obj.temperature_list(:,1) = [];
                
                % Update humidity list and temperature list 
                obj.temperature_list = [obj.temperature_list current_temperature];
                obj.humidity_list = [obj.humidity_list current_humidity];
            end
        end
        
        % Distributed fire detection algorithm
        % Logic: only performs data analysis if the local decision layer ...
        %has detected a fire.
        function compute_fireprob_distributed(obj)
            % Sanity check: do all retrieved messages belong to one time
            %instant?
            for d = 1 : length(obj.received_data)
                if obj.received_data{d}.time_stamp ~= ...
                        obj.received_data{1}.time_stamp
                    
                    error("not all received messages belong to the same time stamp!")
                end
            end
            
            obj.analyzed_time_instance = obj.received_data{1}.time_stamp;
            
            % Find the respective local outlier detection variable
            row = -1;
            for o = 1 : length(obj.outlier_detections)
                if obj.outlier_detections{o}.time_stamp == ...
                        obj.analyzed_time_instance
                    
                    row = o;
                    break;
                end
            end
            
            % If there was no local temperature AND humidity outliers ...
            %(fire detected), there is no analysis done.
            if row ~= -1 && obj.outlier_detections{row}.fire_detected_local
                
                humidity_trend_outlier = false;
                temp_trend_outlier = false;
                
                % Prepare data received from other sensors for analysis
                temperature_data = obj.received_data{1}.humidity;
                humidity_data = obj.received_data{1}.temperature;
                
                % Calculate mean and standard deviation for both
                temp_mean = mean(temperature_data);
                temp_std_dev = std(temperature_data);
                humidity_mean = mean(humidity_data);
                humidity_std_dev = std(humidity_data);
                
                % Retrieve own temperature trend and humidity trend
                for o = length(obj.data_packages)
                    if obj.data_packages{o}.time_stamp == ...
                            obj.analyzed_time_instance

                        row = o;
                        break;
                    end
                end
                
                local_temperature_trend = obj.data_packages{row}.rel_pos_temp;
                local_humidity_trend = obj.data_packages{row}.rel_pos_humidity;
                
                temp_distance = (local_temperature_trend - temp_mean) / ...
                                    temp_std_dev;
                humidity_distance = (local_humidity_trend - humidity_mean) / ...
                                        humidity_std_dev;
                
                if temp_distance > obj.outfactor
                    temp_trend_outlier = true;
                end
                
                
                if humidity_distance > obj.outfactor
                    humidity_trend_outlier = true;
                end
                
                if temp_trend_outlier && humidity_trend_outlier
                    obj.fire_detected_global = true;
                end
            end 
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
            hex_rel_pos_temp = num2hex(data_package.rel_pos_temp);
            hex_rel_pos_humidity = num2hex(data_package.rel_pos_humidity);
            
            hex_day = dec2hex(data_package.time_stamp(1));
            hex_hour = dec2hex(data_package.time_stamp(2));
            hex_minute = dec2hex(data_package.time_stamp(3));

            if mod(length(hex_rel_pos_temp), 2) == 1
                hex_rel_pos_temp = strcat('0', hex_rel_pos_temp);
            end

            if mod(length(hex_rel_pos_humidity), 2) == 1
                hex_rel_pos_humidity = strcat('0', hex_rel_pos_humidity);
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
            complete_payload_string = strcat(hex_rel_pos_temp, ...
                        hex_rel_pos_humidity, ...
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
    end
end

