classdef Section < handle
   properties
       name
       matName
       elmntType % beam OR column
       t2
       t3
       Area
       I22_etabs
       I33_etabs
%        I33_revised
       
       cover
       b
       h
       d
       dPrime
       
   end
   
   methods
       function secObj = Section(name,matName,t2,t3,area,I22,I33)
           secObj.name      = name;
           secObj.matName   = matName;
           secObj.t2        = t2;
           secObj.t3        = t3;
           secObj.Area      = area;
           secObj.I22_etabs = I22;
           secObj.I33_etabs = I33;
           
           secObj.b = t3;
           secObj.h = t2;
%            secObj.I33_revised = I33;
       end
   end
end