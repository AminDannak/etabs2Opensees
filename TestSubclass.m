classdef TestSubclass < TestSuperclass
    methods
        function this = TestSubclass(p1,p2)
           this@TestSuperclass(p1,p2); 
        end
        
        function res = addOne(this,int)
            res = int+1;
        end
        
        function res = addTwo(int)
            res = 1 + addOne(int);
        end     
        
    end
    
    methods (Static)
        function sayHi(name)
            hiWord = TestSubclass.makeHi();
            disp(strcat(hiWord,name))
        end
        
        function hiStr = makeHi()
            hiStr = 'hi ';
        end   
        
        function showLocation(~)
            disp('Subclass')
        end        
        
    end 
end