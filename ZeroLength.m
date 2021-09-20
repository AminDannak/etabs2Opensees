classdef ZeroLength
   properties
       tag
       iNodeTag
       jNodeTag
       rotationalMat
       
   end
   
   methods
       function this = ZeroLength(tag,iNodeTag,jNodeTag,rotationalMat)
           this.tag = tag;
           this.iNodeTag = iNodeTag;
           this.jNodeTag = jNodeTag;
           this.rotationalMat = rotationalMat;
       end
       
       function writeOpenseesCmmnd(this,fileID)
           cmndFrmt = 'element zeroLength %s %s %s -mat $rigidMatTag $rigidMatTag %s -dir 1 2 6 \n';
           inputArgs = this.getInputArgs();
           txt = sprintf(cmndFrmt,inputArgs{1},inputArgs{2},...
               inputArgs{3},inputArgs{4});
           fprintf(fileID,txt);
       end
       
       function inputArgs = getInputArgs(this)
          inputArgs{1} = this.tag;
          inputArgs{2} = this.iNodeTag;
          inputArgs{3} = this.jNodeTag;
          inputArgs{4} = this.rotationalMat;
       end
       
   end
   
   
end