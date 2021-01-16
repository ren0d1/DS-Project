classdef Simulator <  handle
    %SIMULATOR Summary of this class goes here
    %   Detailed explanation goes here
    properties (Constant)
        % Enable visualization. Mandatory for plane mode to work.
        visualizer_state = true;
        
        % Variables for plane
        discretization_size = 25; % in [m]
        variance = 10; % in [m] in each direction ...
                       %(-> total_variance_per_axis = variance * 2) | ...
                       %due to plane speed and fall.
        
        % Variables for random scatter
        amount_of_sensors_per_100_square_meters = 2;
        
        % Expected maximum length for a properly working bluetooth ...
        %transmission in meters.
        maximum_bluetooth_range = 20;
        
        % Rate at which the sensors sign of life is sent
        sign_of_life_rate = 1; % in minutes
    end
    
    properties (Access = private)
        % Config parameters
        zone_width;
        zone_height;
        years;
        
        % humidity_variance, temperature_variance
        subzones_variances;
        amount_of_subzones;
        subzones_min_and_max_coordinates;
        
        simulation_time;
        sensing_rate;
        starting_day;
        
        % General simulation properties (at init)
        weather_generator;
        fire_generator;
        visualizer;
        
        % zone_id, weather_data
        subzones_weather_data;
        subzones_discretized_weather_data;
        
        % Simulation time properties
        fires = [];
        sensors_per_subzone = {};
        
        % Simulation states
        sensors_data_per_subzone_at_tick_t = {};
        fires_data_at_tick_t = {};
    end
    
    methods
        function obj = Simulator(zones_weather_file, zone_image, ...
                                    zone_width, zone_height, years, ...
                                    subzones_variances, simulation_time, ...
                                    sensing_rate, starting_day, plane_mode)
            %SIMULATOR Construct an instance of this class
            %   Detailed explanation goes here
            if isstring(zones_weather_file) && ...
                    contains(zones_weather_file, ".dat")
                
                obj.weather_generator = WeatherGenerator(zones_weather_file);
                
                if isstring(zone_image) && ...
                        contains(zone_image + '.png', ".png")
                    
                    obj.zone_width = zone_width;
                    obj.zone_height = zone_height;
                    obj.years = years;
                    obj.subzones_variances = subzones_variances;
                    obj.amount_of_subzones = size(obj.subzones_variances, 1);
                    obj.simulation_time = simulation_time;
                    obj.sensing_rate = sensing_rate;
                    obj.starting_day = starting_day;
                    
                    if obj.visualizer_state
                        obj.visualizer = Visualizer(zone_image, ...
                                                obj.zone_width, ...
                                                obj.zone_height, ...
                                                obj.amount_of_subzones);
                    end
                                            
                    [starting_subzones_temperature, ...
                     starting_subzones_humidity, ...
                     starting_subzones_wind] = obj.initSubzonesData();
                 
                    if obj.visualizer_state
                        roi = obj.visualizer.initializeGUI(plane_mode, ...
                                    obj.subzones_min_and_max_coordinates);
                    end
                                    
                    if plane_mode
                        obj.generateSensorsBasedOnPlanePath(roi, ...
                                starting_subzones_temperature, ...
                                starting_subzones_humidity);
                        
                        delete(roi);
                    else
                        obj.generateSensorsRandomly(...
                                starting_subzones_temperature, ...
                                starting_subzones_humidity);
                    end
                    
                    % Assign neighbors to each sensor to simulate the ...
                    %Bluetooth communication through a subscription ...
                    %pattern.
                    obj.assignNeighborsForAllSensors();
                else
                    error('Provided zone image does not exist in current folder')
                end
            else
                error('File including weather data does not exist in current folder')
            end
        end
        
        function [s, f] = simulation(obj)
            obj.fire_generator = FireGenerator();
            
            % Create lists used for hourly weather simulation.
            hourly_temperature = zeros(1, obj.amount_of_subzones);
            hourly_humidity = zeros(1, obj.amount_of_subzones);
            hourly_wind = zeros(1, obj.amount_of_subzones);
            
            for day = 1 : obj.simulation_time
                for hour = 1 : 24
                    for sz = 1 : size(obj.subzones_variances, 1)
                        % Get hourly subzone environmental data
                        hourly_temperature(sz) = ...
                            obj.subzones_discretized_weather_data{sz}{1}(...
                                obj.starting_day + day, hour);

                        hourly_humidity(sz) = ...
                            obj.subzones_discretized_weather_data{sz}{2}(...
                                obj.starting_day + day, hour) ...
                            / 100; % Normalized to percentage
                        
                        hourly_wind(sz) = obj.subzones_discretized_weather_data{sz}{3}(...
                                obj.starting_day + day, hour);
                    end
                    
                    % Update simulation respectively to sensing rate
                    for tick = 1 : obj.sensing_rate : 60
                        % Update fires
                        obj.updateFires(hourly_wind, hourly_humidity, hourly_temperature);
                        
                        % Add slight changes for environmental data ...
                        %throughout the sensing part (todo)
                        for sz = 1 : obj.amount_of_subzones
                            % Generate new fires
                            obj.generateFires(sz, hourly_temperature(sz), ...
                                              hourly_humidity(sz), ...
                                              hourly_wind(sz));

                            % Simulate sensor action (aka update)
                            obj.updateSensors(sz, hourly_temperature(sz), ...
                                              hourly_humidity(sz), day, hour, ...
                                              tick);
                                          
                            obj.detectFires(sz);

                            % Simulate random technical problem preventing ...
                            %sensor from working any longer. (TODO)
                            if rand() <= 0.0005
                                obj.sensorDefect(sz);
                            end
                            
                            % Check if sensors are destroyed due to fires
                            obj.checkSensorsBrokenByFire(sz);

                            % Updates GUI
                            if obj.visualizer_state
                                obj.visualizer.updateGUI(obj.fires, ...
                                                     {day, hour, ...
                                                      fix(tick), ...
                                                      mod(tick, 1) * 60});
                            end
                        end
                        
                        sensors_per_subzone_data = cell(...
                            obj.amount_of_subzones, ...
                            size(obj.sensors_per_subzone, 2));
                        
                        for sz = 1 : obj.amount_of_subzones
                            % Find which active sensors are in the subzone
                            subzone_sensors = obj.sensors_per_subzone(sz, :);

                            if ~isempty(find(cellfun('isempty', ...
                                                     subzone_sensors), 1))

                                empty_cell_index = find(cellfun(...
                                                            'isempty', subzone_sensors), ...
                                                        1);

                                amount_of_active_sensors_in_subzone = ...
                                    empty_cell_index - 1;
                            else
                                amount_of_active_sensors_in_subzone = ...
                                    length(subzone_sensors);
                            end

                            for s = 1 : amount_of_active_sensors_in_subzone
                                sensor_data.uuid = ...
                                    obj.sensors_per_subzone{sz, ...
                                            s}.getUuid();
                                
                                sensor_data.alarm_status = ...
                                    obj.sensors_per_subzone{sz, ...
                                            s}.getFireDetectionState();
                                
                                sensor_data.location = ...
                                    obj.sensors_per_subzone{sz, ...
                                            s}.getLocation();
                                        
                                sensors_per_subzone_data{sz, s} = ...
                                    sensor_data;        
                            end
                        end
                        
                        obj.sensors_data_per_subzone_at_tick_t{end + 1} = ...
                            sensors_per_subzone_data;
                        
                        fires_data = {};
                        
                        for f = 1 : length(obj.fires)
                            fire.location = obj.fires{f}.getLocation();
                            fire.radius = obj.fires{f}.getRadius();
                            fire.time_alive = obj.fires{f}.getTimeAlive();
                            
                            fires_data{end + 1} = fire;
                        end

                        obj.fires_data_at_tick_t{end + 1} = ...
                            fires_data;
                        
                        % Extinguish detected fires
                        bs = BaseStation.getInstance();
                        
                        location_of_sensors_which_detected_fire = ...
                            bs.get_location_of_sensors_which_detected_fire();
                        obj.findAndExtinguishFires(...
                                location_of_sensors_which_detected_fire);
                        
                        % Replace dead sensors which got notified ...
                        %to the main base (cannot be slower/faster ...
                        %than sign of life rate).
                        if mod(tick, obj.sign_of_life_rate) == 0
                            sensors_info = bs.get_sensors_to_replace();
                            obj.findAndReplaceSensors(sensors_info, ...
                                                        day, hour, tick);
                        end
                    end    
                end
            end
            
            s = obj.sensors_data_per_subzone_at_tick_t;
            f = obj.fires_data_at_tick_t;
        end
    end
    
    methods (Access = private)
        function [starting_subzones_temperature, ...
                  starting_subzones_humidity, ...
                  starting_subzones_wind] = initSubzonesData(obj)
                
            starting_subzones_temperature = zeros(size(obj.subzones_variances, 1), 1);
            starting_subzones_humidity = zeros(size(obj.subzones_variances, 1), 1);
            starting_subzones_wind = zeros(size(obj.subzones_variances, 1), 1);
            
            amount_of_vertical_splits = ceil(sqrt(size(obj.subzones_variances, 1)));
            amount_of_horizontal_splits = ceil(...
                                            size(obj.subzones_variances, 1) ...
                                            / amount_of_vertical_splits);
            times_reached_max_x = -1;
            
            for sz = 1 : size(obj.subzones_variances, 1)
                % Generate slightly different weather data for the subzone ...
                %using the provided subzone variance in temperature and ...
                %humidity.
                temperature_variance = obj.subzones_variances(sz, 1);
                humidity_variance = obj.subzones_variances(sz, 2);
                wind_variance = obj.subzones_variances(sz, 3);
                
                [regional_temperatures_min_matrix, ...
                    regional_temperatures_max_matrix, ...
                    regional_humidity_min_matrix, ...
                    regional_humidity_max_matrix, ...
                    regional_wind_min_matrix, ...
                    regional_wind_max_matrix] = ...
                    obj.weather_generator.regionalAlteration(...
                                            temperature_variance, ...
                                            humidity_variance, ...
                                            wind_variance);
                                        
                obj.subzones_weather_data{sz} = ...
                    {regional_temperatures_min_matrix; ...
                    regional_temperatures_max_matrix; ...
                    regional_humidity_min_matrix; ...
                    regional_humidity_max_matrix; ...
                    regional_wind_min_matrix; ...
                    regional_wind_max_matrix};
                
                % Discretize subzone weather data into hourly subzone ...
                % temperature and humidity.
                [hourly_temperatures_matrix, hourly_humidity_matrix, hourly_wind_matrix] = ...
                    obj.weather_generator.discretizeHourlyWeatherData(...
                        regional_temperatures_min_matrix, ...
                        regional_temperatures_max_matrix, ...
                        regional_humidity_min_matrix, ...
                        regional_humidity_max_matrix, ...
                        regional_wind_min_matrix, ...
                        regional_wind_max_matrix);
                
                obj.subzones_discretized_weather_data{sz} = ...
                    {hourly_temperatures_matrix; hourly_humidity_matrix; hourly_wind_matrix};
               
                % Retrieves and store the starting temperature and ...
                %humidity of the subzone.
                starting_subzone_temperature = ...
                    obj.subzones_discretized_weather_data{sz}{1}(...
                        obj.starting_day, 1);
                starting_subzone_humidity = ...
                    obj.subzones_discretized_weather_data{sz}{2}(...
                        obj.starting_day, 1);
                starting_subzone_wind = ...
                    obj.subzones_discretized_weather_data{sz}{3}(...
                        obj.starting_day, 1);
                    
                starting_subzones_temperature(sz) = ...
                    starting_subzone_temperature;
                starting_subzones_humidity(sz) = ...
                    starting_subzone_humidity;
                starting_subzones_wind(sz) = ...
                    starting_subzone_wind;
                
                % Calculate the two points coordinates representing the ...
                %subzone area.
                
                if mod(sz - 1, amount_of_vertical_splits) == 0
                    times_reached_max_x = times_reached_max_x + 1;
                end
                
                start_x = obj.zone_width * ...
                            mod(sz - 1, amount_of_vertical_splits) / ...
                            amount_of_vertical_splits;
                finish_x = start_x + obj.zone_width / ...
                                        amount_of_vertical_splits;
                start_y = obj.zone_height * times_reached_max_x / ...
                            amount_of_horizontal_splits;
                finish_y = obj.zone_height * (times_reached_max_x + 1) / ...
                            amount_of_horizontal_splits;

                obj.subzones_min_and_max_coordinates{sz} = ...
                                                    {{start_x, start_y}, ...
                                                    {finish_x, finish_y}};
            end
            
            weather_file_name = strcat('weather-', strrep(datestr(datetime('now')), ':', '-'), '.mat');
            weather_data = obj.subzones_discretized_weather_data;
            save(weather_file_name, 'weather_data');
        end
        
        function generateSensorsBasedOnPlanePath(...
                                        obj, roi, ...
                                        starting_subzones_temperature, ...
                                        starting_subzones_humidity)        
                                    
            amount_of_points = length(roi.Position);
            
            for i = 1 : amount_of_points - 1
                [m, b] = GeometryHelper.findLineSlopeAndIntersect(...
                            roi.Position(i), ...
                            roi.Position(amount_of_points + i), ...
                            roi.Position(i+1), ...
                            roi.Position(amount_of_points + i + 1));

                if abs(roi.Position(i) - roi.Position(i+1)) > ...
                   abs(roi.Position(amount_of_points + i) - ...
                       roi.Position(amount_of_points + i + 1))
                   
                    distance = abs(roi.Position(i) - roi.Position(i+1));
                    
                    steps = floor(distance / obj.discretization_size);
                    
                    for s = 1 : steps
                        % Generate sensor along line segment
                        if roi.Position(i) > roi.Position(i + 1)
                            new_x = roi.Position(i) - s * obj.discretization_size;
                        else
                            new_x = roi.Position(i) + s * obj.discretization_size;
                        end
                        % [x, y] = GeometryHelper.findInterpolatedValue(m, b, new_x);

                        start_x = new_x - obj.variance;
                        if start_x < 0
                            start_x = 0;
                        end
                        
                        end_x = new_x + obj.variance;
                        if end_x > obj.zone_width
                            end_x = obj.zone_width;
                        end
                        
                        start_y = y - obj.variance;
                        if start_y < 0
                            start_y = 0;
                        end
                        
                        end_y = y + obj.variance;
                        if end_y > obj.zone_height
                            end_y = obj.zone_height;
                        end
                        
                        rdm_location = [randi([round(start_x), ...
                                        round(end_x)],1), ...
                                        randi([round(start_y), ...
                                        round(end_y)],1)];
                    
                        for sz = 1 : obj.amount_of_subzones
                            start_x = ...
                              obj.subzones_min_and_max_coordinates{sz}{1}{1};
                            finish_x = ...
                              obj.subzones_min_and_max_coordinates{sz}{2}{1};
                            start_y = ...
                              obj.subzones_min_and_max_coordinates{sz}{1}{2};
                            finish_y = ...
                              obj.subzones_min_and_max_coordinates{sz}{2}{2};

                            if rdm_location(1) >= start_x && ...
                               rdm_location(1) <= finish_x && ...
                               rdm_location(2) >= start_y && ...
                               rdm_location(2) <= finish_y
                           
                                generated_sensor = Sensor(rdm_location, ...
                                    starting_subzones_temperature(sz), ...
                                    starting_subzones_humidity(sz) / 100);

                                if size(obj.sensors_per_subzone, 1) >= sz
                                    if ~isempty(find(...
                                                  cellfun('isempty', ...
                                                    obj.sensors_per_subzone(sz, :)), ...
                                                  1))
                                              
                                        empty_cell_index = find(...
                                            cellfun('isempty', ...
                                                obj.sensors_per_subzone(sz, :)), ...
                                            1);
                                        
                                        obj.sensors_per_subzone{sz, ...
                                                    empty_cell_index} = ...
                                            generated_sensor;
                                    else
                                        obj.sensors_per_subzone{sz, end + 1} = ...
                                            generated_sensor;
                                    end
                                else
                                    obj.sensors_per_subzone{sz, 1} = ...
                                        generated_sensor;
                                end
                                
                                if obj.visualizer_state
                                    obj.visualizer.spawnSensor(generated_sensor);
                                end
                            end
                        end
                    end
                else
                    distance = abs(roi.Position(amount_of_points + i) - ...
                                   roi.Position(amount_of_points + i + 1));
                    
                    steps = floor(distance / obj.discretization_size);
                    
                    for s = 1 : steps
                        % Generate sensor along line segment
                        if roi.Position(amount_of_points + i) > ...
                                roi.Position(amount_of_points + i + 1)
                            
                            new_y = roi.Position(amount_of_points + i) - ...
                                        s * obj.discretization_size;
                        else
                            new_y = roi.Position(amount_of_points + i) + ...
                                        s * obj.discretization_size;
                        end
                        [x, y] = GeometryHelper.findInterpolatedValue(m, b, new_y);
                        
                        start_x = x - obj.variance;
                        if start_x < 0
                            start_x = 0;
                        end
                        
                        end_x = x + obj.variance;
                        if end_x > obj.zone_width
                            end_x = obj.zone_width;
                        end
                        
                        start_y = new_y - obj.variance;
                        if start_y < 0
                            start_y = 0;
                        end
                        
                        end_y = new_y + obj.variance;
                        if end_y > obj.zone_height
                            end_y = obj.zone_height;
                        end
                        
                        rdm_location = [randi([round(start_x), ...
                                        round(end_x)],1), ...
                                        randi([round(start_y), ...
                                        round(end_y)],1)];
                    
                        for sz = 1 : obj.amount_of_subzones
                            start_x = ...
                              obj.subzones_min_and_max_coordinates{sz}{1}{1};
                            finish_x = ...
                              obj.subzones_min_and_max_coordinates{sz}{2}{1};
                            start_y = ...
                              obj.subzones_min_and_max_coordinates{sz}{1}{2};
                            finish_y = ...
                              obj.subzones_min_and_max_coordinates{sz}{2}{2};

                            if rdm_location(1) >= start_x && ...
                               rdm_location(1) <= finish_x && ...
                               rdm_location(2) >= start_y && ...
                               rdm_location(2) <= finish_y
                           
                                generated_sensor = Sensor(rdm_location, ...
                                    starting_subzones_temperature(sz), ...
                                    starting_subzones_humidity(sz) / 100);
                                
                                if size(obj.sensors_per_subzone, 1) >= sz
                                    if ~isempty(find(...
                                                  cellfun('isempty', ...
                                                    obj.sensors_per_subzone(sz, :)), ...
                                                  1))
                                              
                                        empty_cell_index = find(...
                                            cellfun('isempty', ...
                                                obj.sensors_per_subzone(sz, :)),...
                                            1);
                                        
                                        obj.sensors_per_subzone{sz, ...
                                                    empty_cell_index} = ...
                                            generated_sensor;
                                    else
                                        obj.sensors_per_subzone{sz, ...
                                                end + 1} = generated_sensor;
                                    end
                                else
                                    obj.sensors_per_subzone{sz, 1} = ...
                                        generated_sensor;
                                end
                                
                                if obj.visualizer_state
                                    obj.visualizer.spawnSensor(generated_sensor);
                                end
                            end
                        end
                    end
                end
            end
        end
        
        function generateSensorsRandomly(obj, ...
                                        starting_subzones_temperature, ...
                                        starting_subzones_humidity)
            subzones_size_in_square_meters = ...
                (obj.subzones_min_and_max_coordinates{1}{2}{1} - ...
                obj.subzones_min_and_max_coordinates{1}{1}{1}) * ...
                (obj.subzones_min_and_max_coordinates{1}{2}{2} - ...
                obj.subzones_min_and_max_coordinates{1}{1}{2});
            
            amount_of_sensors_per_subzones = ...
                ceil(subzones_size_in_square_meters / 100) * ...
                obj.amount_of_sensors_per_100_square_meters;
            
            obj.sensors_per_subzone = cell(obj.amount_of_subzones, ...
                amount_of_sensors_per_subzones);
            
            for sz = 1 : obj.amount_of_subzones
                obj.generateSensorsRandomlyInSubzone(sz, ...
                            starting_subzones_temperature, ...
                            starting_subzones_humidity);
            end
        end
        
        function generateSensorsRandomlyInSubzone(obj, sz_num, ...
                                        starting_subzones_temperature, ...
                                        starting_subzones_humidity)
            start_x = ...
              obj.subzones_min_and_max_coordinates{sz_num}{1}{1};
            finish_x = ...
              obj.subzones_min_and_max_coordinates{sz_num}{2}{1};
            start_y = ...
              obj.subzones_min_and_max_coordinates{sz_num}{1}{2};
            finish_y = ...
              obj.subzones_min_and_max_coordinates{sz_num}{2}{2};

            count = 1;
            
            % Change random scattering to match sensors_per_100_square_m (todo)
            for ten_meters_upward = 1 : ceil((finish_y - start_y) / 10)
                if start_y + ten_meters_upward * 10 < finish_y + 10
                    for ten_meters_sideways = 1 : ...
                            ceil((finish_x - start_x) / 10)
                        
                        if start_x + ten_meters_sideways * 10 < finish_x + 10
                          for s = 1 : ...
                              obj.amount_of_sensors_per_100_square_meters
                            
                            if start_y + ten_meters_upward * 10 < finish_y
                                if start_x + ten_meters_sideways * 10 < ...
                                        finish_x
                                    
                                    rdm_location = [randi([round(start_x + ...
                                        (ten_meters_sideways - 1) * 10), ...
                                        round(start_x + ...
                                            ten_meters_sideways * 10)],1), ...
                                        randi([round(start_y + ...
                                        (ten_meters_upward - 1) * 10), ...
                                        round(start_y + ...
                                            ten_meters_upward * 10)],1)];
                                else
                                    rdm_location = [randi([round(start_x + ...
                                        (ten_meters_sideways - 1) * 10), ...
                                        round(finish_x)],1), ...
                                        randi([round(start_y + ...
                                        (ten_meters_upward - 1) * 10), ...
                                        round(start_y + ...
                                            ten_meters_upward * 10)],1)];
                                end
                            else
                                if start_x + ten_meters_sideways * 10 < ...
                                        finish_x
                                    
                                    rdm_location = [randi([round(start_x + ...
                                        (ten_meters_sideways - 1) * 10), ...
                                        round(start_x + ...
                                            ten_meters_sideways * 10)],1), ...
                                        randi([round(start_y + ...
                                        (ten_meters_upward - 1) * 10), ...
                                        round(finish_y)],1)];
                                else
                                    rdm_location = [randi([round(start_x + ...
                                        (ten_meters_sideways - 1) * 10), ...
                                        round(finish_x)],1), ...
                                        randi([round(start_y + ...
                                        (ten_meters_upward - 1) * 10), ...
                                        round(finish_y)],1)];
                                end
                            end

                            generated_sensor = Sensor(rdm_location, ...
                                starting_subzones_temperature(sz_num), ...
                                starting_subzones_humidity(sz_num) / 100);

                            obj.sensors_per_subzone{sz_num, count} = ...
                                    generated_sensor;

                            count = count + 1;
                            
                            if obj.visualizer_state
                                obj.visualizer.spawnSensor(generated_sensor);
                            end
                          end                
                        end
                    end
                end
            end
        end 
        
        function assignNeighborsForAllSensors(obj)
            subzone_sensors = {};
            amount_of_active_sensors_in_subzone = {};
            
            for sz = 1 : size(obj.subzones_variances, 1)
                subzone_sensors{end + 1} = obj.sensors_per_subzone(sz, :);
                
                 if ~isempty(find(cellfun('isempty', ...
                                         subzone_sensors{sz}), 1))
                                     
                    empty_cell_index = find(cellfun(...
                                                'isempty', subzone_sensors{sz}), ...
                                            1);
                                        
                    amount_of_active_sensors_in_subzone{end + 1} = ...
                        empty_cell_index - 1;
                 else
                    amount_of_active_sensors_in_subzone{end + 1} = ...
                        length(subzone_sensors{sz});
                 end
            end
            
            for sz = 1 : size(obj.subzones_variances, 1)
               for s = 1 : amount_of_active_sensors_in_subzone{sz}
                    sensor = subzone_sensors{sz}{s};
                    
                    for nsz = 1 : size(obj.subzones_variances, 1)
                        for ns = 1 : amount_of_active_sensors_in_subzone{nsz}
                            potential_neighbor_sensor = subzone_sensors{nsz}{ns};
                            
                            if sensor.getUuid() ~= ...
                                    potential_neighbor_sensor.getUuid()
                                
                                % Check if the potential neighbor is in ...
                                %communication range.
                                if GeometryHelper.isPointInsideCircle(...
                                        sensor.getLocation(), ...
                                        obj.maximum_bluetooth_range, ...
                                        potential_neighbor_sensor.getLocation())

                                    % Since in theory it is in range, we ...
                                    %consider it as a neighbor to simulate ...
                                    %the bluetooth communication.
                                    sensor.addNeighbor(potential_neighbor_sensor);
                                end
                            end
                        end
                    end
                    
                    sensor.howManyNeighbors()
                end 
            end
        end
        
        function assignNeighborsForGivenSensor(obj, sensor)
            subzone_sensors = {};
            amount_of_active_sensors_in_subzone = {};
            
            for sz = 1 : size(obj.subzones_variances, 1)
                subzone_sensors{end + 1} = obj.sensors_per_subzone(sz, :);
                
                 if ~isempty(find(cellfun('isempty', ...
                                         subzone_sensors{sz}), 1))
                                     
                    empty_cell_index = find(cellfun(...
                                                'isempty', subzone_sensors{sz}), ...
                                            1);
                                        
                    amount_of_active_sensors_in_subzone{end + 1} = ...
                        empty_cell_index - 1;
                 else
                    amount_of_active_sensors_in_subzone{end + 1} = ...
                        length(subzone_sensors{sz});
                 end
            end
            
            for sz = 1 : size(obj.subzones_variances, 1)
                for s = 1 : amount_of_active_sensors_in_subzone{sz}
                    potential_neighbor_sensor = subzone_sensors{sz}{s};

                    if sensor.getUuid() ~= ...
                            potential_neighbor_sensor.getUuid()

                        % Check if the potential neighbor is in ...
                        %communication range.
                        if GeometryHelper.isPointInsideCircle(...
                                sensor.getLocation(), ...
                                obj.maximum_bluetooth_range, ...
                                potential_neighbor_sensor.getLocation())

                            % Since in theory it is in range, we ...
                            %consider it as a neighbor to simulate ...
                            %the bluetooth communication.
                            sensor.addNeighbor(potential_neighbor_sensor);
                            potential_neighbor_sensor.addNeighbor(sensor);
                        end
                    end
                end
            end
        end
        
        function updateFires(obj, hourly_wind, hourly_humidity, hourly_temperature)            
            for f = 1 : length(obj.fires)
                fire = obj.fires{f};
                
                fire_sz = fire.getSubZone();
                fire.updateWeather(hourly_wind(fire_sz), ...
                    hourly_humidity(fire_sz),...
                    hourly_temperature(fire_sz));
                
                fire.increaseArea(obj.sensing_rate);
            end
        end
        
        function generateFires(obj, sz_num, temperature, humidity, wind)
            obj.fire_generator.updateFireProbability(temperature, ...
                                                     humidity, wind);
            % Randomly create one or more fires             
            if rand() < obj.fire_generator.getFireProbability()
                % Makes sure that the randi expression doesn't get ...
                %executed at each iteration in order to prevent weird ...
                %behavior and unnecessary computation overhead. 
                amount_of_fires_created = randi(3); % (up to 3 fires) 
                
                for f = 1 : amount_of_fires_created
                    start_x = obj.subzones_min_and_max_coordinates{sz_num}{1}{1};
                    finish_x = obj.subzones_min_and_max_coordinates{sz_num}{2}{1};
                    start_y = obj.subzones_min_and_max_coordinates{sz_num}{1}{2};
                    finish_y = obj.subzones_min_and_max_coordinates{sz_num}{2}{2};

                    % Generate random location within subzone
                    origin = [randi([round(start_x), round(finish_x)],1), ...
                              randi([round(start_y), round(finish_y)],1)];

                    generated_fire = obj.fire_generator.generateFire(...
                            origin, sz_num, humidity, wind, temperature);

                    obj.fires{end + 1} = generated_fire;
                end
            end
        end
        
        function updateSensors(obj, sz_num, temperature, humidity, ...
                               day, hour, tick)
            % Check if there are any active sensor in the subzone
            if ~isempty(obj.sensors_per_subzone{1}) && ...
                    size(obj.sensors_per_subzone, 1) >= sz_num
                
                % Find which active sensors are in the subzone
                subzone_sensors = obj.sensors_per_subzone(sz_num, :);
                
                if ~isempty(find(cellfun('isempty', ...
                                         subzone_sensors), 1))
                                     
                    empty_cell_index = find(cellfun(...
                                                'isempty', subzone_sensors), ...
                                            1);
                                        
                    amount_of_active_sensors_in_subzone = ...
                        empty_cell_index - 1;
                else
                    amount_of_active_sensors_in_subzone = ...
                        length(subzone_sensors);
                end
                
                % Update each sensor of the subzone
                for s = 1 : amount_of_active_sensors_in_subzone
                    sensor = subzone_sensors{s};
                    
                    sensor_area_temperature = temperature;
                    
                    % Add humidity impact of fire (todo)
                    for f = 1 : length(obj.fires)
                        temperature_increase = ...
                            obj.fires{f}.getTemperatureIncreaseAtLocation(...
                                sensor.getLocation(), temperature);
                            
                        sensor_area_temperature = sensor_area_temperature + ...
                                                    temperature_increase;                       
                    end
                    
                    sensor.update(sensor_area_temperature, humidity, ...
                                  day, hour, tick);
                              
                    % Used to make sure the sensors send a sign of life ...
                    %at the expected rate which may differ from sensing ...
                    %rate.
                    if mod(tick, obj.sign_of_life_rate) == 0
                        sensor.send_sign_of_life();
                        sensor.check_sign_of_life();
                    end   
                end
            end
        end
        
        function detectFires(obj, sz_num)
            % Check if there are any active sensor in the subzone
            if ~isempty(obj.sensors_per_subzone{1}) && ...
                    size(obj.sensors_per_subzone, 1) >= sz_num
                
                % Find which active sensors are in the subzone
                subzone_sensors = obj.sensors_per_subzone(sz_num, :);
                
                if ~isempty(find(cellfun('isempty', ...
                                         subzone_sensors), 1))
                                     
                    empty_cell_index = find(cellfun(...
                                                'isempty', subzone_sensors), ...
                                            1);
                                        
                    amount_of_active_sensors_in_subzone = ...
                        empty_cell_index - 1;
                else
                    amount_of_active_sensors_in_subzone = ...
                        length(subzone_sensors);
                end
                
                % Update each sensor of the subzone
                for s = 1 : amount_of_active_sensors_in_subzone
                    sensor = subzone_sensors{s};
                    sensor.detectFire();
                end
            end
        end
        
        function sensorDefect(obj, sz_num)
            % Check if there are any active sensor in the subzone
            if ~isempty(obj.sensors_per_subzone{1}) && ...
                    size(obj.sensors_per_subzone, 1) >= sz_num
                
                % Find which active sensors are in the subzone
                subzone_sensors = obj.sensors_per_subzone(sz_num, :);
                
                if ~isempty(find(cellfun('isempty', ...
                                         subzone_sensors), 1))
                                     
                    empty_cell_index = find(cellfun(...
                                                'isempty', subzone_sensors), ...
                                            1);
                                        
                    amount_of_active_sensors_in_subzone = ...
                        empty_cell_index - 1;
                else
                    amount_of_active_sensors_in_subzone = ...
                        length(subzone_sensors);
                end
                
                sensor = obj.sensors_per_subzone{sz_num, ...
                                amount_of_active_sensors_in_subzone};
                
                % Remove sensor from gui
                if obj.visualizer_state
                    obj.visualizer.removeSensor(sensor);
                end
                
                % Remove sensor from simulator list
                obj.sensors_per_subzone{sz_num, ...
                        amount_of_active_sensors_in_subzone}(1) = [];
            end
        end
        
        function checkSensorsBrokenByFire(obj, sz_num)
            % Check if there are any active sensor in the subzone
            if ~isempty(obj.sensors_per_subzone{1}) && ...
                    size(obj.sensors_per_subzone, 1) >= sz_num
                
                % Find which active sensors are in the subzone
                subzone_sensors = obj.sensors_per_subzone(sz_num, :);
                
                if ~isempty(find(cellfun('isempty', ...
                                         subzone_sensors), 1))
                                     
                    empty_cell_index = find(cellfun(...
                                                'isempty', subzone_sensors), ...
                                            1);
                                        
                    amount_of_active_sensors_in_subzone = ...
                        empty_cell_index - 1;
                else
                    amount_of_active_sensors_in_subzone = ...
                        length(subzone_sensors);
                end
                
                indices_of_sensors_to_remove = [];
                
                for s = amount_of_active_sensors_in_subzone : - 1 : 1
                    sensor = obj.sensors_per_subzone{sz_num, s};
                    
                    for f = 1 : length(obj.fires)
                        fire = obj.fires{f};

                        fire_location = fire.getLocation();
                        radius = fire.getRadius();

                        distance = norm(sensor.getLocation() - fire_location);
                        
                        % Then sensor is inside the flames
                        if distance <= radius && ...
                                ~ismember(s, indices_of_sensors_to_remove)
                            
                            indices_of_sensors_to_remove = ...
                                [indices_of_sensors_to_remove s];
                        end 
                    end
                end
                
                for c = 1 : length(indices_of_sensors_to_remove)
                    idx = indices_of_sensors_to_remove(c);
                    
                    sensor = obj.sensors_per_subzone{sz_num, idx};
                                               
                    % Remove sensor from gui
                    if obj.visualizer_state
                        obj.visualizer.removeSensor(sensor);
                    end

                    % Remove sensor from simulator list
                    obj.sensors_per_subzone{sz_num, idx}(1) = [];
                   
                    for s = idx : (amount_of_active_sensors_in_subzone - c)
                        obj.sensors_per_subzone{sz_num, s}(1) = ...
                            obj.sensors_per_subzone{sz_num, s + 1}(1);
                    end
                    
                    if idx ~= amount_of_active_sensors_in_subzone - (c - 1)
                        obj.sensors_per_subzone{sz_num, ...
                                amount_of_active_sensors_in_subzone - ...
                                (c - 1)}(1) = [];
                    end
                end
            end
        end
        
        function findAndReplaceSensors(obj, sensors_info, day, hour, tick)
            for sii = 1 : length(sensors_info)
                for sz = 1 : obj.amount_of_subzones
                    start_x = ...
                       obj.subzones_min_and_max_coordinates{sz}{1}{1};
                    finish_x = ...
                       obj.subzones_min_and_max_coordinates{sz}{2}{1};
                    start_y = ...
                       obj.subzones_min_and_max_coordinates{sz}{1}{2};
                    finish_y = ...
                       obj.subzones_min_and_max_coordinates{sz}{2}{2};

                    location = sensors_info{sii};

                    if location(1) >= round(start_x) && ...
                           location(1) <= round(finish_x) && ...
                           location(2) >= round(start_y) && ...
                           location(2) <= round(finish_y)
                       
                       % Only way to create a do while loop in matlab :')
                       while 1
                           new_x = randi(...
                            [round(location(1) - obj.variance / 2), ...
                            round(location(1) + obj.variance / 2)],1);

                           new_y = randi(...
                            [round(location(2) - obj.variance / 2), ...
                            round(location(2) + obj.variance / 2)],1);

                           if new_x >= round(start_x) && ...
                               new_x <= round(finish_x) && ...
                               new_y >= round(start_y) && ...
                               new_y <= round(finish_y)
                           
                              break;
                           end
                       end

                       new_location = [new_x, new_y];
                       
                       generated_sensor = Sensor(new_location, ...
                               obj.subzones_discretized_weather_data{sz}{...
                                    1}(obj.starting_day, 1), ...
                               obj.subzones_discretized_weather_data{sz}{...
                                    2}(obj.starting_day, 1) / 100);
                           
                       % Find which active sensors are in the subzone
                       subzone_sensors = obj.sensors_per_subzone(sz, :);
                
                       if ~isempty(find(cellfun('isempty', ...
                                        subzone_sensors), 1))
                                     
                           empty_cell_index = find(cellfun('isempty', ...
                                        subzone_sensors), 1);
                                        
                           amount_of_active_sensors_in_subzone = ...
                               empty_cell_index - 1;
                       else
                           amount_of_active_sensors_in_subzone = ...
                               length(subzone_sensors);
                       end
                       
                       obj.assignNeighborsForGivenSensor(generated_sensor);
                            
                       generated_sensor.setTimeStamp(day, hour, tick);

                       obj.sensors_per_subzone{sz, ...
                                amount_of_active_sensors_in_subzone + 1} ...
                                    = generated_sensor;
                                
                       if obj.visualizer_state
                           obj.visualizer.spawnSensor(generated_sensor);
                       end

                       break;
                   end
               end
           end
        end
        
        function findAndExtinguishFires(obj, ...
                    location_of_sensors_which_detected_fire)
            
            fires_to_extinguish = [];    
                
            for l = 1 : length(location_of_sensors_which_detected_fire)
                for f = 1 : length(obj.fires)
                    fire = obj.fires{f};

                    fire_location = fire.getLocation();
                    influence_radius = fire.getRadiusOfInfluence();
                    
                    distance = norm(location_of_sensors_which_detected_fire{l} - fire_location);
            
                    if distance <= influence_radius
                        already_known = false;
                        
                        % Check to avoid duplicates
                        for fte = 1 : length(fires_to_extinguish)
                            if fires_to_extinguish(fte) == f
                               already_known = true; 
                               break;
                            end
                        end
                        
                        if ~already_known
                            fires_to_extinguish = [fires_to_extinguish f];
                            break;
                        end
                    end 
                end
            end
            
            fires_to_extinguish = sort(fires_to_extinguish);
            
            % Check if it doesn't create "holes" in the fires list
            for f  = 1 : length(fires_to_extinguish)
                idx = fires_to_extinguish(f);
                
                fire = obj.fires{idx - (f - 1)};
               
                if obj.visualizer_state
                    obj.visualizer.removeFire(fire);
                end
               
                obj.fires(idx - (f - 1)) = []; 
            end
        end
    end
end

