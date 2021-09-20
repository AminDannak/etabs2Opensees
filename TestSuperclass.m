classdef TestSuperclass < handle
   properties
        prop1
        prop2
   end
   
   methods (Static)
       function err()
          disp('ERR'); 
       end
   end
   
   methods
        function this = TestSuperclass (p1,p2)
            this.prop1 = p1;
            this.prop2 = p2;
        end
        
        function showLocation(~)
            disp('Superclass')
        end
    end
end