classdef BasementWall < handle
    properties
       storyName
       thickness % unit: m
       nodes
       quads
       length % unit: mm
       height % unit: mm
       quadsW % unit: m
       quadsH % unit: m
       topLeftJoint
       topRightJoint
       botLeftJoint
       botRightJoint
       
       topLeftNode
       topRightNode
       botLeftNode
       botRightNode
       
       % topNodes: all top nodes of the wall are stored in this
       % non-empty for all walls
       topNodes
       topNodesVertLoad
%        topNodesVertLoads; % a vector containing wall nodal loads of top nodes
%        % bottomNodes: including bottom right/left nodes which are also
%        % stored in bot(Right/Left)Nodes
       
       % non-empty only for lowermost basement wall
       bottomNodes 
       bottomNodesMustBeFixed = 0;
       
       cumulativeVertLoad = 0; % its own weight + upper walls weights [+slab loads]
       
    end
    
    methods
        
        function this = BasementWall(storyName,wallThickness,...
                topLeftJoint,topRightJoint,botRightJoint,botLeftJoint)
            mm2m = 0.001;
            this.storyName     = storyName;
            this.thickness     = wallThickness * mm2m;
            this.topLeftJoint  = topLeftJoint;
            this.topRightJoint = topRightJoint;
            this.botRightJoint = botRightJoint;
            this.botLeftJoint  = botLeftJoint;
        end
        
        function generateWallNodes(this,isOnLowermostStory)
            topNodesY = min(this.topLeftJoint.openseesNodes{4}.z,...
                this.topRightJoint.openseesNodes{4}.z);
            if isOnLowermostStory
                this.bottomNodesMustBeFixed = 1;
                leftNodesX = this.topLeftJoint.openseesNodes{1}.x;
                rightNodesX = this.topRightJoint.openseesNodes{3}.x;
                botNodesY = 0;
            else
                leftNodesX = max(this.topLeftJoint.openseesNodes{1}.x,...
                    this.botLeftJoint.openseesNodes{1}.x);
                rightNodesX = min(this.topRightJoint.openseesNodes{3}.x,...
                    this.botRightJoint.openseesNodes{3}.x);
                botNodesY = max(this.botLeftJoint.openseesNodes{2}.z,...
                    this.botRightJoint.openseesNodes{2}.z);
            end
            
            this.length = rightNodesX - leftNodesX;
            this.height = topNodesY - botNodesY;
            
            nXdirQuads = ceil(this.length/BasementWall.maxQuadDimSize);
            nYdirQuads = ceil(this.height/BasementWall.maxQuadDimSize);
            this.nodes = cell(1,(nXdirQuads+1)*(nYdirQuads+1));
            this.quadsW = this.length/nXdirQuads;
            this.quadsH = this.height/nYdirQuads;
            
            if this.bottomNodesMustBeFixed
                this.bottomNodes = cell(1,nXdirQuads+1);
            end
            
            nTopNodes = nXdirQuads + 1;
            this.topNodes = cell(1,nTopNodes);
            nodeIndx = 1;
            topNodeIndx = 1;
            botNodeIndx = 1;
            for xg = 1:nXdirQuads+1
               for yg = 1:nYdirQuads+1
                  nodeX = leftNodesX + (xg-1)*this.quadsW;
                  nodeY = topNodesY - (yg-1)*this.quadsH;
                  nodeTag = strcat(this.topLeftJoint.opnssTag,...
                      num2str(xg),num2str(yg));
                  node = OpenseesNode(nodeTag,nodeX,nodeY);
                  
                  this.getMasterNodeIfNeeded(node,nXdirQuads,nYdirQuads,...
                      this.bottomNodesMustBeFixed,yg);
                  if this.bottomNodesMustBeFixed
                      nodeMustBeFixed = yg == nYdirQuads+1;
                      if nodeMustBeFixed
                          this.bottomNodes{botNodeIndx} = node;
                          botNodeIndx = botNodeIndx + 1;
                      end
                  end
                  
                  this.nodes{nodeIndx} = node;
                  nodeIndx = nodeIndx + 1;
                  
                  nodeIsOnWallTop = yg == 1;
                  if nodeIsOnWallTop
                     this.topNodes{topNodeIndx} = node;
                     topNodeIndx = topNodeIndx + 1;
                  end                  
               end
            end
%             disp('********************************')
%             disp(this.topLeftJoint)
%             disp(topNodeIndx)
            
        end
        
        function getMasterNodeIfNeeded(this,node,nXdirQuads,nYdirQuads,...
                onLowermostStory,nodeYGrid)
            if onLowermostStory && nodeYGrid == nYdirQuads+1
               return
            end
            nodeXdir = str2double(node.tag(8));
            nodeYdir = str2double(node.tag(9));
            if nodeXdir == 1 && nodeYdir == 1 % topLeftNode
%                 node.masterNodeTag = this.topLeftJoint.opnssTag;
                node.masterNodeTag = this.topLeftJoint.openseesNodes{4}.tag;
                this.topLeftNode = node;
            elseif nodeXdir == nXdirQuads+1 && nodeYdir == 1 % topRightNode
%                 node.masterNodeTag = this.topRightJoint.opnssTag;
                node.masterNodeTag = this.topRightJoint.openseesNodes{4}.tag;
                this.topRightNode = node;
            elseif nodeXdir == nXdirQuads+1 && nodeYdir == nYdirQuads+1 % botRightNode
%                 node.masterNodeTag = this.botRightJoint.opnssTag;
                node.masterNodeTag = this.botRightJoint.openseesNodes{2}.tag;
                this.botRightNode = node;
            elseif nodeXdir == 1 && nodeYdir == nYdirQuads+1 % botLeftNode
%                 node.masterNodeTag = this.botLeftJoint.opnssTag;
                node.masterNodeTag = this.botLeftJoint.openseesNodes{2}.tag;
                this.botLeftNode = node;
            end
        end
        
        function generateWallQuads(this,concUnitVolWeight)
            nXdirQuads = ceil(this.length/BasementWall.maxQuadDimSize);
            nYdirQuads = ceil(this.height/BasementWall.maxQuadDimSize);
            this.quads = cell(1,nXdirQuads*nYdirQuads);
            qIndx = 1;
            for xg = 1:nXdirQuads
                for yg = 1:nYdirQuads
                    iNodeTag = strcat(this.topLeftJoint.opnssTag,...
                        num2str(xg),num2str(yg));
                    jNodeTag = strcat(this.topLeftJoint.opnssTag,...
                        num2str(xg),num2str(yg+1));
                    kNodeTag = strcat(this.topLeftJoint.opnssTag,...
                        num2str(xg+1),num2str(yg+1));
                    lNodeTag = strcat(this.topLeftJoint.opnssTag,...
                        num2str(xg+1),num2str(yg));
                  quadTag = iNodeTag;
                  quadTag(1) = '7';
                  quad = Quad(quadTag,iNodeTag,jNodeTag,kNodeTag,lNodeTag,...
                      this.thickness,concUnitVolWeight);
                  this.quads{qIndx} = quad;
                  qIndx = qIndx + 1;
                end
                
            end
        end
        
        function writeNodesToFile(this,fileID)
            [~,nNodes] = size(this.nodes);
            for n = 1:nNodes
               node = this.nodes{n};
               node.writeOpenseesCmmnd(fileID);
            end
        end
        
        function writeNodesConstraintsToFile(this,fileID)
            [~,nNodes] = size(this.nodes);
            for n = 1:nNodes
               node = this.nodes{n};
               node.writeOpenseesConstraintCmmnd(fileID);
            end
        end
        
        function writeNodesFixityToFile(this,fileID)
           [~,nBotNodes] = size(this.bottomNodes);
           for bn = 1:nBotNodes 
               node = this.bottomNodes{bn};
               % fix $nodeTag (ndf $constrValues)
               fprintf(fileID,'fix %s 1 1\n',node.tag);
           end
        end
        
        function quadElmntsToFile(this,fileID,BASEMENTWALL_ELEMENT_FLAG)
            [~,nQuads] = size(this.quads);
            for q = 1:nQuads
               quadElmnt = this.quads{q};
               quadElmnt.writeOpenseesCmmnd(fileID,BASEMENTWALL_ELEMENT_FLAG);
            end
        end
        
        
        function assignLoadToNodes(this,upperWallsCumulVertForce)
           [~,nTopNodes] = size(this.topNodes);
           this.topNodesVertLoad = upperWallsCumulVertForce/nTopNodes;
           for n = 1:nTopNodes
               % the forces are toward negative Y direction, therefore the
               % negative sign
               this.topNodes{n}.yLoad = - this.topNodesVertLoad;
           end
        end
        
        function calcCumulativeVertLoad(this)
            mm2m = 0.001;
            unitVolWeight = Domain.concUnitVolumeMass * 9.81;
            wallVolume = this.height * this.length * mm2m^2 * this.thickness ;
            wallWeight = unitVolWeight * wallVolume;
            [~,nTopNodes] = size(this.topNodes);
            sumNodalLoads = this.topNodesVertLoad * nTopNodes;
            this.cumulativeVertLoad = wallWeight + sumNodalLoads;
        end        
    end
    
    methods (Static)
        function maxDimSize = maxQuadDimSize()
            maxDimSize = 1000; %unit: mm
        end
    end
end