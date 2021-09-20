classdef FrameElement < handle
   properties
        uniqueID_etabs
        nonUniqueID_etabs
        
        % BEAMS:
        %   iNode is on LEFT, jNode is on RIGHT
        % COLUMNS:
        %   iNode is on BOTTOM, jNode is on TOP
        % in XZ/YZ plane right is +X/+Y direction
        iJoint_etabs
        jJoint_etabs
        iNode_opnss 
        jNode_opnss
        storyName
        length
        length_clrSpn % l_n parameter in ACI: length of clear span, measured face to face of supports
        section
        isOnOpenseesFrame = 0;
        minBarDistance = 25;
        
        Ls % 0.5 * frame element's clear span
        rho_sh
        alpha_sl = 1; % bond-slip %steel columns wont need nor use this
%         d_b
        AWeb  = 0;
        nWebTorsLongBarsOnOneSide = 0;
        nWebHorTransBars = 0;   
        webBarsDiamArr
%         AvOnS
        transReinf
        % nonlinear model parameters
        elasticElmnt
        hystereticMat
        ImodFac
%         MyPos % N.m
%         MyNeg % N.m
%         Mr = 0;
%         Ky
%         Kstf
%         thetapPos
%         thetapNeg
%         thetapcPos
%         thetapcNeg
%         lambda
%         McPos
%         McNeg
   end
   
   methods
        function this = FrameElement(etabsUniqueID,etabsNonUniqueID,storyName,iJoint,jJoint,length)
            this.uniqueID_etabs = etabsUniqueID;
            this.nonUniqueID_etabs = etabsNonUniqueID;
            this.storyName = storyName;
            this.iJoint_etabs = iJoint;
            this.jJoint_etabs = jJoint;
            this.length = length;
        end
        
        function calcRhoSh(this)
            m2mmFactor  = 1000;
            this.rho_sh = (this.transReinf.AvOnS/m2mmFactor)/this.section.b;
        end
        
        function [db, AsBot, AsTop] = getLongReinfParams(~)
            db = 0;
            AsBot = 0;
            AsTop = 0;
            
            fprintf('\nWARNING!\n')
            fprintf('no GetLongReinfParam method has been defined in Column/Beam class')
        end
        
        function calcHystereticModelParams(this,tag,fc,Ec,fy,Es,HYSTERETIC_MODEL_FLAG,isOnBasement)
            KN2N   = 1000;
            Nmm2Nm = 0.001;
            tag = strcat('40',tag);
            d      = this.section.d;
            dPrime = this.section.dPrime;
            b      = this.section.b;
            h      = this.section.h;
            Ag     = this.section.Area;
            Ig     = this.section.I33_etabs;
            s      = this.transReinf.spacing;
            N      = -1 * (this.P) * KN2N; % unit: Newtons
            % in my code, compression is - , in Fardis formulation and in other
            % formulae, compression is + , so the P value is multiplied by -1
            nFac = Domain.stfnsModFac;
            [db, AsBot, AsTop] = this.getLongReinfParams();
            
%             hystereticModelIsPinching = (HYSTERETIC_MODEL_FLAG == 3);
%             if hystereticModelIsPinching
%                 FprPos  = 0.25;
%                 FprNeg  = 0.25;
%                 A_Pinch = 0.25;
%             end
            frmElmntRotStfns = (6*Ec*Ig/this.length_clrSpn) * Nmm2Nm;
            
            % frequently used params in equations
            sn    = (s/db)*sqrt(fy/100);
            nu    = N/(Ag*fc);
            rhoSh = this.rho_sh;
            if isOnBasement
                kstf  = FrameElement.calcKstf(N,Ag,fc,this.Ls,h);
                this.ImodFac = kstf;
                k0 = (kstf * frmElmntRotStfns);
%                 disp('*********************************************************')
%                 fprintf('ID: %s\nStory: %s\n',this.nonUniqueID_etabs,this.storyName)
%                 disp(this.elasticElmnt.openseesTag)
%                 disp(kstf)
            else
                ky    = FrameElement.calcKy(N,Ag,fc,this.Ls,h);
                k0   = (ky * frmElmntRotStfns); 
                this.ImodFac = ky;
%                 disp('*********************************************************')
%                 fprintf('ID: %s\nStory: %s\n',this.nonUniqueID_etabs,this.storyName)
%                 disp(this.elasticElmnt.openseesTag)
%                 disp(ky)                
            end
            
            
            % in MyPos, beam's bottom reinforcement is in tension
            MyPos = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsBot,AsTop,this.AWeb,N);
            MyNeg = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsTop,AsBot,this.AWeb,N);
            McPos = 1.3 * MyPos;
            McNeg = 1.3 * MyNeg;
            thetapPos  = FrameElement.calcThetaP(this.alpha_sl,nu,rhoSh,fc,fy,sn,AsBot,AsTop,b,h);
            thetapNeg  = FrameElement.calcThetaP(this.alpha_sl,nu,rhoSh,fc,fy,sn,AsTop,AsBot,b,h);
            asPos      = (McPos - MyPos)/(thetapPos * k0);
            asNeg      = (McNeg - MyNeg)/(thetapNeg * k0);
            thetapcPos = FrameElement.calcThetaPC(nu,rhoSh,AsBot,AsTop,b,h,fc,fy);
            thetapcNeg = FrameElement.calcThetaPC(nu,rhoSh,AsTop,AsBot,b,h,fc,fy);
            thetayPos  = MyPos/k0;
            thetayNeg  = MyNeg/k0;
            thetauPos  = thetayPos + thetapPos + thetapcPos;
            thetauNeg  = thetayNeg + thetapNeg + thetapcNeg;
            lambda     = FrameElement.calcLambda(nu,s,d);
            bigLambda  = lambda * min(thetapPos,thetapNeg);
            
            % if arguments seem wrong, it's because you are :D
            % acoording to joint2D nodes axes, the material params should
            % be altered like this (*Pos and *Neg values are used instead
            % of one another):
            this.hystereticMat = HystereticModel(HYSTERETIC_MODEL_FLAG,...
                 tag,k0,asNeg,asPos,MyNeg,MyPos,bigLambda,thetapNeg,...
                thetapPos,thetapcNeg,thetapcPos,thetauNeg,thetauPos,nFac);
            
        end        
   end
   
   methods (Static)
        function My = calcMy(fc,Ec,fy,Es,d,dPrime,b,tensionAs,compressionAs,AWeb,N)
            Nmm2Nm = 1e-3;
            
            n = Es/Ec;
            rho = tensionAs/(b*d);
            rhoPrime = compressionAs/(b*d);
            rhoNu = AWeb/(b*d);
            deltaPrime = dPrime/d;
            
            A_stlYld = rho + rhoPrime + rhoNu + N/(b*d*fy);
            B_stlYld = rho + rhoPrime*deltaPrime + ...
                0.5*rhoNu * (1 + deltaPrime) + N/(b*d*fy);
            Ky_stlYld = sqrt(n^2*A_stlYld^2 + 2*n*B_stlYld) - n*A_stlYld;
            phiY_stlYld = fy/(Es*(1-Ky_stlYld)*d);
            
            A_concCmprs = rho + rhoPrime + rhoNu - N/(1.8*n*b*d*fc);
            B_concCmprs = rho + (rhoPrime*deltaPrime) + 0.5*rhoNu * (1 + deltaPrime);
            Ky_concCmprs = sqrt(n^2*A_concCmprs^2 + 2*n*B_concCmprs) - n*A_concCmprs;
            phiY_concCmpr = 1.8*fc/(Ec*Ky_concCmprs*d);
            
            if phiY_stlYld < phiY_concCmpr
                phiY = phiY_stlYld;
                Ky = Ky_stlYld;
            else
                phiY = phiY_concCmpr;
                Ky = Ky_concCmprs;
            end
            
            term1 = 0.5*Ec*Ky^2*(0.5*(1+deltaPrime)-Ky/3);
            term2 = 0.5*Es*((1-Ky)*rho + (Ky-deltaPrime)*rhoPrime+(rhoNu*(1-deltaPrime))/6)*(1-deltaPrime);
            My = phiY * (term1 + term2) * b * d^3;
            My = My * Nmm2Nm;
        end
        
        function Ky = calcKy(N,Ag,fc,Ls,h)
            Ky = -0.07 + 0.59*N/(Ag*fc) + 0.07*Ls/h;
            lowerLimit = 0.2;
            upperLimit = 0.6;
            Ky = FrameElement.applyUpperAndLowerLimits...
                (Ky,lowerLimit,upperLimit);
        end
        
        function Kstf = calcKstf(N,Ag,fc,Ls,h)
            Kstf = -0.02 + 0.98*N/(Ag*fc) + 0.09*Ls/h;
            lowerLimit = 0.35;
            upperLimit = 0.8;
            Kstf = FrameElement.applyUpperAndLowerLimits...
                (Kstf,lowerLimit,upperLimit);
        end    
        
        function thetaP = calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,tensionAs,CmprsnAs,b,h)
            rho = tensionAs/(b*h);
            rhoPrime = CmprsnAs/(b*h);
            thetaP = 0.12*(1+0.55*alpha_sl)*(0.16^nu)*(0.02+40*rhoSh)^0.43*...
                (0.54)^(0.01*fc)*0.66^(0.1*sn)*2.27^(10*rho);
            numerator   = max(0.01,rhoPrime*fy/fc);
            denomerator = max(0.01,rho*fy/fc);
            fardisTerm = (numerator/denomerator)^0.225;
            thetaP = thetaP * fardisTerm;

%             if showInfo
%                 disp('****************************************')
%                 fprintf('nu = %f\n',nu)
%                 fprintf('rhoSh = %f\n',rhoSh)
%                 fprintf('f''c = %f\n',fc)
%                 fprintf('fy = %f\n',fy)
%                 fprintf('sn = %f\n',sn)
%                 fprintf('rho = %f\n',rho)
%                 fprintf('rho'' = %f\n',rhoPrime)
%                 fprintf('thetaP = %f\n',thetaP)
%             end
        end
        
        function thetaPC = calcThetaPC(nu,rhoSh,tensionAs,CmprsnAs,b,h,fc,fy)
            thetaPC = (0.76)*(0.031^nu)*(0.02+40*rhoSh)^1.02;
            rho = tensionAs/(b*h);
            rhoPrime = CmprsnAs/(b*h);
            numerator   = max(0.01,rhoPrime*fy/fc);
            denomerator = max(0.01,rho*fy/fc);
            fardisTerm = (numerator/denomerator)^0.225;
            thetaPC = thetaPC * fardisTerm;
            lowerLimit = 0; % it's always a positive value
            upperLimit = 0.1;
            thetaPC = FrameElement.applyUpperAndLowerLimits...
                (thetaPC,lowerLimit,upperLimit);
        end
        
        function lambda = calcLambda(nu,s,d)
            lambda = 170.7 * (0.27^nu) * (0.10)^(s/d);
        end
        
        function revisedValue = applyUpperAndLowerLimits(value,lowLim,upLim)
            if value < lowLim
                revisedValue = lowLim;
            elseif value > upLim
                revisedValue = upLim;
            else
                revisedValue = value;
            end            
        end
        
   end
    
end