classdef BeamLongReinf < handle
    properties
       As = 0;
       nBars % or number of bars + number of bundled bars
       barsDiamArr
       defCornerBarD  = 16;
       barWidthsSum   = 0;
       hasBundledBars = 0;
%        hasBundledCornerBars = 0;
       nMaxBundles = 0;
       nReqTransBars = 0;
       db = 0;
       transBarDiam = 10;
    end
    
    methods
        function this = BeamLongReinf(nMidBars,midBarsArray,varargin)
            % varargin{1} = corner bar(s) diameter [optional]
            % varargin{2} = number of corner bars  [optional]
            barGroupHasMidBars = ~isempty(midBarsArray);
            if nargin == 2
                cornerBarDiam = this.defCornerBarD;
            elseif nargin == 3
                cornerBarDiam = varargin{1};
            elseif nargin == 4 && varargin{2} == 2
                cornerBarDiam = varargin{1};
%                 this.hasBundledCornerBars = 1;
                this.hasBundledBars = 1;
            else
                sprintf('\nnumber of corner bars can only have the value of 2\n')
                return
            end
            if barGroupHasMidBars
                [~,midBarsArrayLength] = size(midBarsArray(1,:));
                if nMidBars ~= midBarsArrayLength
                    disp(this)
                    disp('nMidBars is not equal to the length of midBarsArray')
                    return
                end
            end
            
            this.nBars = nMidBars + 2;
            if ~this.hasBundledBars
                this.barsDiamArr = zeros(1,this.nBars);
            else
                this.barsDiamArr = zeros(2,this.nBars);
            end
            
            for i = 1:this.nBars
                if i == 1 || i == this.nBars
                        this.barsDiamArr(:,i) = cornerBarDiam;
                elseif barGroupHasMidBars
                    this.barsDiamArr(1,i) = midBarsArray(1,i-1);
                    if this.hasBundledBars
                        this.barsDiamArr(2,i) = midBarsArray(2,i-1);
                    end
                    
                end
            end
            this.calcAs();
            this.calcBarWidthsSum();
            this.calc_db();
            this.nReqTransBars = floor(this.nBars/2)+1;
        end
        
        function barsArea = calcAs(this)
            barsArea = 0;
            if ~this.hasBundledBars
                nBarsInGroup = 1;
            else
                nBarsInGroup = 2;
            end
            for i = 1:this.nBars
                for j = 1:nBarsInGroup
                    barArea = (pi * this.barsDiamArr(j,i)^2)/4;
                    barsArea = barsArea + barArea;
                end
            end
            this.As = barsArea;
        end
        
        function barWidthsSummation = calcBarWidthsSum(this)
            barWidthsSummation = 0;
            for i = 1:this.nBars 
                barWidthsSummation = barWidthsSummation + this.barsDiamArr(1,i);
            end
            this.barWidthsSum = barWidthsSummation;
        end
        
        function ratio = calcCap2DemRatio(this,reqBarArea)
            ratio = this.As/reqBarArea;
        end
        
        function bar2barClrDistance = calcBar2BarClrDist(this,section)
            cornerBarD = this.barsDiamArr(1,1);
            beamClrCover = section.cover - cornerBarD/2 - this.transBarDiam;
            totalCover = 2*beamClrCover;
            totalS = section.b - totalCover - this.barWidthsSum;
            nDistances = this.nBars - 1;
            bar2barClrDistance = totalS/nDistances;
        end
        
        function barsC2Cdistance = calcBarsC2Cdistance(this,section)
            cover = section.cover;
            totCover = 2*cover;
            beamWidth = section.b;
            widthMinusCovers = beamWidth - totCover;
            nDistances = this.nBars - 1;
            barsC2Cdistance = widthMinusCovers/nDistances;
            
        end
        
        function calc_db(this)
            if ~this.hasBundledBars
                this.db = max(this.barsDiamArr);
            else 
                areas = zeros(1,this.nBars);
                equivalentDiams = zeros(1,this.nBars);
                for b = 1:this.nBars
                    d1 = this.barsDiamArr(1,b);
                    if this.barsDiamArr(2,b) == 0
                        d2 = 0;
                    else
                        d2 = this.barsDiamArr(2,b);
                    end
                    areas(b) = (pi/4)*(d1^2+d2^2);
                    equivalentDiams(b) = sqrt(4*areas(b)/pi);
                end
                this.db = max(equivalentDiams);
            end
        end
        
        function sMax = calcSmax(this,sectionDepth)
            sMax = min(sectionDepth/4,6*this.db);
        end
    end
    
    methods (Static)

        function barGroups = createLongBarGroups(minAReq,maxAReq)
            function [indx,exceedsMaxLimit] = addBarGroup(nMidBars,midBarsDiamArr,indx)
                barGroup = BeamLongReinf(nMidBars,midBarsDiamArr);
                [AreaInReqRange,exceedsMaxLimit] = BeamLongReinf.barGroupAreaChk(barGroup,minAReq,maxAReq);
                if AreaInReqRange
%                     disp(barGroup.barsDiamArr)
                    barGroups{indx} = barGroup;
                    indx = indx + 1;
                elseif exceedsMaxLimit
                    barGroups = Domain.removeEmptyCellMembers(barGroups);
                    return
                end                
            end
            
            usedBars = BeamLongReinf.usedLongBars;
            usedBars = sort(usedBars); % sorts them in ascending array
            [~,nBarTypes] = size(usedBars);
            nMaxPosbleBarGroups = BeamLongReinf.calcMaxPossibleScenarios(nBarTypes,usedBars(1));
            barGroups = cell(1,nMaxPosbleBarGroups);
            barGroups{1} = BeamLongReinf(0,[]); % just 2 minBars for corners - no middle bars
            nMidBars = 1;
            indx = 2;

            while(1)
                for bt = 1:nBarTypes 
                    midBarsDiamArr = BeamLongReinf.makeUniformVec(nMidBars,usedBars(1));
                    notUsingMinBar = bt ~= 1;
                    if notUsingMinBar
                        for n = 1:nMidBars 
                            for pos = 1:n
                                midBarsDiamArr(pos) = usedBars(bt);
                            end
                            [indx,exceedsMaxLimit] = addBarGroup(nMidBars,midBarsDiamArr,indx);
                            if exceedsMaxLimit
                                return
                            end
                        end
                    else % using minBar
                        [indx,exceedsMaxLimit] = addBarGroup(nMidBars,midBarsDiamArr,indx);
                        if exceedsMaxLimit
                            return
                        end
                    end
                end
                nMidBars = nMidBars + 1;
            end

        end
        
        function barGroupsWithBundles = createBundledGroups(nonBundledGroups)
            nBarGroupsWithBundles = 0;
            [~,nNonBundGroups] = size(nonBundledGroups);
            for nbg = 1:nNonBundGroups
                nonBundGroup = nonBundledGroups{nbg};
                nonBundGroup.nMaxBundles = ...
                    floor(nonBundGroup.nBars/2) + 1;
               nBarGroupsWithBundles = nBarGroupsWithBundles + ...
                   nonBundGroup.nMaxBundles - 1; % corner bars are added simultaneousley
            end
            
            barGroupsWithBundles = cell(1,nBarGroupsWithBundles);
            indx = 1;
            for nbg = 1:nNonBundGroups
                nonBundGroup = nonBundledGroups{nbg};
                midBarsDiamArr = zeros(2,nonBundGroup.nBars-2);
                midBarsDiamArr(1,:) = ...
                    nonBundGroup.barsDiamArr(2:nonBundGroup.nBars-1);
                cornerBarsD = nonBundGroup.barsDiamArr(1);
%                 nBundles = 2;
                for bg = 2:nonBundGroup.nMaxBundles
                    if bg > 2
                        nBundledMidBars = bg - 2;
                        midBarsDiamArr(2,1:nBundledMidBars) = ...
                            nonBundGroup.barsDiamArr(2:1+nBundledMidBars);
%                         nBundles = bg;
                    end
                    bundGrp = BeamLongReinf(nonBundGroup.nBars-2,...
                        midBarsDiamArr,cornerBarsD,2);
                    bundGrp.nReqTransBars = nonBundGroup.nMaxBundles;
                    bundGrp.nMaxBundles = nonBundGroup.nMaxBundles;
                    bundGrp.hasBundledBars = 1;
                    barGroupsWithBundles{indx} = bundGrp;
                    indx = indx + 1;
                end
            end            
        end
        
        function uniformVec =  makeUniformVec(nBars,barsDiam)
            if nBars ~= 0
                uniformVec = zeros(1,nBars);
                for i = 1:nBars
                    uniformVec(i) = barsDiam;
                end
            else
                uniformVec = [];
            end
        end

        function [AreaInReqRange,exceedsMaxLimit] = barGroupAreaChk(barGroup,minAReq,maxAReq)
            minAreaChk = barGroup.As > 0.9 * minAReq;
            maxAreaChk = barGroup.As < 1.3 * maxAReq;
            AreaInReqRange = minAreaChk && maxAreaChk;
            exceedsMaxLimit = ~maxAreaChk;
        end
        
        function nMaxPossblBarGroups = calcMaxPossibleScenarios(nBarTypes,minBarDiam)
            cover = 25;
            totalCover = 2*cover;
            maxBeamWidth = 1000;
            minClrSpce = 25;
            availableDistance = (maxBeamWidth - totalCover - minBarDiam);
            barsMaxN = round(availableDistance/(minBarDiam + minClrSpce));
            sum = 0;
            for i = 1:barsMaxN
                sum = sum + i;
            end
            nMaxPossblBarGroups = sum * nBarTypes;
        end
        
        % STATIC VARIABLES
        function usedBars = usedLongBars()
            usedBars = [16,20];
        end
        
        function dist = minLongBar2BarDist()
            dist = 25;
        end
    end
end