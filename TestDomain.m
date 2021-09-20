classdef TestDomain < handle
   properties
       testObj;
       p1 = 10;
       p2 = 11;
   end
   
   methods
       function this = TestDomain()
          this.testObj = TestSubclass(1,2);
       end
       function assignMax(this,objProp,val)
           if (val > objProp)
               objProp = val;
           end
       end
       
       function addOneToProp(this,domProp)
           domProp = domProp + 1;
       end
       
   end
end