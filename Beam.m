classdef Beam < FrameElement
    properties
        frameID
        clrCover = 25;
        P  = 0          %factored axial force
        
        % reinforcements
        AsTop_req  = 0;
        AstTop_req = 0; % As + extra A required for torsion
        AsBot_req  = 0;
        AstBot_req = 0; % As + extra A required for torsion
        Al_req     = 0;
        AvOnS_req  = 0;
        AtOnS_req  = 0;
        AtvOnS_req = 0; % required (Av + 2At)/s
        needsWebLongBars = 0;
        topLongReinf
        botLongReinf

        % Capacity/Demand Ratios
        AsTop_ConD = 0;
        AsBot_ConD = 0;
        AvOnS_ConD = 0;
        
    end
    
    methods
        function this = Beam(etabsUniqueID,etabsNonUniqueID,storyName,iJoint,jJoint,length)
            this@FrameElement(etabsUniqueID,etabsNonUniqueID,storyName,iJoint,jJoint,length);
        end
        
        function isOnOpnssFrms = isOnOpenseesFrames(this,frmID1,frmID2)
            cond1 = this.frameID == frmID1;
            cond2 = this.frameID == frmID2;
            isOnOpnssFrms = cond1 | cond2;
            if isOnOpnssFrms
                this.isOnOpenseesFrame = 1;
            end
        end
        
        function calcLn_and_assgnOpnssNodes(this)
            iNode = this.iJoint_etabs;
            jNode = this.jJoint_etabs;
            this.jNode_opnss = jNode.openseesNodes{1,3};
            this.iNode_opnss = iNode.openseesNodes{1,1};
            
            this.calcClrSpnLngth();
        end
        
        function calcClrSpnLngth(this)
            x2 = this.jNode_opnss.x;
            x1 = this.iNode_opnss.x;
            this.length_clrSpn = x2 - x1;
            this.Ls = 0.5 * this.length_clrSpn;
            
            if this.length_clrSpn < 0
                formatSpc = '\nERROR\nbeam with uniqueID_etabs %8s has negative length';
                fprintf(formatSpc,this.uniqueID_etabs);
            end
        end
        
        function reviseIg(this,slab_th)
            bw = this.section.b ;
            hb = this.section.h;
            hf = slab_th;
            width_flng = 2*this.length_clrSpn/8;

            A_justBeam = this.section.Area;
            A_flng = hf*(width_flng);
            A_sec = A_justBeam + A_flng;

            % measured from bottom of beam section
            beamAloneCntrdY = hb/2;
            flangesCntrdY = hb - (hf/2);

            cntrdY = (A_justBeam*beamAloneCntrdY + A_flng*flangesCntrdY)/A_sec;
            beamCntrdY2CntrdY = beamAloneCntrdY - cntrdY;
            flangesCntrdY2CntrdY = flangesCntrdY - cntrdY;

            beamAloneI = (bw*hb^3)/12 ;

            beamI = beamAloneI + A_justBeam*beamCntrdY2CntrdY^2;
            flangesI = (width_flng)*(hf^3)/2 + A_flng*flangesCntrdY2CntrdY^2;
            sectionI = beamI + flangesI;
            revisedI = 0.5 * (beamAloneI + sectionI);
            this.section.I33_etabs = revisedI;
        end
        
        function addTorsionalReinforcement(this)
            % calculating total Av/s (torsional+shear)
            this.AtvOnS_req = this.AtOnS_req + this.AvOnS_req;
            
            % calculating required longitudinal reinforcement, considering
            % longitudinal torsional reinforcement
            if this.Al_req == 0
               return 
            end
            section = this.section;
            cover2c = section.cover;
            bPrime  = section.b - 2*cover2c;
            hPrime  = section.h - 2*cover2c;
            maxTorsBarsDistance = 300;
            nReqTorsBarsOnHorSides = ceil(bPrime/maxTorsBarsDistance) + 1;
            nReqTorsBarsOnVerSides = ceil(hPrime/maxTorsBarsDistance) + 1;
            nTotReqTorsbars  = 2 * (nReqTorsBarsOnHorSides + nReqTorsBarsOnVerSides - 2);
            extraTorsAreaReq = this.Al_req * (nReqTorsBarsOnHorSides/nTotReqTorsbars);
            this.AstTop_req  = this.AsTop_req + extraTorsAreaReq;
            this.AstBot_req  = this.AsBot_req + extraTorsAreaReq;
        end
        
        function calcCap2DemRatios(this)
            this.AsTop_ConD = this.topLongReinf.As/this.AstTop_req;
            this.AsBot_ConD = this.botLongReinf.As/this.AstBot_req;
            this.AvOnS_ConD = this.transReinf.AvOnS/this.AtvOnS_req;            
        end
        
        function calcAWeb(this,acceptableErr)
            AWebReq = this.Al_req - ...
                (this.topLongReinf.As - this.AsTop_req) - ...
                (this.botLongReinf.As - this.AsBot_req);
            temp = 0;
            if this.topLongReinf.hasBundledBars
                temp = temp + 2 * this.topLongReinf.barsDiamArr(1,1);
            else
                temp = temp + this.topLongReinf.barsDiamArr(1);
            end
            if this.botLongReinf.hasBundledBars
               temp = temp + 2 * this.botLongReinf.barsDiamArr(1,1); 
            else
               temp = temp + this.botLongReinf.barsDiamArr(1);
            end
            cornerBarsDiamSum = temp;
            maxLongTorsBarsDist = 300;
            assumedSumOfLongAndTransBarsDiam = 20;
            freeDist = this.section.h - cornerBarsDiamSum - ...
                2 * (this.section.cover - assumedSumOfLongAndTransBarsDiam + ...
                this.transReinf.barDiam);
            nWebLongTorsBars = 2 * (ceil(freeDist/maxLongTorsBarsDist) - 1);
            this.nWebTorsLongBarsOnOneSide = nWebLongTorsBars/2;
            usedLongBars = sort(BeamLongReinf.usedLongBars);
            this.nWebHorTransBars = floor(this.nWebTorsLongBarsOnOneSide/4);
%             disp(this.section.h)
%             disp(freeDist)
            if nWebLongTorsBars > 0
                this.needsWebLongBars = 1;
            else
                return
            end
            [~,nUsedLongBars] = size(usedLongBars);
            while(1)
                for ub = 1:nUsedLongBars
                    bar2barClrDistIsOK = ...
                        this.chkWebLongBarsMinDist(freeDist,usedLongBars(ub),acceptableErr);
                    if ~bar2barClrDistIsOK
                        format = '\nsufficent web reinforcement was not found for beam on story %s with label %s';
                        fprintf(format,this.storyName,this.label)
                        return
                    else
                        barArea = pi/4 * usedLongBars(ub)^2;
                        totWebTorseLongBarsArea = nWebLongTorsBars * barArea;
                        areaSuffices = ...
                            AWebReq * (1 - acceptableErr) <= totWebTorseLongBarsArea;
                        if areaSuffices
                            this.AWeb;
                            this.webBarsDiamArr = BeamLongReinf.makeUniformVec...
                                (this.nWebTorsLongBarsOnOneSide,usedLongBars(ub));
                            return
                        end
                    end
                end
                nWebLongTorsBars = nWebLongTorsBars + 2;
                this.nWebTorsLongBarsOnOneSide = nWebLongTorsBars/2;
                this.nWebHorTransBars = floor(this.nWebTorsLongBarsOnOneSide/4);
            end
        end
        
        function isOK = chkWebLongBarsMinDist(this,distance,barsDiam,acceptableErr)
            nBars          = this.nWebTorsLongBarsOnOneSide;
            availableDist  = distance - (nBars * barsDiam);
            bar2barClrDist = availableDist/(nBars + 1);
            bar2barClrDistIsOK = bar2barClrDist >= ...
                BeamLongReinf.minLongBar2BarDist * (1 - acceptableErr);
            if bar2barClrDistIsOK
                isOK = 1;
            else
                isOK = 0;
            end
        end
        
        function calcDprime(this)
            this.section.dPrime = ...
                this.section.h - this.section.d;
        end
        
        function [db, AsBot, AsTop] = getLongReinfParams(this)
            db     = max(this.topLongReinf.db,this.botLongReinf.db);
            AsBot  = this.botLongReinf.As;
            AsTop  = this.topLongReinf.As;            
        end
    end
end
