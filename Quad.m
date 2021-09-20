classdef Quad < handle
    
    properties
        quadTag
        iNodeTag
        jNodeTag
        kNodeTag
        lNodeTag
        type = 'PlaneStress'; % can also be 'PlaneStrain'
        thickness % unit: m
        unitVolWeight
    end
    
    methods
        function this = Quad(quadTag,iNode,jNode,kNode,lNode,thickness,unitVolWeight)
            this.quadTag = quadTag;
            this.iNodeTag = iNode;
            this.jNodeTag = jNode;
            this.kNodeTag = kNode;
            this.lNodeTag = lNode;
            this.thickness = thickness;
            this.unitVolWeight = unitVolWeight;
        end
        
        function writeOpenseesCmmnd(this,fileID,elementFlag)
            if elementFlag == 1 % use "quad" elements
               % element quad $eleTag $iNode $jNode $kNode $lNode $thick $type $matTag <$pressure $rho $b1 $b2>
               cmdFormat = 'element quad %s %s %s %s %s %d %s $elasticConcreteTag %d %d %d %d\n'; 
               txt = sprintf(cmdFormat,this.quadTag,this.iNodeTag,...
                   this.jNodeTag,this.kNodeTag,this.lNodeTag,...
                   this.thickness,this.type,0,0,0,-1*this.unitVolWeight*this.thickness);
            else                % use "SSPquad" elements
                % element SSPquad $eleTag $iNode $jNode $kNode $lNode $matTag $type $thick <$b1 $b2>
                cmdFormat = 'element SSPquad %s %s %s %s %s $elasticConcreteTag %s %d %d %d\n';
                txt = sprintf(cmdFormat,this.quadTag,this.iNodeTag,...
                    this.jNodeTag,this.kNodeTag,this.lNodeTag,...
                    this.type,this.thickness,0,-1*this.unitVolWeight);
            end
            fprintf(fileID,txt);
        end
    end
end