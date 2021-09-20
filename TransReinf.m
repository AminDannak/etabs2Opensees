classdef TransReinf
   properties
      barDiam = 10;
      nTransBars
      Av
      AvOnS   %unit: mm2/m
      spacing %unit: mm
      mm2mFac = 0.001;
   end
   
   methods
       function this = TransReinf(nTransBar,spacing_mm,varargin)
           % varargin is for bar diameter [10mm by default]
           this.nTransBars = nTransBar;
           this.spacing    = spacing_mm;
           this.Av    = nTransBar * (pi/4) *(this.barDiam^2);
           this.AvOnS = this.Av / (this.spacing * this.mm2mFac);
           if nargin == 3
               barDiam = varargin{1};
               barDiamIsNotOK = ~ismember(barDiam,TransReinf.validBarDiams());
               if barDiamIsNotOK
                   disp('bars diameter can only be 8,10 or 12 mm')
               else
                   this.barDiam = varargin{1};
               end
           end
       end
      
       function transReinf = addOneBar(this)
           transReinf = TransReinf(this.nTransBars+1,this.barDiam,this.spacing);
       end
       
       function ratio = calcCap2DemRatio(this,reqAvOnS)
           ratio = this.AvOnS/reqAvOnS;
       end
       
       function sMaxIsOK = chkColSmax(this,longReinf,h_x,section,acceptableErr)
           s0 = TransReinf.calcS0(h_x);
           db = longReinf.db;
           h = section.h;
           sMax = min(h/4, 6*db);
           sMax = min(sMax,s0);
%            disp(sprintf('Smax = %s',sMax));
           if sMax * (1 + acceptableErr) >= this.spacing
               sMaxIsOK = 1;
           else
               sMaxIsOK = 0;
           end
       end
       
   end
   
   methods (Static)
       function transReinforcements = createTransReinforcements(maxReqAvOnS,varargin)
           % varargin is for bar diameter
           if nargin == 2
               notUsingDefBarDiam = 1;
               barDiam = varargin{1};
           elseif nargin == 1
               notUsingDefBarDiam = 0;
           else
               disp('wrong number of inputs for TransReinf.createTransReinforcements(...)')
           end
           nMaxTransBars = 10;
           spacings = TransReinf.spacings();
           [~,nSpacings] = size(spacings);
           nTotalTransReinfs = (nMaxTransBars - 1) * nSpacings;
           transReinforcements = cell(1,nTotalTransReinfs);
           indx = 1;
            for n = 2:nMaxTransBars
              for s = 1:nSpacings
                  if notUsingDefBarDiam
                      transReinforcements{1,indx} = ...
                          TransReinf(n,spacings(s),barDiam);
                  else
                      transReinforcements{1,indx} = TransReinf(n,spacings(s));
                  end
                  indx = indx + 1;
              end
            end
            if transReinforcements{1,indx-1}.AvOnS < maxReqAvOnS
              disp('___WARNING___')
              disp('maxReqAvOnS is not satisfied even with nMaxTransBar 10')
            end
       end
       
       function barDiams = validBarDiams()
           barDiams = [8 10 12];
       end
       
       function spacings = spacings()
           spacings = [100 75 50];
       end
       
       function s0 = calcS0(h_x)
           s0 = 100 + (350 - h_x)/3;
           if s0 < 100
               s0 = 100;
           elseif s0 > 150
               s0 = 150;
           end
       end
   end
end