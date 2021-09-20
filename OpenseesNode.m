classdef OpenseesNode < handle
    properties
        x
        z
        tag
        massX = 0;
        massY = 0; % Z notation was based on ETABS axes. Y notation agrees with opensees
        masterNodeTag = 'notSet'
        
        xLoad = 0;
        yLoad = 0;
        zMoment = 0;
    end
    
    
    methods
        function nodeObj = OpenseesNode(tag,x,z)
            nodeObj.tag = tag;
            nodeObj.x = x;
            nodeObj.z = z;
        end
        
        function writeOpenseesCmmnd(this,fileID)
            mm2mFac = 0.001;
            
            if (this.massX == 0 && this.massY == 0)
                cmnd = OpenseesNode.openseescommnd('allZero');
                txt = sprintf(cmnd,this.tag,this.x*mm2mFac,this.z*mm2mFac);
            else
                cmnd = OpenseesNode.openseescommnd();
                txt = sprintf(cmnd,this.tag,this.x*mm2mFac,this.z*mm2mFac,this.massX,this.massY);
            end
            fprintf(fileID,txt);
        end
        
        function writeOpenseesConstraintCmmnd(this,fileID)
            nodeIsSlave = ~strcmp(this.masterNodeTag,'notSet');
           if nodeIsSlave
               % equalDOF $rNodeTag $cNodeTag $dof1 $dof2 ... 
               cmdFormat = 'equalDOF %s %s 1 2\n';
               txt = sprintf(cmdFormat,this.masterNodeTag,this.tag);
               fprintf(fileID,txt);               
           end
        end
        
        function writeLoadsToFile(this,fileID,nDOFs)
            nodeHasLoad = (this.yLoad ~= 0);
            if nodeHasLoad
                % load $nodeTag (ndf $LoadValues) 
                if nDOFs == 2
                    cmdFormat = 'load %s %d %d\n';
                    txt = sprintf(cmdFormat,this.tag,this.xLoad,this.yLoad);
                elseif nDOFs == 3
                    cmdFormat = 'load %s %d %d %d\n';
                    txt = sprintf(cmdFormat,this.tag,this.xLoad,this.yLoad,this.zMoment);
                else
                   warning('OpenseesNode::writeLoadsToFile()\nnDOFs can be either 2 or 3') 
                end
                fprintf(fileID,txt);
            end
        end
    end
    
    
    methods (Static)
        function cmnd = openseescommnd(varargin)
            if ~isempty(varargin) && strcmp(varargin{1},'allZero')
%                 cmnd = 'node     %-15s %-+25.15e %-+25.15e     -mass     $smallMass     $smallMass     $smallMass\n';
                cmnd = 'node     %-15s %-+15e %-+15e     -mass     $smallMass        $smallMass        $smallMass\n';
            else
                cmnd = 'node     %-15s %-+15e %-+15e     -mass     %-15e %-15e $smallMass\n';
            end
        end
    end
    
end