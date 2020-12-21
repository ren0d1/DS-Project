classdef TimeHelper
    %TIMEHELPER Summary of this class goes here
    %   Detailed explanation goes here
    methods (Static)
        function are_equal = findIfTimeStampsAreEqual(time_stamp_1, ...
                                                        time_stamp_2)
           are_equal = false;
                                                    
           if time_stamp_1(1) == time_stamp_2(1) && ...
              time_stamp_1(2) == time_stamp_2(2) && ...
              time_stamp_1(3) == time_stamp_2(3) && ...
              time_stamp_1(4) == time_stamp_2(4)
                           
               are_equal = true;
            end
        end
        
        function delay_is_okay = findIfTimeStampsAreNotTooMuchApart(...
                                    time_stamp_1, delay, time_stamp_2)
            % time_stamp_1 needs to be the most recent one
            % seconds are not used because delay is in minutes                    
            time_stamp_1_value = time_stamp_1(1) * 24 * 60 + ...
                                 time_stamp_1(2) * 60 + time_stamp_1(3);
            time_stamp_2_value = time_stamp_2(1) * 24 * 60 + ...
                                 time_stamp_2(2) * 60 + time_stamp_2(3);
                             
            delay_is_okay = false;
            if time_stamp_1_value - delay < time_stamp_2_value    
                delay_is_okay = true;
            end
        end
    end
end

