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
        amount_of_sensors_per_100_square_meters = 3;
        
        % Expected maximum length for a properly working bluetooth ...
        %transmission in meters.
        maximum_bluetooth_range = 10;
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
        sensors_per_subzone_at_tick_t = {};
        fires_at_tick_t = {};
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
                    obj.amount_of_subzones = length(obj.subzones_variances);
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
                     starting_subzones_humidity] = obj.initSubzonesData();
                 
                    if obj.visualizer_state
                        roi = obj.visualizer.initializeGUI(plane_mode, ...
                                    obj.subzones_min_and_max_coordinates);
                    end
                                    
                    if plane_mode
                        
                        obj.generateSensorsBasedOnPlanePath(roi, ...
                                starting_subzones_temperature);
                        
                        delete(roi);
                    else
                        
                        obj.generateSensorsRandomly(...
                                starting_subzones_temperature);
                    end
                    
                    % Assign neighbors to each sensor to simulate the ...
                    %Bluetooth communication through a subscription ...
                    %pattern.
                    obj.assignNeighborlySensors();
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
                    for sz = 1 : length(obj.subzones_variances)
                        % Get hourly subzone environmental data
                        hourly_temperature(sz) = ...
                            obj.subzones_discretized_weather_data{sz}{1}(...
                                obj.starting_day + day, hour);

                        hourly_humidity(sz) = ...
                            obj.subzones_discretized_weather_data{sz}{2}(...
                                obj.starting_day + day, hour) ...
                            / 100; % Normalized to percentage
                    end
                    
                    % Update simulation respectively to sensing rate
                    for step = 1 : obj.sensing_rate : 60
                        % Update fires
                        obj.updateFires();
                        
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
                                              step);
                            
                            % Simulate random technical problem preventing ...
                            %sensor from working any longer.
                            if rand() <= 0.05
                                obj.sensorDefect(sz);
                            end            

                            % Updates GUI
                            if obj.visualizer_state
                                obj.visualizer.updateGUI(obj.fires, ...
                                                     {day, hour, step});
                            end
                        end
                        
                        obj.sensors_per_subzone_at_tick_t{end+1} = ...
                            obj.sensors_per_subzone;

                        obj.fires_at_tick_t{end+1} = ...
                            obj.fires;
                    end    
                end
            end
            
            s = obj.sensors_per_subzone_at_tick_t;
            f = obj.fires_at_tick_t;
        end
    end
    
    methods (Access = private)
        function [starting_subzones_temperature, ...
                  starting_subzones_humidity] = initSubzonesData(obj)
                
            starting_subzones_temperature = zeros(length(obj.subzones_variances), 1);
            starting_subzones_humidity = zeros(length(obj.subzones_variances), 1);
            
            amount_of_vertical_splits = ceil(sqrt(length(obj.subzones_variances)));
            amount_of_horizontal_splits = ceil(...
                                            length(obj.subzones_variances) ...
                                            / amount_of_vertical_splits);
            times_reached_max_x = -1;
            
            for sz = 1 : length(obj.subzones_variances)
                % Generate slightly different weather data for the subzone ...
                %using the provided subzone variance in temperature and ...
                %humidity.
                temperature_variance = obj.subzones_variances(sz, 1);
                humidity_variance = obj.subzones_variances(sz, 2);
                
                [regional_temperatures_min_matrix, ...
                    regional_temperatures_max_matrix, ...
                    regional_humidity_min_matrix, ...
                    regional_humidity_max_matrix] = ...
                    obj.weather_generator.regionalAlteration(...
                                            temperature_variance, ...
                                            humidity_variance);
                                        
                obj.subzones_weather_data{sz} = ...
                    {regional_temperatures_min_matrix; ...
                    regional_temperatures_max_matrix; ...
                    regional_humidity_min_matrix; ...
                    regional_humidity_max_matrix};
                
                % Discretize subzone weather data into hourly subzone ...
                % temperature and humidity.
                [hourly_temperatures_matrix, hourly_humidity_matrix] = ...
                    obj.weather_generator.discretizeHourlyWeatherData(...
                        regional_temperatures_min_matrix, ...
                        regional_temperatures_max_matrix, ...
                        regional_humidity_min_matrix, ...
                        regional_humidity_max_matrix);
                
                obj.subzones_discretized_weather_data{sz} = ...
                    {hourly_temperatures_matrix; hourly_humidity_matrix};
               
                % Retrieves and store the starting temperature and ...
                %humidity of the subzone.
                starting_subzone_temperature = ...
                    obj.subzones_discretized_weather_data{sz}{1}(...
                        obj.starting_day, 1);
                starting_subzone_humidity = ...
                    obj.subzones_discretized_weather_data{sz}{2}(...
                        obj.starting_day, 1);
                starting_subzones_temperature(sz) = ...
                    starting_subzone_temperature;
                starting_subzones_humidity(sz) = ...
                    starting_subzone_humidity;
                
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
        end
        
        function generateSensorsBasedOnPlanePath(...
                                        obj, roi, ...
                                        starting_subzones_temperature)        
                                    
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
                                    starting_subzones_temperature(sz));

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
                                    starting_subzones_temperature(sz));
                                
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
                                        starting_subzones_temperature)
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
                            starting_subzones_temperature);
            end
        end
        
        function generateSensorsRandomlyInSubzone(obj, sz_num, ...
                                        starting_subzones_temperature)
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
                                starting_subzones_temperature(sz_num));

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
        
        function assignNeighborlySensors(obj)
            for sz = 1 : length(obj.subzones_variances)
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
                    sensor = subzone_sensors{s};
                    for ns = 1 : amount_of_active_sensors_in_subzone
                        if s ~= ns
                            potential_neighbor_sensor = subzone_sensors{ns};
                            
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
            end
        end
        
        function updateFires(obj)
            fires_to_remove = {};
            for f = 1 : length(obj.fires)
                fire = obj.fires{f};
                fire.increaseArea(obj.sensing_rate);

                % Check detected fires and kill them (todo)
                if fire.getRadius() > 5
                    fires_to_remove{end+1} = f;
                end
            end
            
            for f = length(fires_to_remove): -1 : 1
                fire = obj.fires{fires_to_remove{f}};
               
                if obj.visualizer_state
                    obj.visualizer.removeFire(fire);
                end
               
                obj.fires(fires_to_remove{f}) = []; 
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

                    generated_fire = obj.fire_generator.generateFire(origin);

                    obj.fires{end + 1} = generated_fire;
                end
            end
        end
        %sz --> subzone
        function updateSensors(obj, sz_num, temperature, humidity, ...
                               day, hour, tick)
            % Check if there are any active sensor in the subzone
            if ~isempty(obj.sensors_per_subzone) && ...
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
                        %need to be changed?
                        temperature_increase = ...
                            obj.fires{f}.getTemperatureIncreaseAtLocation(...
                                sensor.getLocation(), temperature);
                            
                        sensor_area_temperature = sensor_area_temperature + ...
                                                    temperature_increase;                       
                    end
                    
                    sensor.update(sensor_area_temperature,...
                                  day, hour, tick);
                end
            end
        end
        
        function sensorDefect(obj, sz_num)
            % Check if there are any active sensor in the subzone
            if ~isempty(obj.sensors_per_subzone) && ...
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
                
                sensor = obj.sensors_per_subzone{sz_num, amount_of_active_sensors_in_subzone};
               
                if obj.visualizer_state
                    obj.visualizer.removeSensor(sensor);
                end
                
                obj.sensors_per_subzone{sz_num, amount_of_active_sensors_in_subzone}(1) = [];
            end
        end
    end
end

