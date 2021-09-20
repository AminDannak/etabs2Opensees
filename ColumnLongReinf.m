classdef ColumnLongReinf < handle
    properties
        
       As = 0;
       sideBarsAs = 0;
       nBars % sum of the bars on all sides
       nSideBars
       sideBarsDiamArr
       defCornerBarD  = 20;
       sideBarsWidthsSum   = 0;
       hasBundledBars = 0;
       nMaxBundles = 0;
       nReqTransBars = 0;
       db = 0;
       transBarDiam = 10;        
        
    end
    
    methods
        
        function this = ColumnLongReinf(nSideBars,midBarsArray,varargin)
            % varargin{1} = corner bar(s) diameter [optional]
            % varargin{2} = number of corner bars  [optional]
            nMidBars = nSideBars - 2;
            barGroupHasMidBars = ~isempty(midBarsArray);
            if nargin == 2
                cornerBarDiam = this.defCornerBarD;
            elseif nargin == 3
                cornerBarDiam = varargin{1};
            elseif nargin == 4 && varargin{2} == 2
                % nargin == 4 is an indication of the reinforcement having
                % bunled bars, hence "hasBundledBars" property  is set here
                cornerBarDiam = varargin{1};
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
            
            if ~this.hasBundledBars
                this.sideBarsDiamArr = zeros(1,this.nBars);
            else
                this.sideBarsDiamArr = zeros(2,this.nBars);
            end
            
            for i = 1:nSideBars
                if i == 1 || i == nSideBars
                        this.sideBarsDiamArr(:,i) = cornerBarDiam;
                elseif barGroupHasMidBars
                    this.sideBarsDiamArr(1,i) = midBarsArray(1,i-1);
                    if this.hasBundledBars
                        this.sideBarsDiamArr(2,i) = midBarsArray(2,i-1);
                    end
                    
                end
            end
            
            this.nSideBars = nSideBars;
            this.nBars = 4 * (this.nSideBars - 1);
            this.calcAs();
            this.calcSideBarsAs();
            this.calcOneSideBarsWidthsSum();
            this.calc_db();
            
            % nReqTransBars property can change based on the
            % Pu<0.3(Ag)(f'c) equation. default value is set here, but it
            % might change during the execution of the program.
            this.nReqTransBars = floor(this.nSideBars/2)+1;
            this.nMaxBundles   = floor(this.nSideBars/2)+1;
        end        
        
        function calcAs(this)
            
            if ~this.hasBundledBars
                nBarsInGroup = 1;
            else
                nBarsInGroup = 2;
            end
            
            oneCornerBarsA = 0;
            [nCornerBars,~] = size(this.sideBarsDiamArr);
            for i = 1:nCornerBars
                diameter = this.sideBarsDiamArr(i,1);
                barArea  = (pi * diameter^2)/4;
                oneCornerBarsA = oneCornerBarsA + barArea;
            end
            
            oneSideMidBarsA    = 0;
            hasMiddleBars = this.nSideBars > 2;
%             disp('************************************')
%             disp(this)            
            if hasMiddleBars
                for j = 2:this.nSideBars-1
                    for i = 1:nBarsInGroup
%                         sprintf('(%i,%i)',i,j)
                        barArea = (pi * this.sideBarsDiamArr(i,j)^2)/4;
                        oneSideMidBarsA = oneSideMidBarsA + barArea;
                    end
                end
            end
            barsArea = 4 * (oneCornerBarsA + oneSideMidBarsA);
            this.As = barsArea;
        end        
        
        function calcSideBarsAs(this)
            barsAs = 0;
            for sb = 1:this.nSideBars
                barDiam = this.sideBarsDiamArr(sb);
                barArea = (pi/4) * barDiam^2;
                barsAs = barsAs + barArea;
            end
            this.sideBarsAs = barsAs;
        end
        
        function calcOneSideBarsWidthsSum(this)
            barsWidthSum = 0;
            for j = 1:this.nSideBars
                barsWidthSum = barsWidthSum + this.sideBarsDiamArr(1,j);
            end
            this.sideBarsWidthsSum = barsWidthSum;
        end        
        
        function calc_db(this)
            if ~this.hasBundledBars
                this.db = max(this.sideBarsDiamArr);
            else 
                areas = zeros(1,this.nBars);
                equivalentDiams = zeros(1,this.nBars);
                for b = 1:this.nBars
                    d1 = this.sideBarsDiamArr(1,b);
                    if this.sideBarsDiamArr(2,b) == 0
                        d2 = 0;
                    else
                        d2 = this.sideBarsDiamArr(2,b);
                    end
                    areas(b) = (pi/4)*(d1^2+d2^2);
                    equivalentDiams(b) = sqrt(4*areas(b)/pi);
                end
                this.db = max(equivalentDiams);
            end
        end        
        
        function ratio = caclCap2DemandAsRatio(this,As_req)
            ratio = this.As/As_req;
        end
        
        function barsC2Cdist = calcBarsC2Cdistance(this,section,allLongBarsNeedTransBar)
            secSide2BarCntr = section.cover + this.transBarDiam + ...
                this.sideBarsDiamArr(1)/2;
            availableDist = section.b - 2*secSide2BarCntr;
            nGaps = this.nSideBars - 1;
            
            if allLongBarsNeedTransBar
                nDistances = 1;
            else
                nDistances = 2;
            end
            barsC2Cdist = nDistances * (availableDist/nGaps);
        end
        
        function bar2barClrDist = calcBar2BarDistance(this,section)
            secSide2longBarOuterSide = section.cover + this.transBarDiam;
            availableDist = section.b - 2*secSide2longBarOuterSide ...
                - this.sideBarsWidthsSum;
            nGaps = this.nSideBars - 1;
            bar2barClrDist = availableDist/nGaps;
        end
        
        function reviseNreqTransBars(this,allLongBarsNeedTransBar)
            if allLongBarsNeedTransBar
                this.nReqTransBars = this.nSideBars;
            end
        end
    end
    
    methods (Static)
        function barGroups = createLongBarGroups(minAReq,maxAReq)
            function [indx,areaExceedsMaxLimit] = addBarGroup(nMidBars,midBarsDiamArr,indx)
                nSideBars = nMidBars + 2;
                barGroup = ColumnLongReinf(nSideBars,midBarsDiamArr);
                [AreaInReqRange,areaExceedsMaxLimit] = BeamLongReinf.barGroupAreaChk(barGroup,minAReq,maxAReq);
                if AreaInReqRange
%                     disp(barGroup.barsDiamArr)
                    barGroups{indx} = barGroup;
                    indx = indx + 1;
                elseif areaExceedsMaxLimit
                    barGroups = Domain.removeEmptyCellMembers(barGroups);
                    return
                end                
            end
            
            usedBars = [20 25];
            usedBars = sort(usedBars); % sorts them in ascending array
            [~,nBarTypes] = size(usedBars);
            nMaxPosbleBarGroups = ColumnLongReinf.calcMaxPossibleScenarios(nBarTypes,usedBars(1));
            barGroups = cell(1,nMaxPosbleBarGroups);
            barGroups{1} = ColumnLongReinf(2,[]);
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
            
            % caclulating the total number of longitudinal bar groups
            % having bundled bars in them based on groups that don't have
            % bundled bars.
            for nbg = 1:nNonBundGroups
                nonBundGroup = nonBundledGroups{nbg};
                nonBundGroup.nMaxBundles = ...
                    floor(nonBundGroup.nSideBars/2) + 1;
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
                    bundGrp = ColumnLongReinf(nonBundGroup.nBars,...
                        midBarsDiamArr,cornerBarsD,2);
                    bundGrp.nReqTransBars = nonBundGroup.nMaxBundles;
                    bundGrp.nMaxBundles = nonBundGroup.nMaxBundles;
                    bundGrp.hasBundledBars = 1;
                    barGroupsWithBundles{indx} = bundGrp;
                    indx = indx + 1;
                end
            end            
        end        
        
        function nMaxPossblBarGroups = calcMaxPossibleScenarios(nBarTypes,minBarDiam)
            minCover = 25;
            totalCover = 2 * minCover;
            maxColWidth = 2000;
            minClrSpce = 1.5 * minBarDiam; % using minBarDiam leads to a larger
            % number of bars, i.e. maximum possible cases
            availableDistance = (maxColWidth - totalCover - minBarDiam);
            barsMaxN = round(availableDistance/(minBarDiam + minClrSpce));
            sum = 0;
            for i = 1:barsMaxN
                sum = sum + i;
            end
            nMaxPossblBarGroups = sum * nBarTypes;
        end
    end
end