classdef ModElasticFrameElement < handle
    properties
       openseesTag
       iNode
       jNode
       A
       E
       IzFrmElmnt
       Iz
       K11
       K33
       K44
       massDens
       uniformLoad = 0;
    end
    
    methods
        function this = ModElasticFrameElement(tag,iNodeTag,jNodeTag,A,E,IzFrmElmnt,varargin)
            
            mm2Tom2 = 1e-6;
            mm4Tom4 = 1e-12;
            MPa2Pa  = 1e+6;
            
            this.openseesTag = tag;
            this.iNode = iNodeTag;
            this.jNode = jNodeTag;
            this.A = A * mm2Tom2;
            this.E = E * MPa2Pa;
            this.IzFrmElmnt = IzFrmElmnt * mm4Tom4;
            
            n = Domain.stfnsModFac;
            this.Iz = this.IzFrmElmnt * (n + 1)/n;
            this.K44 = 6 * (1 + n)/(2 + 3 * n);
            this.K11 = this.K44 * (1 + 2 * n)/(1 + n);
            this.K33 = this.K11;
            isOnBasement = varargin{1};
            if isOnBasement
                % code gets here only if SUBBASE_ZERO_WEIGHT flag has a
                % value of 1 (i.e. subbase elements' weight is ignored)
                this.massDens = 0;
            else
                this.massDens = this.A * Domain.concUnitVolumeMass;
            end
        end
        
        function writeOpenseesCmmnd(this,fileID)
            commandFormat = ModElasticFrameElement.openseescommnd();
%             inputArgs     = this.getInputArray();
            txt = sprintf(commandFormat,this.openseesTag,this.iNode,this.jNode,this.A,this.E,this.Iz,this.K11,this.K33,this.K44,this.massDens);
%             txt = sprintf(commandFormat,inputArgs);
            fprintf(fileID,txt);            
        end
        
        function inputArray = getInputArray(this)
            inputArray = [this.openseesTag,this.iNode,this.jNode,this.A,this.E,this.Iz,this.K11,this.K33,this.K44,this.massDens];
        end
        
        function writeBeamLoadToFile(this,fileID)
            % HUGE WARNING!!!!!!!!!!!!!!!
            % $Wy load is the load applied to element in "POSITIVE
            % DIRECTION"  of element's "LOCAL Y AXIS"
            % SO THE GRAVITY LOADS ARE "NEGATIVE"
            if this.uniformLoad ~= 0
                % eleLoad -ele $eleTag -type -beamUniform $Wy
                txt = sprintf('\teleLoad -ele %s -type -beamUniform %d\n',this.openseesTag,-1*this.uniformLoad);
                fprintf(fileID,txt);
            end
        end
    end
    
    methods (Static)
        
        function commandFrmt = openseescommnd()
            commandFrmt = 'element ModElasticBeam2d  %s %s %s %d %d %d %d %d %d $transfTag -mass %d \n';
        end
        
    end
end