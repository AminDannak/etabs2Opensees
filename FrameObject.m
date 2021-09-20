classdef FrameElement < handle
   properties
        uniqueID_etabs
        nonUniqueID_etabs
        iJoint_etabs
        jJoint_etabs
        storyName 
   end
   
   methods
        function this = FrameElement(etabsUniqueID,etabsNonUniqueID,storyName,iJoint,jJoint)
            this.uniqueID_etabs = etabsUniqueID;
            this.nonUniqueID_etabs = etabsNonUniqueID;
            this.storyName = storyName;
            this.iJoint_etabs = iJoint;
            this.jJoint_etabs = jJoint;
        end
    end
end