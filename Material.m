classdef Material < handle
    properties
       name
       E
       unitVolMass
       strength %f'c for concrete, Fy for steel
       
       strength_exp
       E_exp
    end
    
    methods
        function matObj = Material(name,E,unitVolMass,strength) 
           matObj.name = name;
           matObj.E = E;
           matObj.unitVolMass = unitVolMass;
           matObj.strength = strength;
        end
    end
        
end