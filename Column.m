classdef Column < FrameElement
    properties
        xFrameID
        yFrameID
        P = 0;    %factored axial force. unit: KN
        isRC = 1; % 1: it's a Reinforced Concrete column, 0: it's not
        
        % reinforcements
        As_req     = 0;
        AvOnS_req  = 0;
        longReinf     
        
        % Capacity/Demand Ratios
        As_ConD    = 0;
        AvOnS_ConD = 0;
        
        % (column stiffness)/(story stiffness) ratio
        col2StryStfRatio
    end
    
    methods
        function this = Column(etabsUniqueID,etabsNonUniqueID,storyName,iJoint,jJoint,length)
            this@FrameElement(etabsUniqueID,etabsNonUniqueID,storyName,iJoint,jJoint,length);
        end
        
        function isOnOpnssFrms = isOnOpenseesFrames(this,frmID1,frmID2)
            cond1 = this.yFrameID == frmID1;
            cond2 = this.yFrameID == frmID2;
            isOnOpnssFrms = cond1 | cond2;
            if isOnOpnssFrms
                this.isOnOpenseesFrame = 1;
            end
        end
        
        function calcLn_and_assgnOpnssNodes(this,lowermostStry)
            iNode = this.iJoint_etabs;
            jNode = this.jJoint_etabs;
            this.jNode_opnss = jNode.openseesNodes{1,4};
            elmntOnLwestFloor = strcmp(this.storyName,lowermostStry);
            if ~elmntOnLwestFloor
                this.iNode_opnss = iNode.openseesNodes{1,2};
            else
                this.iNode_opnss = iNode.openseesNodes{1,5};
            end
            this.calcClrSpnLngth();
            
        end
        
        function calcClrSpnLngth(this)
            z2 = this.jNode_opnss.z;
            z1 = this.iNode_opnss.z;
            this.length_clrSpn = z2 - z1;
            this.Ls = 0.5 * this.length_clrSpn;
            
            if this.length_clrSpn < 0
                formatSpc = '\nERROR\ncoulmn with uniqueID_etabs %8s has negative length \n';
                fprintf(formatSpc,this.uniqueID_etabs);
            end            
        end
        
        function calcCap2DemRatios(this)
           this.As_ConD    = this.longReinf.As/this.As_req;
           this.AvOnS_ConD = this.transReinf.AvOnS/this.AvOnS_req;
        end
        
        function calcAWeb(this)
            this.nWebHorTransBars          = this.longReinf.nReqTransBars - 2;
            this.nWebTorsLongBarsOnOneSide = this.longReinf.nSideBars - 2;
            crnrBarDiam = this.longReinf.sideBarsDiamArr(1);
            crnrBarArea = pi/4 * crnrBarDiam^2;
            this.AWeb   = 4 * ((this.longReinf.As/4) - crnrBarArea);
            ncolSideBars        = this.longReinf.nSideBars;
            this.webBarsDiamArr = this.longReinf.sideBarsDiamArr...
                (2:ncolSideBars - 1);
        end
        
        function reviseDepthAndCalcDprime(this)
            clrCover     = this.section.cover;
            transBarDiam = this.transReinf.barDiam;
            longBarDiam  = this.longReinf.sideBarsDiamArr(1);
            d = this.section.h - (clrCover + transBarDiam + 0.5 * longBarDiam);
            dPrime              = this.section.h - d;
            this.section.d      = d;
            this.section.dPrime = dPrime;
        end
        
        function [db, AsBot, AsTop] = getLongReinfParams(this)
            db = max(this.longReinf.sideBarsDiamArr);
            AsBot  = this.longReinf.sideBarsAs;
            AsTop  = AsBot;            
        end
    end
    
end
