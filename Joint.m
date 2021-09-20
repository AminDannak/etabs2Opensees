classdef Joint < handle
   properties
      x_etabs
      y_etabs
      z_etabs
      storyName
      xFrameID
      yFrameID
      uniqueID_etabs
      nonUniqueID_etabs
      XZcnnctdFrmObjctsUniqIDs % surrounding frame objects in CCW manner, starting from right hand beam in XZ plane
      YZcnnctdFrmObjctsUniqIDs % surrounding frame objects in CCW manner, starting from right hand beam in YZ plane
      width
      height
      openseesNodes = cell(1,5);
      opnssTag % main grid joint tag with format 50ABC0
      joint2dTag
      hystereticMatsTags
      lowermostLvlZeroLngth
      perpBasementWall = ElasticColumn('0','0','0',0,0,0,0); %ElasticColumn object
      
      isOnOpenseesFrames = 0;
      isOn2ndOpenseesFrame = 0;
      
      
      
   end
   
   methods
       function this = Joint(storyName,etabsUniqueID,etabsNonUniqueID,x,y,z)
           this.storyName = storyName;
           this.x_etabs = x;
           this.y_etabs = y;
           this.z_etabs = z;
           this.uniqueID_etabs = etabsUniqueID;
           this.nonUniqueID_etabs = etabsNonUniqueID;
           this.XZcnnctdFrmObjctsUniqIDs = zeros(1,4);
           this.YZcnnctdFrmObjctsUniqIDs = zeros(1,4);
       end
       
       function cmprsnValue = cmprCrdnts(this,aJoint)
           sameXordnts = (this.x_etabs == aJoint.x_etabs);
           sameYordnts = (this.y_etabs == aJoint.y_etabs);
           sameZordnts = (this.z_etabs == aJoint.z_etabs);
           cmprsnValue = (sameXordnts && sameYordnts && sameZordnts);
       end
       
       function writeOpenseesCmmnd(this,fileID)
           cmndFrmt = Joint.openseesCmmnd();
           inputArgs = this.getInputArgs();
           txt = sprintf(cmndFrmt,...
               inputArgs{1},inputArgs{2},inputArgs{3},...
               inputArgs{4},inputArgs{5},inputArgs{6},...
               inputArgs{7},inputArgs{8},inputArgs{9},...
               inputArgs{10});
           fprintf(fileID,txt);
       end
       
       function inputArgs = getInputArgs(this)
           nArgs = 10;
           inputArgs = cell(1,nArgs);
           this.generateJoint2dTag();
           inputArgs{1} = this.joint2dTag;
           
           % tags of nodes 1 to 5
           joint2dNodeTags = this.getJoint2dNodesTags();
           for i = 2:6
              inputArgs{i} = joint2dNodeTags{i-1};
           end
%            inputArgs{2:6} = this.getJoint2dNodesTags();
           hystMatsTags = this.hystereticMatsTags;
           for i = 7:10
%                inputArgs{i} = '0';
              inputArgs{i} = hystMatsTags{i-6}; 

           end
%            inputArgs{7:10} = this.hystereticMatsTags;
       end
       
       function ndTagsArr = getJoint2dNodesTags(this)
           ndTagsArr = cell(1,5);
           for nd = 1:5
               ndTagsArr{nd} = this.openseesNodes{nd}.tag;
           end
       end
       
       function createSupprotZeroLnegths(this)
           hystereticMatTag = this.hystereticMatsTags{2};
           iNodeTag = this.openseesNodes{4}.tag; % this is the node that
           % becomes fixed. zerolength element is put between this node and
           % joint's center node.
           jNodeTag = this.openseesNodes{5}.tag; % joint's center node. i.e.
           % column's bottom node.
           
           tag = this.opnssTag;
           tag(1:2) = '60';
           this.lowermostLvlZeroLngth = ZeroLength(tag,iNodeTag,jNodeTag,hystereticMatTag);
       end
       
       function generateJoint2dTag(this)
           tag = this.opnssTag;
           tag(1:2) = '50';
           this.joint2dTag = tag;
       end
       
       function writeNodesToFile(this,fileID,lowermostLvl)
           if ~strcmp(this.storyName,lowermostLvl) && this.isOnOpenseesFrames
               for n = 1:4
                  this.openseesNodes{n}.writeOpenseesCmmnd(fileID);
               end
           elseif strcmp(this.storyName,lowermostLvl) && this.isOnOpenseesFrames
               this.openseesNodes{4}.writeOpenseesCmmnd(fileID);
               this.openseesNodes{5}.writeOpenseesCmmnd(fileID);
           end
       end
   end
   
   methods (Static)
       function cmmndFrmt = openseesCmmnd()
           cmmndFrmt = 'element Joint2D %s %s %s %s %s %s %s %s %s %s $rigidMatTag $LrgDspTag \n';
%        cmmndFrmt = 'element Joint2D %s %s %s %s %s %s %s %s %s %s $rigidMatTag $LrgDspTag \n';
       end
   end
end