classdef Visualizer < handle
    %VISUALIZER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        % Display parameters
        bg_img;
        width;
        height;
        amount_of_subzones;
        
        % UIFigure and components
        UIFigure;
        UIAxes;
        CurrentTimeLabel;
        CurrentTimeTextLabel;
        CurrentAmountOfFiresLabel;
        CurrentAmountOfFiresTextLabel;
        
        % Simulation plots
        sensors_plot;
        fires_plot;
    end
    
    methods (Access = private)
        % Create UIFigure and components
        function createComponents(obj)

            % Create UIFigure and hide until all components are created
            obj.UIFigure = uifigure('Visible', 'off');
            obj.UIFigure.Name = 'Figure of simulated area';
           
            % Create UIAxes
            obj.UIAxes = uiaxes(obj.UIFigure);
            title(obj.UIAxes, 'Newcastle close-by parks')
            xlabel(obj.UIAxes, 'm')
            ylabel(obj.UIAxes, 'm')
            
            figure_size = get(obj.UIFigure, 'Position');
            obj.UIAxes.Position = [0 0 figure_size(3)-25 figure_size(4)-25];
           
            % Set axes properties
            obj.UIAxes.XAxisLocation = 'origin';
            obj.UIAxes.YAxisLocation = 'origin';
            axis(obj.UIAxes, [0  obj.width    0  obj.height]);
            grid(obj.UIAxes, 'on');
            
            % Set label properties
            obj.CurrentTimeTextLabel = uilabel(obj.UIFigure);
            obj.CurrentTimeTextLabel.Text = "Current simulation time:";
            obj.CurrentTimeTextLabel.Position = [10 figure_size(4)-25 130 22];
            
            obj.CurrentTimeLabel = uilabel(obj.UIFigure);
            obj.CurrentTimeLabel.Text = "Initialization";
            obj.CurrentTimeLabel.Position = [140 figure_size(4)-25 215 22];
            obj.CurrentTimeLabel.FontColor = 'b';
            
            obj.CurrentAmountOfFiresTextLabel = uilabel(obj.UIFigure);
            obj.CurrentAmountOfFiresTextLabel.Text = "Current amount of active fires: ";
            obj.CurrentAmountOfFiresTextLabel.Position = [370 figure_size(4)-25 165 22];
            
            obj.CurrentAmountOfFiresLabel = uilabel(obj.UIFigure);
            obj.CurrentAmountOfFiresLabel.Text = "0";
            obj.CurrentAmountOfFiresLabel.Position = [535 figure_size(4)-25 figure_size(3) 22];
            obj.CurrentAmountOfFiresLabel.FontColor = 'k';
            
            % Show the figure after all components are created
            obj.UIFigure.Visible = 'on';
        end
    end
    
    methods
        function obj = Visualizer(zone_image, width, height, ...
                                    amount_of_subzones)
            obj.bg_img = imread(zone_image + '.png');
            obj.width = width;
            obj.height = height;
            obj.amount_of_subzones = amount_of_subzones;
            obj.createComponents();
        end
        
        function roi = initializeGUI(obj, plane_mode, ...
                                        subzones_min_and_max_coordinates)
            % Set background image
            imagesc(obj.UIAxes, [0 obj.width], [0 obj.height], ...
                    flip(obj.bg_img, 1));
            
            % Correct image orientation
            set(obj.UIAxes, 'ydir', 'normal');
           
            % Make sure every plot from this point onwards will be added
            % alongside the existing ones
            hold(obj.UIAxes, 'on');
          
            % Display subzones (regions) of interest
            for sz = 1 : obj.amount_of_subzones
                start_x = subzones_min_and_max_coordinates{sz}{1}{1};
                finish_x = subzones_min_and_max_coordinates{sz}{2}{1};
                start_y = subzones_min_and_max_coordinates{sz}{1}{2};
                finish_y = subzones_min_and_max_coordinates{sz}{2}{2};
                
                subzone = patch(obj.UIAxes, ...
                                [start_x finish_x finish_x start_x], ...
                                [start_y start_y finish_y finish_y], ...
                                [0.5 0.5 0.5]);
                
                subzone.FaceAlpha = 0.3; % sets transparency

                text(obj.UIAxes, start_x + (finish_x - start_x) /2 - 1000, ...
                     start_y + (finish_y - start_y) /2, ...
                     "Region " + int2str(sz), 'Color', [1 1 1]);
            end
            
            if plane_mode
                obj.CurrentTimeLabel.Text = "Draw plane path";
                
                % Draw plane path
                roi = drawpolyline(obj.UIAxes);
                roi.Visible = 'off';
            else
                obj.CurrentTimeLabel.Text = "Creating random locations";
                roi = NaN;
            end
            
            obj.CurrentTimeLabel.Text = "Sensor deployment phase";
            obj.CurrentTimeLabel.FontColor = [0.5, 0.5, 1];
        end
        
        function spawnSensor(obj, sensor)
            sensor_location = sensor.getLocation();
            sensor_plot = plot(obj.UIAxes, sensor_location(1), ...
                                sensor_location(2), 'x', ...
                                'Color', [0.5, 0.5, 1], 'MarkerSize', 2);
            obj.sensors_plot{end+1} = sensor_plot;
            drawnow;
        end
        
        function updateGUI(obj, active_fires, sim_time)
            % Update simulation time display
            current_sim_time = sim_time;
            
            seconds = current_sim_time{4};
            
            if seconds < 60
                minutes = current_sim_time{3};
            else
                seconds = 0;
                minutes = current_sim_time{3} + 1;
            end
            
            if minutes < 60
                hours = current_sim_time{2};
            else
                minutes = mod(minutes, 60);
                hours = current_sim_time{2} + 1;
            end
            
            if hours < 24
                days = current_sim_time{1};
            else
                hours = mod(hours, 24);
                days = current_sim_time{1} + 1;
            end
            
            obj.CurrentTimeLabel.Text = "Day: " + days + "; Hour: " + hours + "; Minute: " + minutes + "; Second: " + seconds;
 
            if obj.CurrentTimeLabel.FontColor ~= 'k'
                obj.CurrentTimeLabel.FontColor = 'k';
            end
            
            % Updates fires visuals
            amount_of_active_fires = length(active_fires);
            
            % Add new and update existing fires
            for f = 1 : amount_of_active_fires
                fire = active_fires{f};
                fire_location = fire.getLocation();
                fire_exists = false;

                % Checks if fire plot already exists, if so it ...
                %updates its size.
                for p = 1 : length(obj.fires_plot)
                    if ~isempty(obj.fires_plot{p})
                        if obj.fires_plot{p}.XData == ...
                                fire_location(1) && ...
                           obj.fires_plot{p}.YData == ...
                                fire_location(2)

                           fire_exists = true;

                           obj.fires_plot{p}.MarkerSize = ...
                               pi * fire.getRadius() * fire.getRadius() * 0.75;
                        end
                    end
                end

                % If the fire plot didn't exist yet, it creates it.
                if ~fire_exists
                    fire_plot = plot(obj.UIAxes, ...
                                     fire_location(1), ...
                                     fire_location(2), 'o', ...
                                     'Color', [1, 0.5, 0.5], ...
                                     'MarkerFaceColor', ...
                                     [1, 0.5, 0.5], ...
                                     'MarkerSize', ...
                                     pi * fire.getRadius() * fire.getRadius() * 0.75);

                    obj.fires_plot{end+1} = fire_plot;
                end
            end
            
            % Update amount of current active fires display
            obj.CurrentAmountOfFiresLabel.Text = num2str(amount_of_active_fires);
            
            % Selects color based on whether there is any fire active or ... 
            %not.
            if amount_of_active_fires == 0
                obj.CurrentAmountOfFiresLabel.FontColor = 'k';
            else
                obj.CurrentAmountOfFiresLabel.FontColor = 'r';
            end

            % Force display update
            drawnow;
        end
        
        function removeFire(obj, fire)
            fire_location = fire.getLocation();
            
            % Find matching fire plot and removes it
            for p = 1 : length(obj.fires_plot)
                if obj.fires_plot{p}.XData == ...
                        fire_location(1) && ...
                   obj.fires_plot{p}.YData == ...
                        fire_location(2)

                   delete(obj.fires_plot{p});
                   obj.fires_plot(p) = [];
                   break;
                end
            end
        end
        
        function removeSensor(obj, sensor)
            sensor_location = sensor.getLocation();
            
            % Find matching fire plot and removes it
            for p = 1 : length(obj.sensors_plot)
                if obj.sensors_plot{p}.XData == ...
                        sensor_location(1) && ...
                   obj.sensors_plot{p}.YData == ...
                        sensor_location(2)

                   delete(obj.sensors_plot{p});
                   obj.sensors_plot(p) = [];
                   break;
                end
            end
        end
    end
end