classdef HystereticModel < handle
    properties
        name
        tag
        k0         = 0;
        asPos      = 0;
        asNeg      = 0;
        MyPos      = 0;
        MyNeg      = 0;
        bigLambda  = 0;
        c          = 1;
        thetapPos  = 0;
        thetapNeg  = 0;
        thetapcPos = 0;
        thetapcNeg = 0;
        thetauPos  = 0;
        thetauNeg  = 0;
        ResPos     = 0;
        ResNeg     = 0;
        Dpos       = 1;
        Dneg       = 1;
        n          = 0;
        FprPos     = 0;
        FprNeg     = 0;
        A_pinch    = 0;
        
    end
    
    methods
        function this = HystereticModel(modelFlg,tag,k0,asPos,asNeg,MyPos,...
                MyNeg,bigLambda,thetapPos,thetapNeg,thetapcPos,thetapcNeg,...
                thetauPos,thetauNeg,n,varargin)
            rightNumberOfArgs = nargin == 15;
            if ~rightNumberOfArgs
                fprintf('\nWARNING!\n WRONG NUMBER OF ARGUMENTS')
                fprintf('FOR CREATING A HYSTERETIC MATERIAL\n')
            end
            
            switch modelFlg
                case 1
                    this.name = 'bilinear';
                case 2
                    this.name = 'peak-oriented';
                case 3
                    this.name = 'pinching';
                    [this.FprPos, this.FprNeg, this.A_pinch]  = ...
                            HystereticModel.pinchingThreeParams;
                otherwise
                    fprintf('\nWARNING!\nvalid values for modelFlg are:\n')
                    fprintf('1: for bilinear\n2: for peak-oriented\n 3: for pinching')
            end
            
            this.tag        = tag;
            this.k0         = k0;
            this.asPos      = asPos;
            this.asNeg      = asNeg;
            this.MyPos      = MyPos;
            this.MyNeg      = -MyNeg;
            this.bigLambda  = bigLambda;
            this.thetapPos  = thetapPos;
            this.thetapNeg  = thetapNeg;
            this.thetapcPos = thetapcPos;
            this.thetapcNeg = thetapcNeg;
            this.thetauPos  = thetauPos;
            this.thetauNeg  = thetauNeg;
            this.n          = n;
        end
        
        function writeOpenseesCmmnd(this,fileID)
            commandFormat = HystereticModel.openseescommnd(this.name);
            inputArgs     = this.getInputArray();
            txt           = sprintf(commandFormat,this.tag,inputArgs);
            fprintf(fileID,txt);
        end

        function numericInputsArr = getInputArray(this)
            inputsFirstPart = [this.k0,this.asPos,this.asNeg,this.MyPos,this.MyNeg];
            
            inputsLastPart = [this.bigLambda,this.bigLambda,this.bigLambda,this.bigLambda,...
                this.c,this.c,this.c,this.c,this.thetapPos,this.thetapNeg,...
                this.thetapcPos,this.thetapcNeg,this.ResPos,this.ResNeg,...
                this.thetauPos,this.thetauNeg,this.Dpos,this.Dneg,this.n];
            
            matIsPinching = strcmp(this.name,'pinching');
            if ~matIsPinching
                numericInputsArr = horzcat(inputsFirstPart,inputsLastPart);
            else % adding pinching model's 3 additional arguments
                inputsMidPart = [this.FprPos,this.FprNeg,this.A_pinch];
                numericInputsArr = horzcat(inputsFirstPart,inputsMidPart,inputsLastPart);
            end
        end
    end
    
    methods(Static)
        function commandFormat = openseescommnd(hystereticMatName)
            
            % the min number of arguments is 25, so:
            nMinArgs  = 25;
            inputArgs = ' %s '; % tag is a string (hence %s not %d)
            for i = 1:nMinArgs - 1
               inputArgs = strcat(inputArgs,' %d'); 
            end
            
            switch hystereticMatName
                case 'bilinear'
                    matCmmnd = 'uniaxialMaterial Bilin ';
                case 'peak-oriented'
                    matCmmnd = 'uniaxialMaterial ModIMKPeakOriented ';
                case 'pinching'
                    matCmmnd = 'uniaxialMaterial ModIMKPinching ';
                    % there are three additional arguments for pinching
                    % materials, so:
                    inputArgs = strcat(inputArgs,' %d %d %d ');
            end
            commandFormat = strcat(matCmmnd,inputArgs,'\n');
        end
        
        function [FprPos,FprNeg,A_pinch] = pinchingThreeParams()
            
           FprPos  = 0.25;
           FprNeg  = 0.25;
           A_pinch = 0.25;
           
        end
        
    end
    
end