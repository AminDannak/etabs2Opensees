classdef ElasticColumn < handle
    properties
       openseesTag
       iNode
       jNode
       A  % unit: m^2
       E  % unit: Pa
       Iz % unit: m^4
       massDens
       soilLoad = 0;
       cumulativeVertLoad = 0; % its own weight + upper walls weights
       
    end    
    
    
    methods
        function this = ElasticColumn(tag,iNodeTag,jNodeTag,A,E,Iz,varargin)
            % varargin{1} is the "isOnBasement" argument
            
            mm2Tom2 = 1e-6;
            mm4Tom4 = 1e-12;
            MPa2Pa  = 1e+6;
            
            this.openseesTag = tag;
            this.iNode = iNodeTag;
            this.jNode = jNodeTag;
            this.A = A * mm2Tom2;
            this.E = E * MPa2Pa;
            this.Iz = Iz * mm4Tom4;
            isOnBasement = varargin{1};
            if isOnBasement
                % code gets here only if SUBBASE_ZERO_WEIGHT flag has a
                % value of 1 (i.e. subbase elements' weight is ignored)
                this.massDens = 0;
            else
                this.massDens = this.A * Domain.steelUnitVolMass;
            end            
        end
        
        function writeOpenseesCmmnd(this,fileID)
            commandFormat = ElasticColumn.openseescommnd();
            txt = sprintf(commandFormat,this.openseesTag,this.iNode,this.jNode,this.A,this.E,this.Iz,this.massDens);
            fprintf(fileID,txt);            
        end
        
        function inputArray = getInputArray(this)
            inputArray = [this.openseesTag,this.iNode,this.jNode,this.A,this.E,this.Iz,this.massDens];
        end
        
        function writeSoilLoadsToFile(this,fileID)
            % eleLoad -ele $eleTag -type -beamUniform $Wy
            txt = sprintf('\teleLoad -ele %s -type -beamUniform %d\n',this.openseesTag,this.soilLoad);
            fprintf(fileID,txt);            
        end
        
        function nStoryFromBot = getStoryNumber(this)
            % returns the number of the story
            % lowermost story is 1
            storyStr = this.openseesTag(3:4);
            nStoryFromBot = str2double(storyStr);
        end
        
        function calcCumulativeVertLoad(this,upperPrpWallsCumulVertLoad,wallHeight)
            unitVolWeight = Domain.concUnitVolumeMass * 9.81;
            wallVolume = wallHeight * this.A;
            wallWeight = unitVolWeight * wallVolume;
            this.cumulativeVertLoad = wallWeight + upperPrpWallsCumulVertLoad;            
        end
    end
    
    methods (Static)
        
        function commandFrmt = openseescommnd()
            commandFrmt = 'element elasticBeamColumn %s %s %s %d %d %d $transfTag -mass %d \n';
        end
        
    end
end