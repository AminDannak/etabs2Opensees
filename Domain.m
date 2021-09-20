classdef Domain < handle
   properties (Access = public)
      xlsxFilePath
      xlsFilePath_25prcnt
      xlsFilePath_mass
      xlsFileTabsUsed
      openseesModelDir

      storiesTopDown
      nStories
      storiesHeights
      storiesMass     % unit: Kg
      storiesMass_pushover % unit: Kg
      storiesShear      % unit: KN
      nZgrids
      zGridOrdnts
      
      basementLevels % basement stories + base level
      nBasementLevels
      lowermostLevel
      bottomUpLevels

      nXgrids     % xGrids are perpendicular to X axis
      xGridOrdnts
      xGridIDs

      nYgrids     % yGrids are perpendicular to Y axis
      yGridOrdnts
      yGridIDs

      mainGridJoints;
      nMainGridJoints;
      
      beams
      nBeams
      
      columns
      nColumns
      
      sections
      nSections
      
      concMaterial
      steelMaterial
      longBarMaterial
      transBarMaterial
      
      maxReqReinfArea_beam = 0;
      minReqReinfArea_beam = 0;
      minReqReinfArea_column = 0;
      maxReqReinfArea_column = 0;
      maxReqAvOnS = 0;
      
      openseesNodes
      
      nXlsxFileTableUnusedRows = 3;
      
      mm2mFactor     = 1e-3;
      mm2cmFactor    = 1e-1;
      cm2mFactor     = 1e-2;
      m2mmFactor     = 1e3;
      cm2tomm2Factor = 1e2;
      cm4tomm4Factor = 1e4;
      KN2Nfactor     = 1e3;
      acceptableErr  = 0.04;
      minLongBarDistance = 25; %unit: mm
      
      beamsLongReinforcements
      columnsLongReinforcements
      transReinforcements
      
      slabs % cell of structs with theses fields: 'name' , 't'
      storiesSlabTh % stories slabs [top to bottom]
      walls % cell of structs with theses fields: 'name' , 't'
      basementStoriesWallTh % topDown
      storiesOccupancies % stories "TOP SLAB" occupancy
      basementWalls
      perpBasementWalls % perp. walls modeled as elastic beams
      perpBasementWallsNodes
      frameConnectingRigidElements
      buildingWeight = 0; % building weight (using FEMA p695 load combination)
      % and sum of stories weights (including basemnet levels)
      buildingWeight_upperLevels = 0;
      femaPeriod = 0;
      
   end
   
   methods (Static)
       
       
       function nFactor = stfnsModFac()
           nFactor = 1;
       end
       
       function massDens = concUnitVolumeMass()
           massDens = 2500; % unit: Kg/m2
       end
       
       function massDens = steelUnitVolMass()
           massDens = 7850; % unit: Kg/m2
       end
       
       function unitError()
           disp('_______ERROR!_______')
           disp('PARAMETERS ARE NOT IN TERMS OF SI UNITS')
           disp('SET UNITS TO SI IN ETABS AND RE-EXPORT EXCEL FILES')
       end
       
       function noEmptyMemCell = removeEmptyCellMembers(rawCell)
           [~,nMembers] = size(rawCell);
           nNonEmptyMembers = 0;
           for m = 1:nMembers
               if ~isempty(rawCell{1,m})
                   nNonEmptyMembers = nNonEmptyMembers + 1;
               end
           end
           noEmptyMemCell = cell(1,nNonEmptyMembers);
           for nem = 1:nNonEmptyMembers
               noEmptyMemCell{1,nem} = rawCell{1,nem};
           end
       end
       
       function writeTitleInFile(fileID,titleTxt)
           txtLength = length(titleTxt);
           for i = 1:txtLength-1
               if strcmp(titleTxt(i),'\')
                   if strcmp(titleTxt(i+1),'n')
                       disp('printing title failed')
                      disp('titleTxt cannot have the "\n" escape character') 
                      return
                   end
               end
           end
           
           width = 2 * txtLength;
           if width < 100
              width = 100; 
           end
           fillerChar = '#';
           asterisksLine(width) = ' ';
           nSideAstrks = 3;
           
           for a = 1:width
               asterisksLine(a) = fillerChar;
           end
           asterisksLine = strcat(asterisksLine,'\n');
           
           
           secondLine(width) = ' ';
           for i = 1:width
              if i <=nSideAstrks ||  i > width-nSideAstrks
                  secondLine(i) = fillerChar;
              else
                  secondLine(i) = ' ';
              end
           end
           secondLine = strcat(secondLine,'\n');
           
           middle = floor(width/2);
           nTxtFirstHalfChars = floor(txtLength/2);
           nTxtScndHalfChars  = txtLength - nTxtFirstHalfChars;
           
           txtLine = secondLine;
           txtLine(middle-nTxtFirstHalfChars:middle+nTxtScndHalfChars-1)...
               = titleTxt;
           
           toBePrintedTxt = strcat(asterisksLine,secondLine,...
               txtLine,secondLine,asterisksLine);
           fprintf(fileID,toBePrintedTxt);
       end
       
       function loads = occupanciesUniformLoads() 
           % loads are in terms of kN/m2
           loads = cell(1,4);
           loads{1} = struct('occupancy','Roof','load',2809.9,'extWallUnifLoad',2781.1);
           loads{2} = struct('occupancy','Residential','load',3119,'extWallUnifLoad',6901.3);
           loads{3} = struct('occupancy','Lobby','load',3822.5,'extWallUnifLoad',8240.4);
           loads{4} = struct('occupancy','Basement','load',2942.5,'extWallUnifLoad',0);
       end
       
   end
   
   methods
        %% Domain constructor
       function domainObj = Domain(inputFilePath,inputDir)
           domainObj.xlsxFilePath = strcat(inputFilePath,'.xlsx');
           domainObj.xlsFilePath_25prcnt = strcat(inputFilePath,'_25prcnt.xlsx');
           domainObj.xlsFilePath_mass    = strcat(inputFilePath,'_mass.xlsx');
           domainObj.openseesModelDir    = strcat(inputDir,'\openseesModel\');
           
           % checking to see if the output directory alreadt exists
           if exist(domainObj.openseesModelDir,'dir') == 0
               mkdir(domainObj.openseesModelDir);
           end
           
       end
       
       %% getting materials
       function getMaterials(this,STEEL_COLUMNS_FLAG)
           disp('getting Material data..')
           concExpectedStrengthRatio = 1.25; % ratio based on ATC-72
           rebarExpectedStrengthRatio = 1.2;
           nameCol = 1;
           Ecol = 2;
           % assigning concrete material data
           sheet = 'Material Properties - Concrete';
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           dataRow = this.nXlsxFileTableUnusedRows + 1;
           unitVolMassCol = 7;
           fcCol = 8;
           name = rawData{dataRow,nameCol};
           E = rawData{dataRow,Ecol};
           unitVolMass = rawData{dataRow,unitVolMassCol};
           fc = rawData{dataRow,fcCol};
           this.concMaterial = Material(name,E,unitVolMass,fc);
           
           this.concMaterial.strength_exp = fc * concExpectedStrengthRatio;
           this.concMaterial.E_exp = 4700 * sqrt(this.concMaterial.strength_exp);
           
           if STEEL_COLUMNS_FLAG
               % assigning steel material data
               sheet = 'Material Properties - Steel';
               [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
               dataRow = this.nXlsxFileTableUnusedRows + 1;
               fyCol = 8;
               name = rawData{dataRow,nameCol};
               E = rawData{dataRow,Ecol};
               unitVolMass = rawData{dataRow,unitVolMassCol};
               fy = rawData{dataRow,fyCol};
               this.steelMaterial = Material(name,E,unitVolMass,fy);
           end
           
           % assigning longitudinal and transverse bars materials
           sheet = 'Material Properties - Rebar';
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           fyCol = 6;
           % transverse
           transBarDataRow = this.nXlsxFileTableUnusedRows + 1;
           name = rawData{transBarDataRow,nameCol};
           E = rawData{transBarDataRow,Ecol};
           unitVolMass = rawData{dataRow,unitVolMassCol};
           fy = rawData{transBarDataRow,fyCol};
           this.transBarMaterial = Material(name,E,unitVolMass,fy);
           expectedStrengthRatio = 1.25; % ratio based on ATC-72
           this.transBarMaterial.strength_exp = rebarExpectedStrengthRatio * fy;
           this.transBarMaterial.E_exp = this.transBarMaterial.E;
           fy_trans = fy;
           % longitudinal
           longBarDataRow = transBarDataRow + 1;
           name = rawData{longBarDataRow,nameCol};
           E = rawData{longBarDataRow,Ecol};
           unitVolMass = rawData{dataRow,unitVolMassCol};
           fy = rawData{longBarDataRow,fyCol};
           this.longBarMaterial = Material(name,E,unitVolMass,fy);
           this.longBarMaterial.strength_exp = expectedStrengthRatio * fy;
           this.longBarMaterial.E_exp = this.longBarMaterial.E;
           fy_long = fy;
           
           if (fy_trans > fy_long)
               sprintf('_______WARNING!_______\n')
               sprintf('Fy_transverse > Fy_longitudinal\n')
           end
           
           
       end
       
       %% forming 3D grid of the etabs model
       function getStoriesData(this)
           sheet = 'Story Data';
           this.xlsFileTabsUsed = [this.xlsFileTabsUsed sheet];
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           
           unit = rawData{3,3};
           elevationsAreInTermsOfmm = strcmp(unit,'mm');
           if (~elevationsAreInTermsOfmm)
               this.unitError();
           end
           
           [nTotalRows,~] = size(rawData(:,1));
           this.nStories = nTotalRows - this.nXlsxFileTableUnusedRows - 1;

           this.storiesTopDown = cell(1,this.nStories);
           this.storiesHeights = zeros(1,this.nStories);

           firstDataRow = this.nXlsxFileTableUnusedRows + 1;
           lastDataRow  = firstDataRow + this.nStories - 1;

           for i = firstDataRow:lastDataRow
              index = i - this.nXlsxFileTableUnusedRows;
              this.storiesTopDown{1,index} = rawData{i,1};
              this.storiesHeights(1,index) = (rawData{i,3}); % *this.mm2mFactor;
           end
           
           tempIndx = 1;
           for i = lastDataRow+1: -1: firstDataRow
               this.bottomUpLevels{1,tempIndx} = rawData{i,1};
               tempIndx = tempIndx + 1;
           end
           
           this.lowermostLevel = rawData{lastDataRow+1,1};
           this.zGridOrdnts = [this.storiesHeights 0];
           this.zGridOrdnts = fliplr(this.zGridOrdnts);
           this.nZgrids = this.nStories + 1;
           
           % specify basement stories
           storyIsBasement = 0;
           for s = 1:this.nStories
               storyName = this.storiesTopDown(s);
               if strcmp(storyName,'Lobby')
                   storyIsBasement = 1;
               elseif storyIsBasement
                   this.basementLevels = [this.basementLevels storyName];
               end
           end
           this.basementLevels = [this.basementLevels this.lowermostLevel];
           [~,this.nBasementLevels] = size(this.basementLevels);
           
       end

       function getXYgridData(this)
           sheet = 'Grid Lines';
           this.xlsFileTabsUsed = [this.xlsFileTabsUsed sheet];
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           nXdirGrids = 0;
           nYdirGrids = 0;
           [nTotalRows,~] = size(rawData(:,1));
           nTotalXandYgrids = nTotalRows - this.nXlsxFileTableUnusedRows;

           firstDataRow = this.nXlsxFileTableUnusedRows + 1;
           lastDataRow = firstDataRow + nTotalXandYgrids - 1;
           ordinatesCol = 6;
           IDsCol = 3;

           for i = firstDataRow:lastDataRow

               if (rawData{i,2} == 'X')
                  nXdirGrids = nXdirGrids+1;
                  this.xGridOrdnts = [this.xGridOrdnts rawData{i,ordinatesCol}*this.m2mmFactor];
                  this.xGridIDs = [this.xGridIDs rawData{i,IDsCol}];
               else
                  nYdirGrids = nYdirGrids + 1;
                  this.yGridOrdnts = [this.yGridOrdnts rawData{i,ordinatesCol}*this.m2mmFactor];
                  this.yGridIDs = [this.yGridIDs rawData{i,IDsCol}];
               end
           end
           this.nXgrids = nXdirGrids;
           this.nYgrids = nYdirGrids;

       end

       function form3Dgrid(this)
           disp('forming 3D grid..')
           this.getStoriesData();
           this.getXYgridData();
       end
        
       %% getting joints data
       function assignJointsFrameLabel(this)
            % assigning xFrameID to joints
            for j = 1:this.nMainGridJoints
                
                for x = 1:this.nXgrids
                    jointIsOnGrid = (this.mainGridJoints(j).x_etabs == this.xGridOrdnts(x));
                    if (jointIsOnGrid)
                        this.mainGridJoints(j).xFrameID = this.xGridIDs(x);
                    end
                end
                % assigning yFrameID to joints
                for y = 1:this.nYgrids
                    jointIsOnGrid = (this.mainGridJoints(j).y_etabs == this.yGridOrdnts(y));
                    if jointIsOnGrid
                        this.mainGridJoints(j).yFrameID = this.yGridIDs(y);
                    end
                end
            end
       end    

       function getJointsData(this)
           disp('extracting main grid joints data..')
           sheet = 'Objects and Elements - Joints';
           this.xlsFileTabsUsed = [this.xlsFileTabsUsed sheet];
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           [nTotalRows,~] = size(rawData(:,1));
           
           unit = rawData{3,5};
           JointsCrdntsIn_mm = strcmp(unit,'mm');
           if (~JointsCrdntsIn_mm)
               this.unitError();
           end

           firstDataRow = this.nXlsxFileTableUnusedRows + 1;
           storyCol = 1;
           objTypeCol = 3;
           uniqueIDcol = 2;
           nonUniqueIDcol = 4;
           xCol = 5;
           yCol = 6;
           zCol = 7;
           for i = firstDataRow:nTotalRows
               objectIsJoint = strcmp(rawData{i,objTypeCol},'Joint');
               if(objectIsJoint)
                  storyName = rawData{i,storyCol};
                  uniqueID = rawData{i,uniqueIDcol};
                  nonUniqueID = rawData{i,nonUniqueIDcol};
                  x = rawData{i,xCol}; % *this.mm2mFactor;
                  y = rawData{i,yCol}; % *this.mm2mFactor;
                  z = rawData{i,zCol}; % *this.mm2mFactor;
                  % checking to see if the joint is on the main grid
                  isOnXgrid = ismember(x,this.xGridOrdnts);
                  isOnYgrid = ismember(y,this.yGridOrdnts);
                  isOnZgrid = ismember(z,this.zGridOrdnts);
                  jointIsOnMainGrid = 0;
                  if((isOnXgrid + isOnYgrid + isOnZgrid) == 3)
                      jointIsOnMainGrid = 1;
                  end

                  if(jointIsOnMainGrid)
                      newJoint = Joint(storyName,uniqueID,nonUniqueID,x,y,z);
                      this.mainGridJoints = [this.mainGridJoints newJoint];
                  end

               end
           end
           [~,this.nMainGridJoints] = size(this.mainGridJoints);
           this.assignJointsFrameLabel();
       end
       
       %% getting sections data
       function getSectionData(this)
          sheet = 'Frame Sections';
          [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
          [nTotalRows,~] = size(rawData(:,1));
          [~,nCols] = size(rawData);
          firstDataRow = this.nXlsxFileTableUnusedRows + 1;
          nameCol    = 1;
          matNameCol = 2;
          t3Col      = 4;
          t2Col      = 5;
          areaCol    = 9+2;
          I22Col     = 13+2;
          I33Col     = 14+2;
          if nCols ~= 30
              areaCol    = 9;
              I22Col     = 13;
              I33Col     = 14;              
          end
          
          for i = firstDataRow:nTotalRows
              secName = rawData{i,nameCol};
              matName = rawData{i,matNameCol};
              t3      = rawData{i,t3Col}; % *this.mm2cmFactor;
              t2      = rawData{i,t2Col}; % *this.mm2cmFactor;
              area    = rawData{i,areaCol}* this.cm2tomm2Factor;
              I22     = rawData{i,I22Col} * this.cm4tomm4Factor;
              I33     = rawData{i,I33Col} * this.cm4tomm4Factor;
              newSection = Section(secName,matName,t3,t2,area,I22,I33);
              this.sections = [this.sections newSection];
          end
          
          sectionDimIn_mm = strcmp(rawData{3,t3Col},'mm');
          if ~sectionDimIn_mm
              this.unitError();
              warndlg('section dimensions not in mm')
          end
          [~,this.nSections] = size(this.sections);
%           this.getSectionCovers();
       end
       
       %% getting frame objects data
       
       function jointObject = findJointByUniqueID(this,jointUniqueID)
           [~,nJoints] = size(this.mainGridJoints);
           for i = 1:nJoints
              id = this.mainGridJoints(i).uniqueID_etabs;
              if (id == jointUniqueID)
                  jointObject = this.mainGridJoints(i);
                  break;
              end
           end
       end
       
       function [iJoint,jJoint] = extractJointsData(~,jointStr)
           % in .xlsx exported file, iJoint and jJoints are written in one
           % cell, separated by a semicolon, e.g. 31; 32
           % note that there is a 'space' after ';'
           [~,jointStrSize] = size(jointStr);
           semiColonIndex = strfind(jointStr,';');
           iJointStr = jointStr(1:semiColonIndex-1);
           jJointStr = jointStr(semiColonIndex+2:jointStrSize);
           iJoint = str2double(iJointStr);
           jJoint = str2double(jJointStr);
       end
       
       function getColumnsConnectivities(this)
           sheet = 'Column Connectivity';
           this.xlsFileTabsUsed = [this.xlsFileTabsUsed sheet];
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           [nTotalRows,~] = size(rawData(:,1));
           firstDataRow = this.nXlsxFileTableUnusedRows + 1;

           storyCol = 1;
           nonUniqueIDcol = 2;
           uniqueIDcol = 3;
           jointCol = 4;
           lengthCol = 5;

           for i = firstDataRow:nTotalRows
               story = rawData{i,storyCol};
               nonUniqueID = rawData{i,nonUniqueIDcol};
               uniqueID = rawData{i,uniqueIDcol};
               jointsStr = rawData{i,jointCol};
               [iJointUniqueID,jJointUniqueID] = this.extractJointsData(jointsStr);
               iJoint = this.findJointByUniqueID(iJointUniqueID);
               jJoint = this.findJointByUniqueID(jJointUniqueID);
               length =  rawData{i,lengthCol}; % *this.mm2mFactor;

               newColumn = Column(uniqueID,nonUniqueID,story,iJoint,jJoint,length);
               this.columns = [this.columns newColumn];

           end
           [~,this.nColumns] = size(this.columns);
       end

       function getBeamsConnectivities(this)
           sheet = 'Beam Connectivity';
           this.xlsFileTabsUsed = [this.xlsFileTabsUsed sheet];
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           [nTotalRows,~] = size(rawData(:,1));
           firstDataRow = this.nXlsxFileTableUnusedRows + 1;

           storyCol = 1;
           nonUniqueIDcol = 2;
           uniqueIDcol = 3;
           jointCol = 4;
           lengthCol = 5;

           for i = firstDataRow:nTotalRows
               story = rawData{i,storyCol};
               nonUniqueID = rawData{i,nonUniqueIDcol};
               uniqueID = rawData{i,uniqueIDcol};
               jointsStr = rawData{i,jointCol};
               [iJointUniqueID,jJointUniqueID] = this.extractJointsData(jointsStr);
               iJoint = this.findJointByUniqueID(iJointUniqueID);
               jJoint = this.findJointByUniqueID(jJointUniqueID);
               length =  rawData{i,lengthCol}; % * this.mm2mFactor;

               newBeam = Beam(uniqueID,nonUniqueID,story,iJoint,jJoint,length);
               this.beams = [this.beams newBeam];
           end
           [~,this.nBeams] = size(this.beams);
       end
       
       function assignColumnsFrameID(this)
           for c = 1:this.nColumns
              for x = 1:this.nXgrids
                 columnIsOnGrid = (this.columns(c).iJoint_etabs.x_etabs == this.xGridOrdnts(x));
                 if columnIsOnGrid
                    this.columns(c).xFrameID = this.xGridIDs(x); 
                 end
              end
              
              for y = 1:this.nYgrids
                  columnIsOnGrid = (this.columns(c).iJoint_etabs.y_etabs == this.yGridOrdnts(y));
                  if columnIsOnGrid
                      this.columns(c).yFrameID = this.yGridIDs(y);
                  end
              end
           end
       end
       
       function assignBeamsFrameID(this)
           for b = 1:this.nBeams
               iJoint = this.beams(b).iJoint_etabs;
               jJoint = this.beams(b).jJoint_etabs;
               beamIsPrpndcularToXgrid = (iJoint.x_etabs == jJoint.x_etabs);
               if beamIsPrpndcularToXgrid
                   beamX = iJoint.x_etabs;
                   for x = 1:this.nXgrids
                       if (beamX == this.xGridOrdnts(x))
                          this.beams(b).frameID = this.xGridIDs(x); 
                       end
                   end
               else % if beam is perpendicular to Y-grid
                   beamY = iJoint.y_etabs;
                   for y = 1:this.nYgrids
                       if (beamY == this.yGridOrdnts(y))
                           this.beams(b).frameID = this.yGridIDs(y);
                       end
                   end
               end
           end
       end
       
       function assignSectionToFrameElements(this)
          sheet = 'Frame Assignments - Sections'; 
          [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
          firstDataRow = this.nXlsxFileTableUnusedRows + 1;
          [nTotalRows,~] = size(rawData(:,1));
          secNameCol = 6;
          frmElmntUniqIDcol = 3;
          for i = firstDataRow:nTotalRows
              secName = rawData{i,secNameCol};
              frmElmntUniqID = rawData{i,frmElmntUniqIDcol};
              for s = 1:this.nSections
                  section = this.sections(s);
                  if strcmp(secName,section.name)
                      % assign section to beams
                      for b = 1:this.nBeams
                          beam = this.beams(b);
                          if beam.uniqueID_etabs == frmElmntUniqID
                              beam.section = section;
                              section.elmntType = 'beam';
                              break
                          end
                      end
                      % assign section to columns
                      for c = 1:this.nColumns 
                          column = this.columns(c);
                          columnIsRc = strcmp(this.concMaterial.name,section.matName);
                          if column.uniqueID_etabs == frmElmntUniqID
                              column.section = section;
                              section.elmntType = 'column';
                              % specifying if the column is a steel one
                              if ~columnIsRc
                                  column.isRC = 0;
                              end
                              break
                          end
                      end
                  end
              end
          end
       end
       
       function getFrameObjectsData(this)
           disp('getting coulmns connectivity data..')
           this.getColumnsConnectivities();
           disp('getting beams connectivity data..')
           this.getBeamsConnectivities();
           disp('assigning coulmns'' frame ID..')
           this.assignColumnsFrameID();
           disp('assigning beams'' frame ID..')
           this.assignBeamsFrameID();
           disp('assigning sections to beams/columns..')
           this.assignSectionToFrameElements();
       end
       
       %% getting/calculating sections additional data (cover and depth)
       
       function caclulateSections_d(this)
           function getSectionCovers(sheet,secType,secNameCol,coverCol)
              [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
              firstDataRow = this.nXlsxFileTableUnusedRows + 1;
              [lastDataRow,~] = size(rawData(:,1));
              for row = firstDataRow:lastDataRow
                  for s = 1:this.nSections
                      section = this.sections(s);
                      sectionIsForELmntType = strcmp(section.elmntType,secType);
                      sectionIsNotSteel = ~strcmp(this.steelMaterial.name,section.matName);
                      if sectionIsForELmntType && sectionIsNotSteel
                          secDataIsHere = strcmp(rawData{row,secNameCol},section.name);
                          if secDataIsHere
                              section.cover = rawData{row,coverCol}; % * this.mm2cmFactor;
                              section.d = section.h - section.cover;
%                               section.dPrm = section.cover;
                          end
                      end
                  end
              end
           end
           
           sheet = 'Concrete Column Rebar Data';
           secNameCol = 1;
           coverCol = 8;
           getSectionCovers(sheet,'column',secNameCol,coverCol);
           
           sheet = 'Concrete Beam Rebar Data';
           coverCol = 4;
           getSectionCovers(sheet,'beam',secNameCol,coverCol);
       end
       
       function getSectionAdditionalData(this)
           disp('getting/calculating sections cover and depth..')
           this.caclulateSections_d();
       end

       
       %% making joints additional nodes
       function findSurroundingFrmObjcts(this)
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
               for c = 1:this.nColumns
                  column = this.columns(c);
                  columnIsAboveJoint = joint.cmprCrdnts(column.iJoint_etabs);
                  columnIsBelowJoint = joint.cmprCrdnts(column.jJoint_etabs);
                  
                  if columnIsAboveJoint
                      joint.XZcnnctdFrmObjctsUniqIDs(2) = column.uniqueID_etabs;
                      joint.YZcnnctdFrmObjctsUniqIDs(2) = column.uniqueID_etabs;
                  elseif columnIsBelowJoint
                      joint.XZcnnctdFrmObjctsUniqIDs(4) = column.uniqueID_etabs;
                      joint.YZcnnctdFrmObjctsUniqIDs(4) = column.uniqueID_etabs;
                  end
               end
               
               for b = 1:this.nBeams
                   beam = this.beams(b);
                   beamIsOnJointRight = joint.cmprCrdnts(beam.iJoint_etabs);
                   beamIsOnJointLeft = joint.cmprCrdnts(beam.jJoint_etabs);
                  
                  if beamIsOnJointRight
                      if (beam.frameID == joint.xFrameID)
                          joint.YZcnnctdFrmObjctsUniqIDs(1) = beam.uniqueID_etabs;
                      else
                          joint.XZcnnctdFrmObjctsUniqIDs(1) = beam.uniqueID_etabs;
                      end
                  elseif beamIsOnJointLeft

                      if (beam.frameID == joint.xFrameID)
                          joint.YZcnnctdFrmObjctsUniqIDs(3) = beam.uniqueID_etabs;
                      else
                          joint.XZcnnctdFrmObjctsUniqIDs(3) = beam.uniqueID_etabs;
                      end
                  end                  
               end
           end
       end
       
       function [beamsMaxHeight, columnsMaxWidth] = calcJointDimensions(this,joint)
          rightBeamID = joint.XZcnnctdFrmObjctsUniqIDs(1);
          topColumnID = joint.XZcnnctdFrmObjctsUniqIDs(2);
          leftBeamID  = joint.XZcnnctdFrmObjctsUniqIDs(3);
          botColumnID = joint.XZcnnctdFrmObjctsUniqIDs(4);
          
          rightBeamHeight = 0;
          topColWidth    = 0;
          leftBeamHeight   = 0;
          botColWidth    = 0;
          
          % if the joint is on the lowermost level, i.e. 'Base',
          % there is no joint there and its width and height,
          % i.e. 'beamsMaxHeight' and 'columnsMaxWidth' are ZERO
          if strcmp(this.lowermostLevel,joint.storyName)
              beamsMaxHeight  = 0;
              columnsMaxWidth = 0;
              return
          end
          
          
          for c = 1:this.nColumns
              col   = this.columns(c);
              colID = col.uniqueID_etabs;
              if colID == topColumnID
                  topColWidth = col.section.b;
                  continue
              elseif colID == botColumnID
                  botColWidth = col.section.b;
              end
          end
          
          for b = 1:this.nBeams 
              beam   = this.beams(b);
              beamID = beam.uniqueID_etabs;
              if beamID == rightBeamID
                  rightBeamHeight = beam.section.h;
              elseif beamID == leftBeamID
                  leftBeamHeight = beam.section.h;
              end
          end
          
          beamsMaxHeight   = max(rightBeamHeight,leftBeamHeight);
          columnsMaxWidth = max(topColWidth,botColWidth);
          
       end
       
       function openseesTag = generateOpenSeestag(this,joint)
           % generates tag for joint2D center node (i.e. main grid nodes)
           % openseesTag of each main grid joint follows this format:
           % 10ABC0
           A = 00; B = 0; C = 0;
           
           for l = 1:this.nZgrids
              if strcmp(joint.storyName,this.bottomUpLevels(l))
                  if l <= 10 
                      % A is a 2 digit-long number; so if "l" has
                      % only one digit, a '0' will be added at the
                      % beginning.
                      % why (l <= 10) ? bcoz 10th level, is the 9th story
                      % and 9 has 1 digit, not two
                      A = strcat('0',num2str(l-1));
                  else
                      A = num2str(l-1);
                  end
                  
              end
           end
           
           for y = 1:this.nYgrids
               if joint.yFrameID == this.yGridIDs(y)
                   if (y == 1 || y == 2)
                       joint.isOnOpenseesFrames = 1;
                       if y == 2
                          joint.isOn2ndOpenseesFrame = 1; 
                       end
                   end
                   B = num2str(y);
                   break
               end
           end
           
           for x = 1:this.nXgrids
              if joint.xFrameID == this.xGridIDs(x)
                  C = num2str(x);
                  break
              end
           end

           openseesTag = strcat('10',A,B,C,'0');
       end

       function createOpnssNodes(this,joint)
           
           joint.opnssTag = this.generateOpenSeestag(joint);
           if ~(joint.isOnOpenseesFrames)
               joint.opnssTag = '';
               return
           end
           
           rigidLinkLengthInMeter = 3000;
           modelWidth = max(this.xGridOrdnts);
           x = joint.x_etabs;
           z = joint.z_etabs;
           if joint.isOn2ndOpenseesFrame
               x = x + rigidLinkLengthInMeter + modelWidth;
           end
           cntrNode = OpenseesNode(joint.opnssTag,x,z);
           joint.openseesNodes{1,5} = cntrNode;
           if strcmp(joint.storyName,this.lowermostLevel)
               nodeX = x;
               nodeZ = z;
               halfJointH = 0;
               addAuxNodesTo1side(4);
               return
           end
           
           halfJointW = (0.5 * joint.width);  % * this.cm2mFactor;
           halfJointH = (0.5 * joint.height); % * this.cm2mFactor;
           nodeX = x;
           nodeZ = z;
           
           function addAuxNodesTo1side(positionCode)
               nodeTag    = joint.opnssTag;
               nodeTag(7) = num2str(positionCode);
               switch positionCode
                   case 1
                       nodeX = x + halfJointW;
                       nodeZ = z;
                   case 2
                       nodeZ = z + halfJointH;
                       nodeX = x;
                   case 3
                       nodeX = x - halfJointW;
                       nodeZ = z;
                   case 4
                       nodeZ = z - halfJointH;
                       nodeX = x;
               end

               newNode1 = OpenseesNode(nodeTag,nodeX,nodeZ);
               joint.openseesNodes{1,positionCode} = newNode1;
           end
           
           if joint.isOnOpenseesFrames
               for nodePosition = 1:4
                   addAuxNodesTo1side(nodePosition);
               end
           end
       end
       
       function createFrmsAuxilNodes(this)
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
                [joint.height, joint.width] = this.calcJointDimensions(joint);
                this.createOpnssNodes(joint);
                for node = 1:5
                    if ~isempty(joint.openseesNodes{1,node})
                        this.openseesNodes = [this.openseesNodes joint.openseesNodes{1,node}];
                    end
                end
           end
       end
       
       
       function makeJointsExtraNodes(this)
           disp('making joints extra nodes and auxiliary nodes..')
           this.findSurroundingFrmObjcts();
           this.createFrmsAuxilNodes();
       end
       
       %% calculate elements clear span lengths (i.e. ACI Ln) and assign opensees nodes to them
       function reviseFrmELmntsLengths(this)
           disp('calcualting elements ''clear span length''..')
           disp('assigning opensees nodes..')
           lowermostStry = this.basementLevels{1,this.nBasementLevels-1};
           for c = 1:this.nColumns
               column = this.columns(c);
               if column.isOnOpenseesFrames(this.yGridIDs(1),this.yGridIDs(2))
                  column.calcLn_and_assgnOpnssNodes(lowermostStry);
               end
           end
           
           for b = 1:this.nBeams
               beam = this.beams(b);
               if beam.isOnOpenseesFrames(this.yGridIDs(1),this.yGridIDs(2))
                   beam.calcLn_and_assgnOpnssNodes();
               end
           end
           
       end
       
       %% revising beams moment of inertia using slab thickness (if needed)
       function reviseBeamsIg(this,BEAM_Ig_FLAG)
           if BEAM_Ig_FLAG == 1
               this.getSlabSections();
               this.getStoriesSlabsTh();
               for b = 1:this.nBeams
                   beam = this.beams(b);
                   if beam.isOnOpenseesFrame
                       slabTh = this.getStorySlabTh(beam.storyName);
                       beam.reviseIg(slabTh);
                   end
               end
           end
       end
       
       function slabTh = getStorySlabTh(this,storyName)
           for s = 1:this.nStories
               if strcmp(storyName,this.storiesTopDown{s})
                   slabTh = this.storiesSlabTh(s);
                   return
               end
           end
       end

       function getSlabSections(this)
          sheet = 'Shell Sections - Slab';
          [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
          firstDataRow = this.nXlsxFileTableUnusedRows + 1;
          [lastDataRow,~] = size(rawData(:,1));
          nSlabSections = firstDataRow - lastDataRow + 1;
          this.slabs = cell(1,nSlabSections);
          nameCol = 1;
          thicknessCol = 5;
          indx = 1;
          for row = firstDataRow:lastDataRow
              name = rawData{row,nameCol};
              t = rawData{row,thicknessCol};
              this.slabs{indx} = struct('name',name,'t',t);
              indx = indx + 1;
          end
          
       end
       
       function getStoriesSlabsTh(this)
           % stores each story's slab thickness
           % [stories order is top down]
           this.storiesSlabTh = zeros(1,this.nStories);
           sheet = 'Shell Assignments - Sections';
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           firstDataRow = this.nXlsxFileTableUnusedRows + 1;
           [lastDataRow,~] = size(rawData(:,1));
           labelCol = 2;
           targetLabel = 'F1';
           sectionCol = 4;
           nSlabSection = length(this.slabs);
           indx = 1;
           for row = firstDataRow:lastDataRow
               if strcmp(rawData{row,labelCol},targetLabel)
                   for s = 1:nSlabSection
                       if strcmp(this.slabs{s}.name,rawData{row,sectionCol})
                           this.storiesSlabTh(indx) = this.slabs{s}.t;
                           indx = indx + 1;
                       end
                   end
               end
           end
       end       
       
       
       %% creating elastic elements with modified stiffness matrices
       
       function createZareianElasticElmnts(this,SUBBASE_ZERO_WEIGHT)
           Ec = this.concMaterial.E_exp;
           Es = this.steelMaterial.E;
           mustIgnoreSubBaseElmntsWeight = SUBBASE_ZERO_WEIGHT == 1;
           
           for b = 1:this.nBeams
               beam = this.beams(b);
               if beam.isOnOpenseesFrame
                   tag = this.generateBeamOpnssTag(beam);
                   iNodeTag = beam.iNode_opnss.tag;
                   jNodeTag = beam.jNode_opnss.tag;
                   A        = beam.section.Area;
                   IzFrmElmnt = beam.section.I33_etabs;
                   if mustIgnoreSubBaseElmntsWeight
                       isOnBasement = this.isOnBasementStories(beam.storyName);
                       beam.elasticElmnt = ModElasticFrameElement(...
                       tag,iNodeTag,jNodeTag,A,Ec,IzFrmElmnt,isOnBasement);
                   else
                       beam.elasticElmnt = ModElasticFrameElement(...
                       tag,iNodeTag,jNodeTag,A,Ec,IzFrmElmnt);
                   end
               end
           end
           
           for c = 1:this.nColumns
               column = this.columns(c);
               if column.isOnOpenseesFrame
                   tag = this.generateColumnOpnssTag(column);
                   iNodeTag = column.iNode_opnss.tag;
                   jNodeTag = column.jNode_opnss.tag;
                   A        = column.section.Area;
                   IzFrmElmnt = column.section.I33_etabs;
                   if mustIgnoreSubBaseElmntsWeight
                       isOnBasement = this.isOnBasementStories(column.storyName);
                       if column.isRC
                           column.elasticElmnt = ModElasticFrameElement(...
                               tag,iNodeTag,jNodeTag,A,Ec,IzFrmElmnt,isOnBasement);
                       else % basement steel columns
                           column.elasticElmnt = ElasticColumn(...
                               tag,iNodeTag,jNodeTag,A,Es,IzFrmElmnt,isOnBasement);
                       end
                   else
                       if column.isRC
                           column.elasticElmnt = ModElasticFrameElement(...
                               tag,iNodeTag,jNodeTag,A,Ec,IzFrmElmnt);
                       else % basement steel columns
                           column.elasticElmnt = ElasticColumn(...
                               tag,iNodeTag,jNodeTag,A,Es,IzFrmElmnt);
                       end
                   end
               end
           end
           
       end
       
       function tag = generateBeamOpnssTag(this,beam)
           prefix = '20';
           A = 'notAssigned';
           B = 'notAssigned';
           C = 'notAssigned';
           for s = 1:this.nZgrids
               if strcmp(beam.storyName,this.bottomUpLevels(s))
                   A = strcat('0',num2str(s-1));
               end
           end
           
           for yg = 1:this.nYgrids
               beamY = beam.iJoint_etabs.y_etabs;
               if beamY == this.yGridOrdnts(yg)
                   B = num2str(yg);
               end
               
           end
           
           for xg = 1:this.nXgrids 
               beamLeftX = beam.iJoint_etabs.x_etabs;
               if beamLeftX == this.xGridOrdnts(xg)
                   C = num2str(xg);
               end
           end
           tag = strcat(prefix,A,B,C);
       end
       
       function tag = generateColumnOpnssTag(this,column)
           prefix = '30';
           A = 'notAssigned';
           B = 'notAssigned';
           C = 'notAssigned';
           for s = 1:this.nZgrids
               if strcmp(column.storyName,this.bottomUpLevels(s))
                   A = strcat('0',num2str(s-1));
               end
           end
           
           for yg = 1:this.nYgrids
               columnY = column.iJoint_etabs.y_etabs;
               if columnY == this.yGridOrdnts(yg)
                   B = num2str(yg);
               end
               
           end
           
           for xg = 1:this.nXgrids 
               columnY = column.iJoint_etabs.x_etabs;
               if columnY == this.yGridOrdnts(xg)
                   C = num2str(xg);
               end
           end
           tag = strcat(prefix,A,B,C);           
       end
       
       %% specify beam/column reinforcements
       
       function specifyReinforcement(this)
           disp('getting beams required reinforcement..')
           beamReinfSheet = 'Concrete Beam Summary - ACI 318';
           this.getBeamsRequiredReinforcements(beamReinfSheet);
           
           disp('getting columns required reinforcement..')
           columnReinfSheet = 'Concrete Column Summary - ACI 3';
           this.getColumnsRequiredReinforcements(columnReinfSheet);
           
           disp('adding required toriosnal reinforcement..')
           this.addTorsionalReinforcement();
           
           disp('creating beams longitudinal reinforcement Groups..')
           beamsLongBarGrpsWithNoBundles = ...
               BeamLongReinf.createLongBarGroups(this.minReqReinfArea_beam,this.maxReqReinfArea_beam);
           beamsLongBarGrpsWithBundles = ...
               BeamLongReinf.createBundledGroups(beamsLongBarGrpsWithNoBundles);
           this.beamsLongReinforcements = ...
               this.sortBeamsLongReinfs(beamsLongBarGrpsWithNoBundles,beamsLongBarGrpsWithBundles);
           
           disp('creating transverse reinforcement Groups..')
           this.transReinforcements = TransReinf.createTransReinforcements(this.maxReqAvOnS);
           
           disp('assigning reinforcements to beams..')
           this.assignReinfToBeams();
           
           disp('getting columns axial forces..')
           this.getColumnsForces();
           
           disp('creating columns longitudinal reinforcement groups..')
           this.columnsLongReinforcements = ...
               ColumnLongReinf.createLongBarGroups(this.minReqReinfArea_column,...
               this.maxReqReinfArea_column);
           
           disp('assigning reinforcements to columns..')
           this.assigReinfToColumns();
           
       end
       
       function getBeamsRequiredReinforcements(this,sheet)
           function getBeamReinfData(file,sheet)
              [~,~,rawData] = xlsread(file,sheet);
              firstDataRow = this.nXlsxFileTableUnusedRows + 1;
              [lastDataRow,~] = size(rawData(:,1));
              storyCol  = 1;
              labelCol  = 2;
              uniqIDCol = 3;
              AsTopCol  = 9;
              AsBotCol  = 12;
              AvOnSCol  = 14;
              AlCol     = 16;
              AtOnSCol  = 18;
              beamFirstDataRow  = 1;
              beamFirst2DataRow = 1;
              beamLast2DataRow  = 0;
              beam = this.beams(1);
              this.minReqReinfArea_beam = rawData{firstDataRow,AsTopCol};
              
              for row = firstDataRow:lastDataRow
                  if row ~= 1
                      beamFirstDataRow = rawData{row,uniqIDCol} ~= rawData{row-1,uniqIDCol};
                      if row > 2
                            beamFirst2DataRow = beamFirstDataRow || (rawData{row,uniqIDCol} ~= rawData{row-2,uniqIDCol});
                      end
                  end
                  if row ~= lastDataRow
                      beamLastDataRow  = rawData{row,uniqIDCol}~=rawData{row+1,uniqIDCol};
                      if lastDataRow - row > 1
                          beamLast2DataRow = beamLastDataRow || rawData{row,uniqIDCol}~=rawData{row+2,uniqIDCol};
                      end
                  end
                  
                  rowHasRequiredData = beamFirst2DataRow || beamLast2DataRow;
                  if rowHasRequiredData
                      % each beam has several stations -> several rows of
                      % data in .xlsx file. but we only need first two and
                      % last two stations. so:
                      % the program will start looking for a new beam, only
                      % when it reaches a row that contains data from a new
                      % beam
                      
                      if beamFirstDataRow
                          storyName = rawData{row,storyCol};
                          label = rawData{row,labelCol};
                          beam = this.findByStoryNameAndLabel(storyName,label,'beam');
                      end
                      
                      % assigning maximum required reinforcement to beam in
                      % both main and 25% design files
                      if beam.isOnOpenseesFrame
                          AsTop_req = rawData{row,AsTopCol};
                          if AsTop_req > beam.AsTop_req
                              beam.AsTop_req = AsTop_req;
                              beam.AstTop_req = AsTop_req;
                          end

                          AsBot_req = rawData{row,AsBotCol};
                          if AsBot_req > beam.AsBot_req
                              beam.AsBot_req = AsBot_req;
                              beam.AstBot_req = AsBot_req;
                          end

                          AvOnS_req = rawData{row,AvOnSCol};
                          if AvOnS_req > beam.AvOnS_req
                              beam.AvOnS_req = AvOnS_req;
                          end

                          Al_req    = rawData{row,AlCol};
                          if Al_req > beam.Al_req
                              beam.Al_req = Al_req;
                          end

                          AtOnS_req = rawData{row,AtOnSCol};
                          if AtOnS_req > beam.AtOnS_req
                              beam.AtOnS_req = AtOnS_req;
                          end

                      end
                  end
              end
           end
           
           getBeamReinfData(this.xlsxFilePath,sheet);
           getBeamReinfData(this.xlsFilePath_25prcnt,sheet);
           
       end
       
       function getColumnsRequiredReinforcements(this,sheet)
           function getColumnReinfData(file,sheet)
              [~,~,rawData] = xlsread(file,sheet);
              firstDataRow = this.nXlsxFileTableUnusedRows + 1;
              [lastDataRow,~] = size(rawData(:,1));
              storyCol  = 1;
              labelCol  = 2;
              uniqIDCol = 3;
              AsCol        = 11;
              AvOnSMajCol  = 15;
              AvOnSMinCol  = 17;
              columnFirstDataRow  = 1;
%               columnFirst2DataRow = 1;
%               columnLast2DataRow  = 0;
              column = this.columns(1);
              this.minReqReinfArea_column = rawData{firstDataRow,AsCol};
              
              for row = firstDataRow:lastDataRow
                  if row ~= 1
                      columnFirstDataRow = rawData{row,uniqIDCol} ~= rawData{row-1,uniqIDCol};
%                       if row > 2
%                             columnFirst2DataRow = columnFirstDataRow || (rawData{row,uniqIDCol} ~= rawData{row-2,uniqIDCol});
%                       end
                  end
                  if row ~= lastDataRow
                      columnLastDataRow  = rawData{row,uniqIDCol}~= rawData{row+1,uniqIDCol};
%                       if lastDataRow - row > 1
%                           columnLast2DataRow = columnLastDataRow || rawData{row,uniqIDCol}~=rawData{row+2,uniqIDCol};
%                       end
                  end
                  
                  rowHasRequiredData = columnFirstDataRow|| columnLastDataRow;
                  if rowHasRequiredData
                      % each column has several stations -> several rows of
                      % data in .xlsx file. but we only need first and last
                      % stations. so:
                      % the program will start looking for a new column,
                      % only when it reaches a row that contains data from
                      % a new column
                      
                      if columnFirstDataRow
                          storyName = rawData{row,storyCol};
                          label = rawData{row,labelCol};
                          column = this.findByStoryNameAndLabel(storyName,label,'column');
                      end
                      
                      % assigning maximum required reinforcement to column in
                      % both main and 25% design files
                      if column.isOnOpenseesFrame && column.isRC
                          
                          As_req = rawData{row,AsCol};
                          this.reviseColumnMaxMinReqAs(As_req);
                          if As_req > column.As_req
                              column.As_req = As_req;
                          end

                          AvOnS_req = max(rawData{row,AvOnSMajCol},rawData{row,AvOnSMinCol});
                          this.reviseMaxReqAvOnS(AvOnS_req);
                          if AvOnS_req > column.AvOnS_req
                              column.AvOnS_req = AvOnS_req;
                          end
                          
                      end
                  end
              end
           end
           
           getColumnReinfData(this.xlsxFilePath,sheet);
           getColumnReinfData(this.xlsFilePath_25prcnt,sheet);
           
       end
       
       function reviseBeamMaxMinReqAs(this,requiredA)
          if requiredA > this.maxReqReinfArea_beam
              this.maxReqReinfArea_beam  = requiredA;
          elseif requiredA < this.minReqReinfArea_beam
              this.minReqReinfArea_beam = requiredA;
          end
       end
       
       function reviseColumnMaxMinReqAs(this,requiredA)
          if requiredA > this.maxReqReinfArea_column
              this.maxReqReinfArea_column  = requiredA;
          elseif requiredA < this.minReqReinfArea_column
              this.minReqReinfArea_column = requiredA;
          end
       end
       
       function reviseMaxReqAvOnS(this,reqAvOnS)
          if reqAvOnS > this.maxReqAvOnS
              this.maxReqAvOnS  = reqAvOnS;
          end
       end
       
       function addTorsionalReinforcement(this)
           for b = 1:this.nBeams
               beam = this.beams(b);
               if beam.isOnOpenseesFrame
                   this.beams(b).addTorsionalReinforcement();
                   this.reviseBeamMaxMinReqAs(beam.AsTop_req);
                   this.reviseBeamMaxMinReqAs(beam.AstTop_req);
                   this.reviseBeamMaxMinReqAs(beam.AsBot_req);
                   this.reviseBeamMaxMinReqAs(beam.AstBot_req);
                   this.reviseMaxReqAvOnS(beam.AtvOnS_req);
               end
           end
       end
       
       function sortedReinfs = sortBeamsLongReinfs(this,nonBundledGrps,bundledGrps)
           [~,nNonBundGrps] = size(nonBundledGrps);
           [~,nBundGrps]    = size(bundledGrps);
           nTotGrps = nNonBundGrps + nBundGrps;
           sortedReinfs = cell(1,nTotGrps);
           maxNreqTransBars = bundledGrps{nBundGrps}.nReqTransBars;
           indx = 1;
           for n = 2:maxNreqTransBars
               nonBundGrps = this.findGrpsWithNreqTransBars(nonBundledGrps,n);
               bundGrps    = this.findGrpsWithNreqTransBars(bundledGrps,n);
               nonBundGrps = this.sortlongBarGrpsBasedOnAs(nonBundGrps);
               bundGrps    = this.sortlongBarGrpsBasedOnAs(bundGrps);
               [~,nNonBundGrps]  = size(nonBundGrps);
               [~,nBundGrps]     = size(bundGrps);
               sortedReinfs(indx:(indx-1)+nNonBundGrps) = nonBundGrps;
               indx = nNonBundGrps + indx;
               sortedReinfs(indx:(indx-1)+ nBundGrps) = bundGrps;
               indx = indx + nBundGrps;
           end
           
       end
       
       function matchingGrps = findGrpsWithNreqTransBars(~,longBarGrps,nTransBars)
           [~,nGrps] = size(longBarGrps);
           matchingGrps = cell(1,nGrps);
           indx = 1;
           for g = 1:nGrps
               transBarMatches = longBarGrps{g}.nReqTransBars == nTransBars;
               if transBarMatches
                   matchingGrps{indx} = longBarGrps{g};
                   indx = indx + 1;
               end
           end
           matchingGrps = Domain.removeEmptyCellMembers(matchingGrps);
       end
       
       function sortedCell = sortlongBarGrpsBasedOnAs(~,longBarGrps)
           % sorts the cell in an ascending manner
           [~,nGrps] = size(longBarGrps);
           for i = 1:nGrps 
               for j = i:nGrps 
                   if longBarGrps{i}.As > longBarGrps{j}.As
                       temp = longBarGrps{i};
                       longBarGrps{i} = longBarGrps{j};
                       longBarGrps{j} = temp;
                   end
               end
           end
           sortedCell = longBarGrps;
       end
       
       function assignReinfToBeams(this)
%            indx = 1;
           for b = 1:this.nBeams
               beam = this.beams(b);
               if beam.isOnOpenseesFrame
%                    if strcmp(beam.storyName,'Story -1') && strcmp(beam.nonUniqueID_etabs,'B13')
%                        
%                    end
                   [topAsCands,botAsCands] = this.getBeamLongReinfCandidates(beam);
                   [transReinf,topBarGrp] = this.getTransAndTopReinfs(beam,topAsCands);
                   botAsCands = this.sortlongBarGrpsBasedOnAs(botAsCands);
                   botBarGrp = this.getBotLongBar(botAsCands,transReinf.nTransBars);     
%                    disp('************************************')
%                    disp(indx)
%                    disp(topBarGrp)
%                    disp(topBarGrp.barsDiamArr)
%                    disp(botBarGrp)
%                    disp(transReinf)
%                    indx = indx + 1;
                    beam.topLongReinf = topBarGrp;
                    beam.botLongReinf = botBarGrp;
                    beam.transReinf   = transReinf;
%                     beam.AsTop = topBarGrp.As;
%                     beam.AsBot = botBarGrp.As;
%                     beam.AvOnS = transReinf.AvOnS;
                    beam.calcRhoSh();
                    beam.calcCap2DemRatios();
                    beam.calcAWeb(this.acceptableErr);
%                    disp(beam.AsTop_ConD)
%                    disp(beam.AsBot_ConD)
%                    disp(beam.AvOnS_ConD)
                   
               end
           end
       end
       
       function botLongBarGrp = getBotLongBar(~,botBarGrpCands,nTransBars)
           [~,nBotGrpCands] = size(botBarGrpCands);
           
           for g = 1:nBotGrpCands 
               grp = botBarGrpCands{g};
               groupHasSameNOtrnsBars = nTransBars == grp.nReqTransBars;
               if groupHasSameNOtrnsBars
                   botLongBarGrp = grp;
                   return
               end
           end
           botLongBarGrp = [];
       end
       
       function [topAsCandidates,botAsCandidates] = getBeamLongReinfCandidates(this,beam)
           function [topAsCandidates,botAsCandidates] = getAreaSufficientCandidates(longReinfs)

               [~,nDomainLongReinfs] = size(longReinfs);
               topAsCandidates = cell(1,nDomainLongReinfs);
               botAsCandidates = cell(1,nDomainLongReinfs);

               tIndx = 0;
               bIndx = 0;
               for lr = 1:nDomainLongReinfs
                   isTopAsCandidate = ...
                       longReinfs{lr}.calcCap2DemRatio(beam.AstTop_req) > (1 - this.acceptableErr)...
                       && longReinfs{lr}.calcBar2BarClrDist(beam.section) >...
                       (1 - this.acceptableErr)*this.minLongBarDistance;

                   isBotAsCandidate = ...
                       longReinfs{lr}.calcCap2DemRatio(beam.AstBot_req) > (1 - this.acceptableErr)...
                       && longReinfs{lr}.calcBar2BarClrDist(beam.section) >...
                       (1 - this.acceptableErr)*this.minLongBarDistance;

                   if isTopAsCandidate
                       tIndx = tIndx + 1;
                       topAsCandidates{tIndx} = longReinfs{lr};
                   end
                   if isBotAsCandidate
                       bIndx = bIndx + 1;
                       botAsCandidates{bIndx} = longReinfs{lr};
                   end               
               end
               topAsCandidates = Domain.removeEmptyCellMembers(topAsCandidates);
               botAsCandidates = Domain.removeEmptyCellMembers(botAsCandidates);
           end           
           longReinfs = this.beamsLongReinforcements;
           [topAsCandidates,botAsCandidates] = getAreaSufficientCandidates(longReinfs); 
           topAsCandidates = this.chkBar2BarDistProvisions(topAsCandidates,beam.section);
           botAsCandidates = this.chkBar2BarDistProvisions(botAsCandidates,beam.section);
           
           if isempty(topAsCandidates)
               disp(beam)
               warndlg('no sufficient bar group found for top reinforcement of the beam')
           elseif isempty(botAsCandidates)
               disp(beam)
               warndlg('no sufficient bar group found for top reinforcement of the beam')
           end
       end
       
       function chkdCandidates = chkBar2BarDistProvisions(this,unchkdCands,section)
           [~,nCands] = size(unchkdCands);
           chkdCandidates = cell(1,nCands);
           indx = 1;
           for c = 1:nCands
               longBarGrp = unchkdCands{c};
               bar2barClrDistLessThan_150mm = ...
                   longBarGrp.calcBar2BarClrDist(section) < 150*(1+this.acceptableErr);
               alternateBarsDist = 2*longBarGrp.calcBarsC2Cdistance(section);
               alterBarsDistLessThan_350mm = ...
                   alternateBarsDist < 350*(1+this.acceptableErr);
               barGrpIsQualified = ...
                   bar2barClrDistLessThan_150mm && alterBarsDistLessThan_350mm;
               if barGrpIsQualified
                   chkdCandidates{indx} = longBarGrp;
                   indx = indx + 1;
               end
           end
           chkdCandidates = Domain.removeEmptyCellMembers(chkdCandidates);
       end       
       
       function [transReinf,topBarGrp] = getTransAndTopReinfs(this,beam,longBarCands)
%            transReinfCands = this.getTransReinfCandidates(beam,topLongBarGrp);
           transReinfs = this.transReinforcements;
           [~,nDomainTransReinfs] = size(transReinfs);
           transReinfsCandidates = cell(1,nDomainTransReinfs);
           indx = 0;
           for tr = 1:nDomainTransReinfs
               hasSufficeintAvOnS = ...
                   transReinfs{tr}.calcCap2DemRatio(beam.AtvOnS_req) > (1 - this.acceptableErr);
               if hasSufficeintAvOnS
                   indx = indx + 1;
                   transReinfsCandidates{indx} = transReinfs{tr};
               end
           end
           transReinfsCandidates = Domain.removeEmptyCellMembers(transReinfsCandidates);
           [~,nLongBarCands] = size(longBarCands);
           for c = 1:nLongBarCands
               longBarGrp = longBarCands{c};
               transReinfsCandidates = ...
                   this.chkSmaxProvision(transReinfsCandidates,beam.section.d,longBarGrp);
               transReinfsCandidates = Domain.removeEmptyCellMembers(transReinfsCandidates);
               transReinf = this.getTransReinf(transReinfsCandidates,longBarGrp);
               transReinfWasFound = ~isempty(transReinf);
               if transReinfWasFound
                   topBarGrp = longBarGrp;
                   return
               end
           end
       end
       
       function transReinforcement = getTransReinf(~,transReinfCands,longBarGrp)
           [~,nTrnsRenfsCnds] = size(transReinfCands);
           for tr = 1:nTrnsRenfsCnds
               trnsRenf = transReinfCands{tr};
               haveSameNOtransBars = ...
                   longBarGrp.nReqTransBars == trnsRenf.nTransBars;
               if haveSameNOtransBars
                   transReinforcement = transReinfCands{tr};
                   return
               end
           end
           transReinforcement = [];
       end       
       
       function qualifiedTransReinfs = chkSmaxProvision(this,transReinfs,d,longBarGrp)
           sMax = min(d/4,6*longBarGrp.db);
           [~,nTransReinfs] = size(transReinfs);
           qualifiedTransReinfs = cell(1,nTransReinfs);
           indx = 1;
           for tr = 1:nTransReinfs
               transReinf = transReinfs{tr};
               if transReinf.spacing < sMax * (1-this.acceptableErr)
                   qualifiedTransReinfs{indx} = transReinf;
                   indx = indx + 1;
               end
           end
           qualifiedTransReinfs = Domain.removeEmptyCellMembers(qualifiedTransReinfs);
       end
       
       function getColumnsForces(this)
           sheet = 'Column Forces';
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           firstDataRow = this.nXlsxFileTableUnusedRows + 1;
           [lastDataRow,~] = size(rawData(:,1));
           storyCol   = 1;
           labelCol   = 2;
           comboCol   = 4;
           stationCol = 5;
           forceCol   = 6;
           femaComboName = 'FemaCombo';
           for row = firstDataRow:lastDataRow
               rightCombo = strcmp(rawData{row,comboCol},femaComboName);
               if rightCombo
                   rightStation = rawData{row,stationCol} == 0;
                   if rightStation
                       story = rawData{row,storyCol};
                       label = rawData{row,labelCol};
                       axialForce = rawData{row,forceCol};
                       column = this.findByStoryNameAndLabel(story,label,'column');
                       if column.isOnOpenseesFrame
                           column.P = axialForce;
%                            disp('***************************')
%                            disp(column)
                       end
                   end
               end
           end
       end
       
       function assigReinfToColumns(this)
%            ColumnLongReinf.createColumnsLongBarGrps();
           for c = 1:this.nColumns
               column = this.columns(c);
               if column.isOnOpenseesFrame && column.isRC
                   [longReinf,h_x]  = this.getColLongReinf(column);
                   transReinf   = this.getColTransReinf(column,longReinf,h_x);
                   column.longReinf = longReinf;
                   column.transReinf = transReinf;
%                    column.As    = longReinf.As;
%                    column.AvOnS = transReinf.AvOnS;
                   column.calcCap2DemRatios();
%                    this.displayColReinfData(column,longReinf,transReinf);
                   column.calcRhoSh(); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                   column.calcAWeb();
               end
           end
       end
       
       function displayColReinfData(~,column)
           sprintf('\n*********************************')
           fprintf('As_req    = %d\n',column.As_req)
           fprintf('As        = %d\n',column.longReinf.As)
           fprintf('As C/D    = %d\n',round(column.As_ConD,2))
           disp(longReinf.sideBarsDiamArr)
           
           fprintf('AvOnS_req = %d\n',column.AvOnS_req)
           fprintf('AvOnS     = %d\n',column.transReinf.AvOnS)
           fprintf('Av/s C/D  = %d\n',round(column.AvOnS_ConD,2))
           fprintf('spacing is %d mm\n',column.transReinf.spacing)
       end
       
       function transReinf = getColTransReinf(this,col,longReinf,h_x)
           nReqTransBars = longReinf.nReqTransBars;
           AvOnSReq = col.AvOnS_req;
           [~,nTransReinfs] = size(this.transReinforcements);
           for tr = 1:nTransReinfs
               transReinf = this.transReinforcements{tr};
               AvOnSisOK = transReinf.AvOnS >= AvOnSReq * (1 - this.acceptableErr);
               nReqTransBarsIsOK = (transReinf.nTransBars == nReqTransBars);
               sMaxIsOK = transReinf.chkColSmax(longReinf,h_x,col.section,this.acceptableErr);
               allProvsSatisfied = AvOnSisOK && nReqTransBarsIsOK && sMaxIsOK;
               if allProvsSatisfied
                   return
               end
           end
       end
       
       function [longReinf,h_x] = getColLongReinf(this,col)
%            disp('****************************************')
%            disp(col.storyName)
%            disp(col.nonUniqueID_etabs)           
           Ag      = col.section.Area; %mm2
           fPrimeC = this.concMaterial.strength; % MPa
           aciConditionIsMet = ...
               abs(col.P * (this.KN2Nfactor)) > 0.3 * Ag * fPrimeC;
%            disp(aciConditionIsMet)         
           allLongBarsNeedTransBar = ...
               this.chkTransBarArngmntBasedOnColumnsP(aciConditionIsMet);
           % h_x is an ACI parameter, determining the max distance
           % between two longitudinal bars with supporting
           % transverse reinforcements.
           h_x = ...
               this.chkLongBarsMaxDistBasedOnP(aciConditionIsMet);
           longReinfCands = this.getAreaSufficentLongReinfs(col);
           longReinfCands = this.chkLongBar2BarMaxDistance...
               (longReinfCands,h_x,col.section,allLongBarsNeedTransBar);

           
           longReinf  = ...
               this.chkMinBar2BarDist(longReinfCands,col.section);
           longReinf.reviseNreqTransBars(allLongBarsNeedTransBar);
       end
       
       function cand = chkMinBar2BarDist(this,longReinfCands,section)
           [~,nLongReinfs] = size(longReinfCands);
           for c = 1:nLongReinfs
               longReinf = longReinfCands{c};
               bar2barDistIsOK = longReinf.calcBar2BarDistance(section)...
                   >= this.minLongBarDistance * (1 - this.acceptableErr);
               if bar2barDistIsOK
                   cand = longReinf;
                   return
               end
           end
       end
       
       function cands =  chkLongBar2BarMaxDistance...
               (this, longReinfCands, h_x, section,allLongBarsNeedTransBar)
           [~,nCands] = size(longReinfCands);
           cands = cell(1,nCands);
           indx = 1;
           for c = 1:nCands
               longReinf = longReinfCands{c};
               barsC2CdistIsOK = longReinf.calcBarsC2Cdistance(section,allLongBarsNeedTransBar) ...
                   <= h_x * (1 + this.acceptableErr);
               if barsC2CdistIsOK
                   cands{indx} = longReinf;
                   indx = indx + 1;
               end
           end
           
           cands = Domain.removeEmptyCellMembers(cands);
       end
       
       function longReinfCands = getAreaSufficentLongReinfs(this,col)
           [~,nLongReinfs] = size(this.columnsLongReinforcements);
           longReinfCands  = cell(1,nLongReinfs);
           AsReq = col.As_req;
           indx = 1;
           for lr = 1:nLongReinfs
               longReinf = this.columnsLongReinforcements{lr};
               if longReinf.As >= AsReq * (1 - this.acceptableErr)
                   longReinfCands{indx} = longReinf;
                   indx = indx + 1;
               end
           end
           longReinfCands = Domain.removeEmptyCellMembers(longReinfCands);
       end
       
       
       function allLongBarsNeedTransBar = chkTransBarArngmntBasedOnColumnsP(~,aciConditionIsMet)
          aciRequiresAllLongBars2haveTransBar = aciConditionIsMet;
          if aciRequiresAllLongBars2haveTransBar
              allLongBarsNeedTransBar = 1;
          else
              allLongBarsNeedTransBar = 0;
          end
          
       end
       
       function h_x = chkLongBarsMaxDistBasedOnP(~,aciConditionIsMet)
          % if condition is met, the max distance between long. bars
          % with supporting trans. bars is decreased from 350 mm to 200.
          if aciConditionIsMet
              h_x = 200;
          else
              h_x = 350;
          end
          
       end
       
       
       %% calcualte beams/columns params for nonlinear models
       
       function creatNonlinearFrmElmnts(this,HYSTERETIC_MODEL_FLAG)
           disp('creating frame elements'' hysteretic materials..')
           this.reviseColumnsDepthParams();
           this.reviseBeamDepthParams();
           this.createHystereticModelParams(HYSTERETIC_MODEL_FLAG);
%            this.assignPeakOrientedMaterialsToJoint2Dnodes();
       end
       
       function createHystereticModelParams(this,HYSTERETIC_MODEL_FLAG)
           fc = this.concMaterial.strength_exp;
           Ec = this.concMaterial.E_exp;
           fy = this.longBarMaterial.strength_exp;
           Es = this.longBarMaterial.E_exp;
           
           for c = 1:this.nColumns
               column = this.columns(c);
               storyName = column.storyName;
               isOnBasement = this.isOnBasementStories(storyName);
               if column.isOnOpenseesFrame && column.isRC
                   colTag = column.elasticElmnt.openseesTag;
                   column.calcHystereticModelParams(colTag,fc,Ec,fy,Es,HYSTERETIC_MODEL_FLAG,isOnBasement);
%                    disp('**************************************')
%                    disp(column.hystereticMat)
               end
           end
           
           for b = 1:this.nBeams
               beam = this.beams(b);
               storyName = beam.storyName;
               isOnBasement = this.isOnBasementStories(storyName);
               if beam.isOnOpenseesFrame
                   beamTag = beam.elasticElmnt.openseesTag;
                   beam.calcHystereticModelParams(beamTag,fc,Ec,fy,Es,HYSTERETIC_MODEL_FLAG,isOnBasement); 
%                    disp('**************************************')
%                    disp(beam.hystereticMat)
               end
           end
       end
       
       function isOnBasement = isOnBasementStories(this,frmElmntStry)
           isOnBasement = 0;
           for i = 1:this.nBasementLevels
               storyName = this.basementLevels{i};
               if strcmp(storyName,frmElmntStry)
                  isOnBasement = 1;
               end
           end
       end       
       
       function reviseColumnsDepthParams(this)
           for c = 1:this.nColumns
               col = this.columns(c);
               if col.isOnOpenseesFrame && col.isRC
                   col.reviseDepthAndCalcDprime();
               end
           end
       end
       
       function reviseBeamDepthParams(this)
           for b = 1:this.nBeams
              beam = this.beams(b);
              if beam.isOnOpenseesFrame
                 beam.calcDprime(); 
              end
           end
       end
       
       %% revise Zareian ELements moments of inertia according to ATC factors
       function reviseZareianFrmELmntsI(this)
           for b = 1:this.nBeams
               beam = this.beams(b);
               if beam.isOnOpenseesFrame
                   beam.elasticElmnt.Iz = beam.elasticElmnt.Iz * ...
                       beam.ImodFac;
               end
           end
           
           for c = 1:this.nColumns
               column = this.columns(c);
               if column.isOnOpenseesFrame
                   if column.isRC
                       column.elasticElmnt.Iz = column.elasticElmnt.Iz * ...
                           column.ImodFac;
                   end
               end
           end
       end
       
       
       %% create joint2D elements
       
       function completeJointsData(this)
           disp('creating joint2D elements..')
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
               isOnLowermostLvl = strcmp(joint.storyName,this.lowermostLevel);
               if joint.isOnOpenseesFrames
                   joint.hystereticMatsTags = this.getJointNodesHystMats(joint);
                   joint.generateJoint2dTag();
                   if isOnLowermostLvl
                       joint.createSupprotZeroLnegths();
                   end
%                    disp('*********************************************')
%                    disp(joint)
               end
           end
       end         
       
       function jointNodesHystMats = getJointNodesHystMats(this,joint)
           jointNodesHystMats = cell(1,4);
           for n = 1:4
               jointHasFrmElmntOnThisSide = ...
                   joint.XZcnnctdFrmObjctsUniqIDs(n) ~= 0;
               if jointHasFrmElmntOnThisSide
                   frmElmntUniqID = joint.XZcnnctdFrmObjctsUniqIDs(n);
                   frmElmnt =  this.findByEtabsUniqueID(frmElmntUniqID);
                   frmElmntIsSteelColumn = 0;
                   if strcmp(frmElmnt.section.elmntType,'column')
                      if ~frmElmnt.isRC
                          frmElmntIsSteelColumn = 1;
                      end
                   end
                   if ~frmElmntIsSteelColumn
                       jointNodesHystMats{n} = frmElmnt.hystereticMat.tag;
                   else
                       jointNodesHystMats{n} = '$HingedMatTag';
                   end
               else
                   jointNodesHystMats{n} = '0';
%                    hasFrmCnctrOnThisSide = this.hasFramesConnectorOnThisSide(joint,n);
%                    if hasFrmCnctrOnThisSide
%                        jointNodesHystMats{n} = '$HingedMatTag';
%                    else
%                        jointNodesHystMats{n} = '0';
%                    end
               end
               
           end
       end
       
       function hasFrmCnctrOnThisSide = hasFramesConnectorOnThisSide(this,joint,positionCode)
           if joint.isOnOpenseesFrames && ~joint.isOn2ndOpenseesFrame
               storyJoints = this.getStoryJoints(joint.storyName,1);
               nJoints = length(storyJoints);
               rightJoint = strcmp(storyJoints{nJoints}.opnssTag,joint.opnssTag);
               rightNode = positionCode == 1;
           elseif joint.isOn2ndOpenseesFrame
               storyJoints = this.getStoryJoints(joint.storyName,2);
               rightJoint = strcmp(storyJoints{1}.opnssTag,joint.opnssTag);
               rightNode = positionCode == 3;
           end
           hasFrmCnctrOnThisSide = rightJoint && rightNode;
       end
       
       %% assigning mass to nodes
       function assignMassToNodes(this,SUBBASE_ZERO_WEIGHT)
           disp('assigning mass to nodes..')
           this.getStoriesMass(SUBBASE_ZERO_WEIGHT);
           this.getStoriesShear();
           this.calcCol2storyStfnRatios();
           this.assignMass();
       end
       
       function assignMass(this)
          for c = 1:this.nColumns
              column = this.columns(c);
              
              if column.isOnOpenseesFrame
                  isOnBasement = this.isStoryBasement(column.storyName);
                  if ~isOnBasement
                      storyMass = this.getStoryMass(column.storyName);
                      nodeMass = column.col2StryStfRatio * storyMass;
                      column.jJoint_etabs.openseesNodes{2}.massX = nodeMass;
                      column.jJoint_etabs.openseesNodes{2}.massY = nodeMass;                      
                  else
                      column.jJoint_etabs.openseesNodes{2}.massX = 0;
                      column.jJoint_etabs.openseesNodes{2}.massY = 0;                      
                  end

              end
          end
       end
       
       
       function storyMass = getStoryMass(this,storyName)
           storyIndx = 0;
           for s = 1:this.nStories
               thatsTheStory = (strcmp(storyName,this.storiesTopDown{1,s}));
               if thatsTheStory
                   storyIndx = s;
               end
           end
           storyMass = this.storiesMass(storyIndx);
       end
       
       function calcCol2storyStfnRatios(this)
           sheet = 'Column Forces';
           [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
           firstDataRow = this.nXlsxFileTableUnusedRows + 1;
           [lastDataRow,~] = size(rawData(:,1));
           storyCol    = 1;
           labelCol    = 2;
           loadCaseCol = 4;
           targetLoadCase    = 'Ex';
           stationCol  = 5;
           targetStation = 0;
           shearCol    = 7;
           for row = firstDataRow:lastDataRow
               loadCaseOK = strcmp(targetLoadCase,rawData{row,loadCaseCol});
               if loadCaseOK
                  shearStationOK = (targetStation == rawData{row,stationCol});
                  if shearStationOK
                      story = rawData{row,storyCol};
                      label = rawData{row,labelCol};
                      column = this.findByStoryNameAndLabel(story,label,'column');
                      if column.isOnOpenseesFrame
                          storyShear = this.getStoryShear(story);
                          columnShear = abs(rawData{row,shearCol});
                          disp('**********************************')
                          disp(columnShear);
                          column.col2StryStfRatio = columnShear/storyShear; 
                      end
                  end
               end
           end
       end
       
       function storyShear = getStoryShear(this,storyName)
          storyIndx = 0;
          for s = 1:this.nStories
              thatsTheStory = strcmp(storyName,this.storiesTopDown{1,s});
              if thatsTheStory
                  storyIndx = s;
              end
          end
          storyShear = this.storiesShear(storyIndx);
       end
       
       function getStoriesShear(this)
           this.storiesShear = zeros(1,this.nStories);
           sheet = 'Story Forces';
           [~,~,rawData]    = xlsread(this.xlsxFilePath,sheet);
           firstDataRow     = this.nXlsxFileTableUnusedRows + 1;
           [lastDataRow,~]  = size(rawData(:,1));
           loadCaseCol      = 2;
           targetLoadCase   = 'Ex';
           forceLocationCol = 3;
           forceLocation    = 'Bottom';
           shearCol         = 5;
           indx = 1;
           for row = firstDataRow:lastDataRow
               loadCaseOK = strcmp(targetLoadCase,rawData{row,loadCaseCol});
               forceLocationOK = strcmp(forceLocation,rawData{row,forceLocationCol});
               if loadCaseOK && forceLocationOK
                   this.storiesShear(indx) = abs(rawData{row,shearCol});
                   indx = indx + 1;
               end
           end
           
       end
       
       function getStoriesMass(this,SUBBASE_ZERO_WEIGHT)
           % stores stories massed in a vector. stories order is top down
           % according to the etabs-exported excel file data arrangement
           this.storiesMass = zeros(1,this.nStories);
           this.storiesMass_pushover = zeros(1,this.nStories);
           sheet = 'Mass Summary by Story';
           [~,~,rawData] = xlsread(this.xlsFilePath_mass,sheet);
           firstDataRow  = this.nXlsxFileTableUnusedRows + 1;
           nStoriesDataRow = firstDataRow + this.nStories - 1; % -1 is bcoz
           % we don't need the mass of the level 'Base'
           storyNameCol = 1;
           massCol = 2;
           indx = 1;
           buildingW = 0;
           g = 9.81;
           
           for i = firstDataRow:nStoriesDataRow
               storyName = rawData{i,storyNameCol};
               storyIsOnBasement = this.isStoryBasement(storyName);
               storyMass = rawData{i,massCol};
               this.storiesMass_pushover(indx) = storyMass;
               if SUBBASE_ZERO_WEIGHT && storyIsOnBasement
                   this.storiesMass(indx) = 0;
                   indx = indx + 1;
               else
                   this.storiesMass(indx) = storyMass;
                   indx = indx + 1;
                   this.buildingWeight_upperLevels = (storyMass * g) + ...
                       this.buildingWeight_upperLevels;
               end
               buildingW = buildingW + (storyMass * g);
           end
           this.buildingWeight = buildingW;
       end
       
       function storyIsOnBasement = isStoryBasement(this,storyName)
           storyIsOnBasement = 0;
           for bs = 1:this.nBasementLevels-1
               if strcmp(storyName,this.basementLevels{bs})
                   storyIsOnBasement = 1;
                   return
               end
           end
       end
       
       %% applying uniform loads (tributary + external walls) to beams
       
      
       function addGravityLoadToBeams(this)
           disp('assigning loads to beams..')
%            this.getSlabSections();
           this.getWallSections();
%            this.getStoriesSlabsTh();
           this.getBasementWallsTh();
           this.assignOccupanciesToStories();
           this.assignLoadToBeams();
       end
       
       function assignLoadToBeams(this)
          for b = 1:this.nBeams
             beam = this.beams(b);
             if beam.isOnOpenseesFrame
                isOnOuterFrame = this.isBeamOnOuterFrame(beam); 
                if isOnOuterFrame
                    this.AssignBeamUniformLoad(beam,isOnOuterFrame);
                else
                    this.AssignBeamUniformLoad(beam,isOnOuterFrame);
                end
             end
          end
       end
       
       function AssignBeamUniformLoad(this,beam,beamIsOnOuterFrame)
           perpBayLength = beam.length * this.mm2mFactor;
           [storyUnifLoad,extWallLoad] = this.getStoryLoads(beam.storyName);
           if beamIsOnOuterFrame
               tributaryLength = 0.5 * perpBayLength;
           else
               tributaryLength = perpBayLength;
               extWallLoad = 0;
           end
           beam.elasticElmnt.uniformLoad = ...
               tributaryLength * storyUnifLoad + extWallLoad;
       end
       
       function [unifLoad,extWallLoad] = getStoryLoads(this,storyName)
           storyIndx = find(strncmp(storyName,this.storiesTopDown,length(storyName)));
           occupancy = this.storiesOccupancies(storyIndx);
           unifLoad = 0;
           extWallLoad = 0;
           loads = Domain.occupanciesUniformLoads();
           
           for i = 1:length(loads);
               if strcmp(loads{i}.occupancy,occupancy)
                   unifLoad = loads{i}.load;
                   extWallLoad = loads{i}.extWallUnifLoad;
               end
           end
       end
       
       function isOnOuterFrame = isBeamOnOuterFrame(this,beam)
           frameID = beam.iJoint_etabs.yFrameID;
           outerFrame1 = this.yGridIDs(1);
           outerFrame2 = this.yGridIDs(this.nYgrids);
           if frameID == outerFrame1 || frameID == outerFrame2
               isOnOuterFrame = 1;
           else
               isOnOuterFrame = 0;
           end
       end
       
       function assignOccupanciesToStories(this)
           this.storiesOccupancies = cell(1,this.nStories);
           this.storiesOccupancies{1} = 'Roof';
           belowLobby = 0;
           indx = 2;
           for s = 2:this.nStories
               if ~belowLobby
                  residentialOccupancy = ~strcmp('Lobby',this.storiesTopDown{s-1}) && ~belowLobby;
                  if residentialOccupancy
                      this.storiesOccupancies{indx} = 'Residential';
                      indx = indx + 1;
                  elseif strcmp('Lobby',this.storiesTopDown{s-1})
                      this.storiesOccupancies{indx} = 'Lobby';
                      indx = indx + 1;
                      belowLobby = 1;
                  end
               else
                   this.storiesOccupancies{indx} = 'Basement';
                   indx = indx + 1;                   
               end
           end
       end
       
       function getBasementWallsTh(this)
          this.basementStoriesWallTh = zeros(1,this.nBasementLevels-1);
          sheet = 'Shell Assignments - Sections';
          [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
          firstDataRow = this.nXlsxFileTableUnusedRows + 1;
          [lastDataRow,~] = size(rawData(:,1));
          storyCol = 1;
          secCol   = 4;
          indx = 1;
          for row = firstDataRow:lastDataRow 
              story = rawData{row,storyCol};
              wallSec = rawData{row,secCol};
              newStoryWallData = ~strcmp(story,rawData{row+1,storyCol});
              if row == firstDataRow || newStoryWallData
                  this.basementStoriesWallTh(indx) = this.getWallSectionThickness(wallSec);
                  indx = indx + 1;
                  if indx > this.nBasementLevels - 1;
                      return
                  end
              end
          end
          
       end
       
       function wallThickness = getWallSectionThickness(this,wallSection)
           nWalls = length(this.walls);
           for w = 1:nWalls 
               if strcmp(wallSection,this.walls{w}.name)
                   wallThickness = this.walls{w}.t;
                   return
               end
           end
       end
       
       function getWallSections(this)
          sheet = 'Shell Sections - Wall';
          [~,~,rawData] = xlsread(this.xlsxFilePath,sheet);
          firstDataRow = this.nXlsxFileTableUnusedRows + 1;
          [lastDataRow,~] = size(rawData(:,1));
          nWallSections = firstDataRow - lastDataRow + 1;
          this.walls = cell(1,nWallSections);
          nameCol = 1;
          thicknessCol = 4;
          indx = 1;
          for row = firstDataRow:lastDataRow
              name = rawData{row,nameCol};
              t = rawData{row,thicknessCol};
              this.walls{indx} = struct('name',name,'t',t);
              indx = indx + 1;
          end           
       end
       

       
       %% applying soil at rest pressure to perpendicular basement walls
       function addSoilLoadToPerpendicularWalls(this)
           mm2m = 0.001;
           seismicBaseY = this.zGridOrdnts(this.nBasementLevels);
           P0 = 9430; % unit: N/m2
           for pw = 1:length(this.perpBasementWalls)
              pwall = this.perpBasementWalls{pw};
              [botNodeY,topNodeY] = this.getPerpWallNodesY(pwall);
              wTopDepth = (seismicBaseY - topNodeY) * mm2m;
              wBotDepth = (seismicBaseY - botNodeY) * mm2m;
              wTopPressure = wTopDepth * P0;
              wBotPressure = wBotDepth * P0;
              
              % calculate walls length using its A and I
              % t = sqrt(12*I/A) --> length = A/t --> length = A/(sqrt(12*I/A))
              wlength = pwall.A/sqrt(12*pwall.Iz/pwall.A);
              
              wTopForce = wTopPressure * wlength;
              wBotForce = wBotPressure * wlength;
              
              wAverageForce = 0.5 * (wTopForce+wBotForce);
              loadDirSign = this.getSoilLoadDirectionSign(pwall);
              pwall.soilLoad = loadDirSign * wAverageForce;
           end
       end
       
       function dirSign = getSoilLoadDirectionSign(this,perpWall)
           % returns a "sign" that indicates wether the load pointed
           % towards +Y axis or -Y
           % local +Y is in the global -X (yes -X) direction
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
               if joint.isOnOpenseesFrames
                   if strcmp(joint.perpBasementWall.openseesTag,...
                           perpWall.openseesTag)
                       wallIsOnRight = joint.x_etabs == ...
                           this.xGridOrdnts(this.nXgrids);
                       wallIsOnLeft = joint.x_etabs == ...
                           this.xGridOrdnts(1);
                       if wallIsOnRight
                           dirSign = +1;
                           return
                       elseif wallIsOnLeft
                           dirSign = -1;
                           return
                       else
                          msg = 'in Domain>getSoilLoadDirectionSign(..) perp wall is not on the left nor right';
                          warndl(msg)
                       end
                   end
               end
               
           end
       end
       
       function [botNodeY,topNodeY] = getPerpWallNodesY(this,perpWall)
           botNodeY = 0;
           topNodeY = 0;
           for n = 1:length(this.perpBasementWallsNodes)
               node = this.perpBasementWallsNodes{n};
               if strcmp(node.tag,perpWall.iNode)
                   botNodeY = node.z;
               elseif strcmp(node.tag,perpWall.jNode)
                   topNodeY = node.z;
               end
           end
       end
       
       %% creating basement walls (nodes and [ssp]quad elements of wall)
       
       % this function:
       % 1. generates all the extra nodes needed for the basement walls
       % 2. specifies the master nodes for wall corner nodes
       % 3. specifies the node which must be fixed (the bottom nodes of the
       %    basement wall in the lowermost basement floor)
       function createBasementWalls(this)
           disp('creating basement walls..')
           this.basementWalls = cell(1,100);
           wallIndx = 1;
           concUnitVolWeight = this.concMaterial.unitVolMass * 9.806;
           for bs = 1:this.nBasementLevels-1
               storyName = this.basementLevels(bs);
               wallThickness = this.basementStoriesWallTh(bs);
               lowerStoryName = this.basementLevels(bs+1);
               storyJoints = this.getStoryJoints(storyName,1);
               lowerStoryJoints = this.getStoryJoints(lowerStoryName,1);
               wallsUpperLeftJoints = storyJoints(1:this.nXgrids-1);
               nStoryWalls = length(wallsUpperLeftJoints);
               isOnLowermostStory = (bs == this.nBasementLevels-1);
               for w = 1:nStoryWalls
                   topLeftJoint = storyJoints{w};
                   topRightJoint = storyJoints{w+1};
                   botRightJoint = lowerStoryJoints{w+1};
                   botLeftJoint = lowerStoryJoints{w};
                   
                   basementWall = BasementWall(storyName,wallThickness,topLeftJoint,...
                       topRightJoint,botRightJoint,botLeftJoint);
                   basementWall.generateWallNodes(isOnLowermostStory);
                   
                   basementWall.generateWallQuads(concUnitVolWeight);
                   this.basementWalls{wallIndx} = basementWall;
                   wallIndx = wallIndx + 1;
               end
           end
           this.basementWalls = Domain.removeEmptyCellMembers(this.basementWalls);
       end
       
       function createPerpendicularWalls(this,SUBBASE_ZERO_WEIGHT)
           disp('creating perpendicular basement walls..')
           this.perpBasementWalls = cell(1,2*(this.nBasementLevels-1));
           this.perpBasementWallsNodes = cell(1,length(this.perpBasementWalls)*2);
           wIndx = 1;
           nIndx = 1; %perp. walls node index
           for bs = 1:this.nBasementLevels-1
               
               storyName = this.basementLevels(bs);
               lowerStoryName = this.basementLevels(bs+1);
               wallThickness = this.basementStoriesWallTh(bs);
               stryInFrameJoints = this.getStoryJoints(storyName,1);
               stryOutFrameJoints = this.getStoryJoints(storyName,2);
               lowStryInFrameJoints = this.getStoryJoints(lowerStoryName,1);
               lowStryOutFrameJoints = this.getStoryJoints(lowerStoryName,2);
               
               inFrmPrpWallTopJoints = {stryInFrameJoints{1},...
                   stryInFrameJoints{length(stryInFrameJoints)}};
               inFrmPrpWallBotJoints = {lowStryInFrameJoints{1},...
                   lowStryInFrameJoints{length(lowStryInFrameJoints)}};
               outFrmPrpWallTopJoints = {stryOutFrameJoints{1},...
                   stryOutFrameJoints{length(stryOutFrameJoints)}};
               outFrmPrpWallBotJoints = {lowStryOutFrameJoints{1},...
                   lowStryOutFrameJoints{length(lowStryOutFrameJoints)}};
               
               wallLength = this.basementWalls{bs*3}.length;
               % inFrmPrpWalls is a cell; {leftWall,rightWall}
               % nodes is a cell; {topNode,botNode}
               [inFrmPrpWalls,inFrmPrpWallNodes] = this.createPrpWalls(inFrmPrpWallTopJoints,...
                   inFrmPrpWallBotJoints,wallThickness,wallLength,SUBBASE_ZERO_WEIGHT,1);
               [outFrmPrpWalls,outFrmPrpWallNodes] = this.createPrpWalls(outFrmPrpWallTopJoints,...
                   outFrmPrpWallBotJoints,wallThickness,wallLength,SUBBASE_ZERO_WEIGHT,2);
               
               this.perpBasementWalls(wIndx:wIndx+1) = inFrmPrpWalls;
               this.perpBasementWalls(wIndx+2:wIndx+3) = outFrmPrpWalls;
               wIndx = wIndx + 4;
               
               this.perpBasementWallsNodes(nIndx:nIndx+3) = inFrmPrpWallNodes;
               this.perpBasementWallsNodes(nIndx+4:nIndx+7) = outFrmPrpWallNodes;
               nIndx= nIndx + 8;
           end
           
       end
       
       function [prpWalls,nodes] = createPrpWalls(this,topJoints,botJoints,...
               wallT,wallLength,SUBBASE_ZERO_WEIGHT,positionCode)
           prpWalls = cell(1,2);
           nodes = cell(1,4); % left i/j nodes, right i/j nodes
           lowermostStory = strcmp(botJoints{1}.storyName,this.lowermostLevel);
           
           if positionCode == 1
               prpWallLength = wallLength/2;
           elseif positionCode == 2
               prpWallLength = wallLength;
           else
               disp('domain.createPrpWalls() method wrong argument')
               disp('positionCode can only be either 1 or 2')
           end
           
           I = prpWallLength * wallT^3 / 12;
           A = prpWallLength * wallT;
           E = this.concMaterial.E_exp;
           
           for pw = 1:2
              if pw == 1 % left perp. wall
                 nodesX = topJoints{pw}.openseesNodes{3}.x + ...
                     0.5*wallT;
              else       % right perp. wall
                  nodesX = topJoints{pw}.openseesNodes{1}.x - ...
                      0.5*wallT;
              end
              jNodeTag = this.generatePrpWallNodeTag(topJoints{pw},2);
              
              jNodeY = topJoints{pw}.openseesNodes{4}.z;
              
              iNodeTag = this.generatePrpWallNodeTag(botJoints{pw},1);
              if lowermostStory
                  iNodeY = botJoints{pw}.openseesNodes{4}.z;
              else
                  iNodeY = botJoints{pw}.openseesNodes{2}.z;
              end
              
              prpWallTag = this.generatePrpWallTag(topJoints{pw});
              jNode = OpenseesNode(jNodeTag,nodesX,jNodeY);
              jNode.masterNodeTag = topJoints{pw}.opnssTag;
%               jNode.masterNodeTag = topJoints{pw}.openseesNodes{4}.tag;
              iNode = OpenseesNode(iNodeTag,nodesX,iNodeY);
              if ~lowermostStory
                 iNode.masterNodeTag = botJoints{pw}.opnssTag; 
%                  iNode.masterNodeTag = botJoints{pw}.openseesNodes{2}.tag; 
              end
              nodes{(pw-1)*2+1} = iNode;
              nodes{(pw-1)*2+2} = jNode;
              perpWall = ElasticColumn(prpWallTag,iNodeTag,jNodeTag,A,E,I,SUBBASE_ZERO_WEIGHT);
              prpWalls{pw} = perpWall;
              topJoints{pw}.perpBasementWall = perpWall;
           end
           
       end
       
       function tag = generatePrpWallTag(~,topJoint)
           tag = topJoint.opnssTag;
           tag(1) = '3';
       end
       
       function tag = generatePrpWallNodeTag(~,joint,nodePositionCode)
           tag = strcat(joint.opnssTag,'0',num2str(nodePositionCode));
       end
       
       function storyJoints  = getStoryJoints(this,story,framePosition)
           % framePosition can only have values 1 or 2
           % 1: first opensees frame
           % 2: second opensees frame
           storyJoints = cell(1,this.nXgrids);
           indx = 1;
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
               jointOnStory = strcmp(story,joint.storyName);
               if framePosition == 1
                   jointIsQualified = jointOnStory && ...
                       joint.isOnOpenseesFrames && ~joint.isOn2ndOpenseesFrame;
               elseif framePosition == 2
                   jointIsQualified = jointOnStory && ...
                       joint.isOnOpenseesFrames && joint.isOn2ndOpenseesFrame;
               else
                  disp('domain.getStoryJoints(..) method wrong input') 
                  disp('framePosition can only have values 1 or 2')
               end
               if jointIsQualified
                   storyJoints{indx} = joint;
                   indx = indx + 1;
               end
           end
           storyJoints = this.sortJointLeft2Right(storyJoints); 
       end
       
       function left2rightJoints = sortJointLeft2Right(~,joints)
           nJoints = length(joints);
          for j = 1:nJoints-1
              for i = j+1:nJoints
                  if joints{j}.x_etabs > joints{i}.x_etabs
                      temp = joints{i};
                      joints{i} = joints{j};
                      joints{j} = temp;
                  end
              end
          end
          left2rightJoints = joints;
       end
       
       %% adding walls weight load
       function addBasementWallsWeight(this)
          nBasementStories = length(this.basementLevels)-1;
          for bs = 1:nBasementStories
              story = this.basementLevels{bs};
              storyWalls = this.getStoryWalls(story);
              storyPrpWalls = this.getStoryPerpWalls(story);
              topmostBasementStory = (bs == 1);
              for w = 1:length(storyWalls)
                  wall = storyWalls{w};
                  upperWallsCumulVertLoad = 0;
                  if ~topmostBasementStory
                      upperWall = this.getUpperWall(wall,w);
                      upperWallsCumulVertLoad = upperWall.cumulativeVertLoad;
                  end
                  wall.assignLoadToNodes(upperWallsCumulVertLoad);
                  wall.calcCumulativeVertLoad();                    
              end
              
              for pw = 1:length(storyPrpWalls)
                  perpWall = storyPrpWalls{pw};
                  upperPrpWallsCumulVertLoad = 0;
                  if ~topmostBasementStory
                      upperPrpWall = this.getUpperPrpWall(perpWall,pw);
                      upperPrpWallsCumulVertLoad = upperPrpWall.cumulativeVertLoad;
                  end
                  mm2m = 0.001;
                  perpWallTopNode = this.findPerpWallNodeByTag(perpWall.jNode);
                  perpWallBotNodes = this.findPerpWallNodeByTag(perpWall.iNode);
                  if perpWallTopNode.z < perpWallBotNodes.z
                      warning('Domain::addBasementWallsWeight\n perpWall botNode is above its topNode');
                      pause
                  else
                      wallHeight = (perpWallTopNode.z - perpWallBotNodes.z) * mm2m;
                  end
                  perpWallTopNode.yLoad = -upperPrpWallsCumulVertLoad;
                  perpWall.calcCumulativeVertLoad(upperPrpWallsCumulVertLoad,wallHeight);
%                   disp('****************************')
%                   disp(perpWall.cumulativeVertLoad)
              end
          end
       end
       
       function topPerpWall = getUpperPrpWall(this,perpWall,wallNOfromLeft)
           storyNumber = perpWall.getStoryNumber();
           perpWallTopStory = this.storiesTopDown{this.nStories - storyNumber};
           botStoryPerpWalls = this.getStoryPerpWalls(perpWallTopStory);
           if strcmp(perpWallTopStory,'Lobby')
               pause
           end
           topPerpWall = botStoryPerpWalls{wallNOfromLeft};
       end
       
       function storyPerpWalls = getStoryPerpWalls(this,story)
           % returns a cell containing perpWalls arranged left to right
           storyPerpWalls = cell(1,4);
           indx = 1;
           for i = 1:length(this.perpBasementWalls)
               perpWall = this.perpBasementWalls{i};
               storyNumber = perpWall.getStoryNumber();
               perpWallStory = this.storiesTopDown{this.nStories + 1 - storyNumber};
               perpWallOnStory = strcmp(perpWallStory,story);
               if perpWallOnStory
                   storyPerpWalls{indx} = perpWall;
                   indx = indx + 1;
               end
           end
           
           for i = 1:length(storyPerpWalls)-1
              perpWall = storyPerpWalls{i};
              wTopNode = this.findPerpWallNodeByTag(perpWall.jNode);
              wBotNode = this.findPerpWallNodeByTag(perpWall.iNode);
              for j = i+1:length(storyPerpWalls)
                  if wBotNode.x < wTopNode.x
                      temp = storyPerpWalls{j};
                      storyPerpWalls{j} = perpWall;
                      storyPerpWalls{i} = temp;
                  end
              end
           end
                   
       end
       
       function node = findPerpWallNodeByTag(this,nodeTag)
           for n = 1:length(this.perpBasementWallsNodes)
               wallNode = this.perpBasementWallsNodes{n};
               nodesTagMatch = strcmp(nodeTag,wallNode.tag);
               if nodesTagMatch
                   node = wallNode;
                   return
               end
           end
       end
       
       function upperWall = getUpperWall(this,wall,wallNOfromLeft)
           wallUpperStory = '';
           for bs = 1:length(this.basementLevels)-1
               bottomStory = this.basementLevels{bs+1};
               wallsUpperStory = strcmp(wall.storyName,bottomStory);
               if wallsUpperStory
                   wallUpperStory = this.basementLevels{bs};
               end
           end
           
           if strcmp(wallUpperStory,'')
               warning('in Domain::getUpperWall(), no upper story found');
               pause
           else
               upperStoryWalls = this.getStoryWalls(wallUpperStory);
               upperWall = upperStoryWalls{wallNOfromLeft};               
           end
       end
       
       function storyWalls = getStoryWalls(this,story)
           % returns a specified story's walls, arranged left to right
           nWalls = this.nXgrids-1;
           storyWalls = cell(1,nWalls);
           indx = 1;
           for w = 1:length(this.basementWalls)
               wall = this.basementWalls{w};
               wallIsOnStory = strcmp(story,wall.storyName);
               if wallIsOnStory
                  storyWalls{indx} = wall;
                  indx = indx + 1;
               end
           end
           
           for i = 1:nWalls-1
               for j = i+1:nWalls
                   if storyWalls{j}.topLeftNode.x < storyWalls{i}.topLeftNode.x
                      temp = storyWalls{j};
                      storyWalls{j} = storyWalls{i};
                      storyWalls{i} = temp;
                   end
               end
           end
       end
       
       %% calculating FEMA p695 period
       function calculatePeriod_fema(this)
           
           SMRFheight = this.calculateSMRFheight();
           ascePeriod = 0.0466*SMRFheight^(0.9);
           if 1.4 * ascePeriod <= 0.25
               this.femaPeriod = 0.25;
           else
               this.femaPeriod = 1.4 * ascePeriod;
           end
       end
       
       function SMRFheight = calculateSMRFheight(this)
           nSMRFstories = this.nStories - this.nBasementLevels + 1;
           lobbyH = 4; % unit: m
           residentialH = 3.4; %unit: m
           SMRFheight = lobbyH + (nSMRFstories-1) * residentialH;
       end

       %% generating opensees model (.tcl files)
       
       function writeNodesToFile(this)
           disp('writing main grid nodes..')
           file = strcat(this.openseesModelDir,'nodes.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'OPENSEES MODEL NODES');
           Domain.writeTitleInFile(fileID,'MODEL MAIN FRAMES NODES');
%            [~,nOpenssNodes] = size(this.openseesNodes);
%            for n = 1:nOpenssNodes
%                % apply some conditions not to print joints center nodes
%                node = this.openseesNodes{n};
%                
%                node.writeOpenseesCmmnd(fileID);
%            end
           for j = 1:this.nMainGridJoints
               this.mainGridJoints(j).writeNodesToFile(fileID,this.lowermostLevel);
           end
%            Domain.writeTitleInFile(fileID,'PERPENDICULAR BASEMENT WALLS NODES');
%            for n = 1:length(this.perpBasementWallsNodes)
%                this.perpBasementWallsNodes{n}.writeOpenseesCmmnd(fileID);
%            end
           fclose(fileID);
       end
       
       function writeElasticElmntsToFile(this)
           disp('writing elastic beams (Ibarra model)..')
          file = strcat(this.openseesModelDir,'elasticBeams.tcl');
          fileID = fopen(file,'w');
          Domain.writeTitleInFile(fileID,'ELASTIC BEAMS');
          for b = 1:this.nBeams
              beam = this.beams(b);
              if beam.isOnOpenseesFrame
                  beam.elasticElmnt.writeOpenseesCmmnd(fileID);
              end
          end
          fclose(fileID);
          
          disp('writing elastic columns (Ibarra model)..')
          file = strcat(this.openseesModelDir,'elasticColumns.tcl');
          fileID = fopen(file,'w');
          Domain.writeTitleInFile(fileID,'ELASTIC COLUMS');
          for c = 1:this.nColumns
              column = this.columns(c);
              if column.isOnOpenseesFrame
                  column.elasticElmnt.writeOpenseesCmmnd(fileID);
              end
          end
          fclose(fileID);
       end
       
       function writeHystereticMatsToFile(this,HYSTERETIC_MODEL_FLAG)
           disp('writing hysteretic materials..')
           switch HYSTERETIC_MODEL_FLAG
               case 1
                   fileName = 'bilinearMaterial.tcl';
               case 2
                   fileName = 'peakOrientedMaterial.tcl';
               case 3
                   fileName = 'pinchingMaterial.tcl';
               otherwise
                   fprintf('\n\n %d IS AN INVALID VALUE FOR HYSTERETIC_MODEL_FLAG',HYSTERETIC_MODEL_FLAG)
                   return
           end
           file = strcat(this.openseesModelDir,fileName);
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'HYSTERETIC MATERIAL');
           for c = 1:this.nColumns
              column = this.columns(c);
              if column.isOnOpenseesFrame && column.isRC
                  column.hystereticMat.writeOpenseesCmmnd(fileID);
              end
           end
          
           for b = 1:this.nBeams
              beam = this.beams(b);
              if beam.isOnOpenseesFrame
                  beam.hystereticMat.writeOpenseesCmmnd(fileID);
              end
          end
          fclose(fileID);
       end
       
       function writeJoint2dsToFile(this)
           disp('writing joint2D and zerolength elements..')
           file = strcat(this.openseesModelDir,'joint2d_zerolength.tcl');
           fileID = fopen(file,'w');
           zeroLengthTitleNotSet = 1;
           Domain.writeTitleInFile(fileID,'JOINT2D ELEMENTS');
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
               if joint.isOnOpenseesFrames
                   isOnLowermostLvl = strcmp(joint.storyName,this.lowermostLevel);
                   if ~isOnLowermostLvl
                       joint.writeOpenseesCmmnd(fileID);
                   else
                       if zeroLengthTitleNotSet
                           Domain.writeTitleInFile(fileID,'ZERO LENGTH ELEMENTS');
                           zeroLengthTitleNotSet = 0;
                       end
                       joint.lowermostLvlZeroLngth.writeOpenseesCmmnd(fileID);
                   end
               end
           end
           fclose(fileID);
       end
       
       
       function fixStructureSupports(this)
           disp('writing frames nodes fixity..')
           file = strcat(this.openseesModelDir,'nodes.tcl');
           fileID = fopen(file,'a+');
           
           % lowermost columns have zerolength elements at the bottom the
           % materials of which are hysteretic materials. the node considered
           % to be at the bottom of the zerolength element should be fixed in
           % order for columns and hence the whole structure to be stable.
           Domain.writeTitleInFile(fileID,'MAIN FRAMES FIXED NODES');
           for j = 1:this.nMainGridJoints
               joint = this.mainGridJoints(j);
               jointIsOnLowermostLvl = strcmp(joint.storyName,this.lowermostLevel);
               if joint.isOnOpenseesFrames && jointIsOnLowermostLvl
                   toBeFixedNodeTag = joint.openseesNodes{4}.tag;
                   txt = sprintf('fix %s 1 1 1\n',toBeFixedNodeTag);
                   fprintf(fileID,txt);
               end
           end
           fclose(fileID);
       end
       
       function writeBasementWallsToFile(this,BASEMENTWALL_ELEMENT_FLAG)
           disp('writing basement walls \/')
           file = strcat(this.openseesModelDir,'basementwalls.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'BASEMENT WALLS (ON XZ PLANE) NODES, QUADS & MATERIALS');
           fprintf(fileID,'model basic -ndm 2 -ndf 2\n');
           fprintf(fileID,'set smallMass 1\n');
           E = this.concMaterial.E_exp;
           MPa2Pa = 1e+6;
           wallsNDMaterialCmd = sprintf('nDMaterial ElasticIsotropic $elasticConcreteTag %d 0.2\n',E*MPa2Pa);
           fprintf(fileID,'set elasticConcreteTag 40000002\n');
           fprintf(fileID,wallsNDMaterialCmd);
           
           disp('    writing nodes..')
           Domain.writeTitleInFile(fileID,'BASEMENT WALLS'' NODES');
           for w = 1:length(this.basementWalls) 
               wall = this.basementWalls{w};
               wall.writeNodesToFile(fileID);
           end
           disp('    writing lowermost wall nodes fixity..')
           Domain.writeTitleInFile(fileID,'FIXING LOWERMOST BASEMENTWALL BOTTOM NODES');
           for w = 1:length(this.basementWalls) 
               wall = this.basementWalls{w};
               if wall.bottomNodesMustBeFixed
                   wall.writeNodesFixityToFile(fileID);
               end
           end
           
           disp('    writing Quad elements..')
           Domain.writeTitleInFile(fileID,'BASEMENT WALLS'' QUAD ELEMENTS');
           for w = 1:length(this.basementWalls) 
               wall = this.basementWalls{w};
               wall.quadElmntsToFile(fileID,BASEMENTWALL_ELEMENT_FLAG);
           end
           fclose(fileID);
           
           disp('    writing corner nodes constrains..')
           file = strcat(this.openseesModelDir,'basementWallsEqualDOFs.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'BASEMENT WALLS'' NODES CONSTRAINTS');
           for w = 1:length(this.basementWalls) 
               wall = this.basementWalls{w};
               wall.writeNodesConstraintsToFile(fileID);
           end           
           fclose(fileID);
       end
       
       function writePerpBasementWallsToFile(this)
           disp('writing perpendicular basement walls \/')
           file = strcat(this.openseesModelDir,'perpendicularBasementWalls.tcl');
           fileID = fopen(file,'w');
           
           % writing nodes to file
           disp('    writing nodes..')
           Domain.writeTitleInFile(fileID,'PERPENDICULAR BASEMENT WALLS NODES');
           for n = 1:length(this.perpBasementWallsNodes)
               this.perpBasementWallsNodes{n}.writeOpenseesCmmnd(fileID);
           end
           
           disp('    writing elastic elements..')
           Domain.writeTitleInFile(fileID,'ELASTIC PERPENDICULAR WALLS ELEMENTS');
          for pw = 1:length(this.perpBasementWalls)
              wall = this.perpBasementWalls{pw};
              wall.writeOpenseesCmmnd(fileID);
          end
          
          % fixing lowermost storiy's perpendicular wall bottom nodes
          disp('    writing nodes fixities..')
           Domain.writeTitleInFile(fileID,'PERPENDICULAR WALLS FIXED NODES');
           for n = 1:length(this.perpBasementWallsNodes)
               node = this.perpBasementWallsNodes{n};
               if node.z == 0
                   toBeFixedNodeTag = node.tag;
                   txt = sprintf('fix %s 1 1 1\n',toBeFixedNodeTag);
                   fprintf(fileID,txt);                   
               end
           end
           
           disp('    writing constrains..')
           Domain.writeTitleInFile(fileID,'PERPENDICULAR WALLS CONSTRAINTS');
           for bs = 1:this.nBasementLevels-1
               story = this.basementLevels(bs);
               botStory = this.basementLevels(bs+1);
               frm1storyJoints = this.getStoryJoints(story,1);
               frm1botStoryJoints = this.getStoryJoints(botStory,1);
               frm2storyJoints = this.getStoryJoints(story,2);
               frm2botStoryJoints = this.getStoryJoints(botStory,2);
               this.constrainStoryPerpWalls(fileID,frm1storyJoints,frm1botStoryJoints);
               this.constrainStoryPerpWalls(fileID,frm2storyJoints,frm2botStoryJoints);
           end
           fclose(fileID);
       end
       
       function constrainStoryPerpWalls(this,fileID,storyJoints,botStoryJoints)
           nJoints = length(storyJoints);
           leftPerpWall = storyJoints{1}.perpBasementWall;
           rightPerpWall = storyJoints{nJoints}.perpBasementWall;
           % story [top] leftmost joint constraint
%            storyLeftmostJoint = storyJoints{1};
           this.writePerpWallEqualDOF2File(fileID,leftPerpWall,'top');
           
           % story [top] rightmost joint constraint
%            storyRightmostJoint = storyJoints{nJoints};
           this.writePerpWallEqualDOF2File(fileID,rightPerpWall,'top');
           
           if ~strcmp(botStoryJoints{1}.storyName,this.lowermostLevel)
               % story [bot] leftmost joint constrint
%                botStoryLeftmostJoint = botStoryJoints{1};
               this.writePerpWallEqualDOF2File(fileID,leftPerpWall,'bottom');
               % story [bot] rightmost joint constrint
%                botStoryRightmostJoint = botStoryJoints{nJoints};
               this.writePerpWallEqualDOF2File(fileID,rightPerpWall,'bottom');
           end
       end
       
       function writePerpWallEqualDOF2File(this,fileID,perpWall,position)
           % position argument refer to the position of the
           % joint, relative to the story and can either be
           % 'top' or 'bottom'
           
           
%            masterNodeTag = joint.opnssTag; %%%%%%%%%%%%%%%%%%% CHANGE TO JOINT2D RIGHT NODE
           if strcmp(position,'top')
               slaveNodeTag  = perpWall.jNode;
           elseif strcmp(position,'bottom')
              slaveNodeTag  = perpWall.iNode;
           else
               warnmsg = 'position arg. in Domain::writePerpWallEqualDOF2File has been assigned wrong value';
               warndlg(warnmsg,'Warning!')
           end
           masterNodeTag = this.findPrpWallNodeMaster(slaveNodeTag);
           txt = sprintf('equalDOF %s %s 1 2 3\n',masterNodeTag,slaveNodeTag);
           fprintf(fileID,txt);
       end
       
       function masterNodeTag = findPrpWallNodeMaster(this,slaveNodeTag)
           for n = 1:length(this.perpBasementWallsNodes)
               node = this.perpBasementWallsNodes{n};
               nodeFound = strcmp(slaveNodeTag,node.tag);
               if nodeFound
                  masterNodeTag = node.masterNodeTag;
                  return
               end
           end
       end
       
       function createRigidSlabConditions(this,RIGID_SLAB_FLAG)
           disp('writing rigid slabs constrains..')
           file = strcat(this.openseesModelDir,'rigidSlabConditions.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'CREATING RIGID SLAB CONDITIONS');
           if RIGID_SLAB_FLAG == 1 || RIGID_SLAB_FLAG == 2 || RIGID_SLAB_FLAG == 3
               for s = 1:this.nStories
                   storyName = this.storiesTopDown{s};
                   storyJoints_frame1 = this.getStoryJoints(storyName,1);
                   this.writeRigSlabConstraints2File(fileID,...
                       storyJoints_frame1,RIGID_SLAB_FLAG);
                   storyJoints_frame2 = this.getStoryJoints(storyName,2);
                   this.writeRigSlabConstraints2File(fileID,...
                       storyJoints_frame2,RIGID_SLAB_FLAG);
               end
           elseif RIGID_SLAB_FLAG == 0
               return
           else
               msg = 'wrong input value for Domain>createRigidSlabConditions';
               title = 'YOU HAVE MADE A BOO BOO :)';
               warndlg(msg,title);               
           end
           fclose(fileID);
       end
       
       function writeRigSlabConstraints2File(~,fileID,joints,RIGID_SLAB_FLAG)
           switch RIGID_SLAB_FLAG
               case 1
                   masterNodeTag = joints{1}.opnssTag;
                   for j = 2:length(joints)
                       slaveNodeTag = joints{j}.opnssTag;
                       % equalDOF $rNodeTag $cNodeTag $dof1 $dof2 ...
                       fprintf(fileID,'equalDOF %s %s 1\n',...
                           masterNodeTag,slaveNodeTag);
                   end                   
               case 2
                   masterNodeTag = joints{1}.openseesNodes{1}.tag;
                   for j = 2:length(joints)
                       slaveNodeTag = joints{j}.openseesNodes{1}.tag;
                       fprintf(fileID,'equalDOF %s %s 1\n',...
                           masterNodeTag,slaveNodeTag);
                   end
               case 3
                   masterNodeTag = joints{1}.openseesNodes{2}.tag;
                   for j = 2:length(joints)
                       slaveNodeTag = joints{j}.openseesNodes{2}.tag;
                       fprintf(fileID,'equalDOF %s %s 1\n',...
                           masterNodeTag,slaveNodeTag);
                   end                   
                   
               otherwise
                   msg = 'wrong input for method Doamin>writeRigSlabConstraints2File';
                   title = 'YOU HAVE MADE A BOO BOO :)';
                   warndl(msg,title);
           end
           

       end
       
       function connectTwoFramesTogether(this)
           disp('writing frame connector elements..')
           file = strcat(this.openseesModelDir,'frameConnectors.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'RIGID ELEMENTS CONNECTING TWO FRAMES TOGETHER + THEIR NODES AND ZEROLENGTHS');
           this.frameConnectingRigidElements = cell(this.nStories);
           for s = 1:this.nStories 
               
               storyName = this.storiesTopDown{s};
               storyJoints_frm1 = this.getStoryJoints(storyName,1);
               storyJoints_frm2 = this.getStoryJoints(storyName,2);
               
               storyNumber = this.nStories - (s-1);
               if storyNumber < 10
                   storyNumber = strcat('0',num2str(storyNumber));
               else
                   storyNumber = num2str(storyNumber);
               end
               tag = strcat('20',storyNumber,'00');
               
               rotationalMat = '$HingedMatTag';
               leftJoint  = storyJoints_frm1{length(storyJoints_frm1)};
               iNode_joint   = leftJoint.openseesNodes{1};
               iNodeTag_joint = iNode_joint.tag;
               iNodeTag = strcat(iNodeTag_joint,'1');
               iNode = OpenseesNode(iNodeTag,iNode_joint.x,iNode_joint.z);
               leftSpringTag = leftJoint.opnssTag; leftSpringTag(1) = '6'; leftSpringTag(7) = '1';
               leftSpring = ZeroLength(leftSpringTag,iNodeTag_joint,iNodeTag,rotationalMat);
               
               rightJoint = storyJoints_frm2{1};
               jNode_joint   = rightJoint.openseesNodes{3};
               jNodeTag_joint = jNode_joint.tag;
               jNodeTag = strcat(jNodeTag_joint,'3');
               jNode = OpenseesNode(jNodeTag,jNode_joint.x,jNode_joint.z);
               rightSpringTag = leftJoint.opnssTag; rightSpringTag(1) = '6'; rightSpringTag(7) = '3';
               rightSpring = ZeroLength(rightSpringTag,jNodeTag_joint,jNodeTag,rotationalMat);
               
               iNode.writeOpenseesCmmnd(fileID);
               jNode.writeOpenseesCmmnd(fileID);
               leftSpring.writeOpenseesCmmnd(fileID);
               rightSpring.writeOpenseesCmmnd(fileID);
               
               A = 100; %unit: m2
               I = 1000; %unit: m4
               txt = sprintf('element elasticBeamColumn %s %s %s %d $rigidConnectorsE %d $transfTag\n\n',...
                   tag,iNodeTag,jNodeTag,A,I);
               fprintf(fileID,txt);
           end
           fclose(fileID);
       end
       
       function writeGravityAndSoilLoadsToFile(this)
           disp('writing beams loads..')
           file = strcat(this.openseesModelDir,'beamsGravityLoads.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'BEAMS GRAVITY LOADS');
           fprintf(fileID,'pattern Plain 1 Linear {\n');
           Domain.writeTitleInFile(fileID,'BEAMS GRAVITY LOADS (FEMA P695 LOAD COMBINATION)');
           fprintf(fileID,'#\teleLoad -ele $eleTag -type -beamUniform $Wy\n');
           for b = 1:this.nBeams
              beam = this.beams(b);
              if beam.isOnOpenseesFrame
                  beam.elasticElmnt.writeBeamLoadToFile(fileID);
              end
           end
           fprintf(fileID,'}');
           fclose(fileID);
           
           disp('writing basement walls weight loads..')
           file = strcat(this.openseesModelDir,'basementWallsWeightLoads.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'BASEMENT WALLS WEIGHT LOADS');
           fprintf(fileID,'pattern Plain 2 Linear {\n');
           fprintf(fileID,'# load $nodeTag (ndf $LoadValues)\n');
           nWallNodesDOF = 2;
           for w = 1:length(this.basementWalls)
               wallTopNodes = this.basementWalls{w}.topNodes;
               for n = 1:length(wallTopNodes)
                   wallTopNodes{n}.writeLoadsToFile(fileID,nWallNodesDOF);
               end
           end
           fprintf(fileID,'}');
           fclose(fileID);           
           
           disp('writing perpendicular basement walls weight loads..')
           file = strcat(this.openseesModelDir,'perpBasementWallsWeightLoads.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'PERPENDICULAR BASEMENT WALLS WEIGHT LOADS');
           fprintf(fileID,'pattern Plain 3 Linear {\n');
           fprintf(fileID,'# load $nodeTag (ndf $LoadValues)\n');
           nWallNodesDOF = 3;
           for w = 1:length(this.perpBasementWalls)
               wallTopNodeTag = this.perpBasementWalls{w}.jNode;
               wallTopNode = this.findPerpWallNodeByTag(wallTopNodeTag);
               wallTopNode.writeLoadsToFile(fileID,nWallNodesDOF);
           end
           fprintf(fileID,'}');
           fclose(fileID);               
           
           disp('writing soil loads..')
           file = strcat(this.openseesModelDir,'soilLoads.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'PERPENDICULAR WALLS SOIL LOADS');
           Domain.writeTitleInFile(fileID,'PERPENDICULAR BASEMENT WALLS SOIL LOADS');
           fprintf(fileID,'pattern Plain 4 Linear {\n');
           for pw = 1:length(this.perpBasementWalls)
               this.perpBasementWalls{pw}.writeSoilLoadsToFile(fileID);
           end
           
           fprintf(fileID,'}');
           fclose(fileID);
       end
       
       function createRayleighDampingFile(this)
           file = strcat(this.openseesModelDir,'rayleighDamping.tcl');
           fileID = fopen(file,'w');
           Domain.writeTitleInFile(fileID,'RAYLEIGH DAMPING');
           fprintf(fileID,'set n %d\n',Domain.stfnsModFac);
           fprintf(fileID,'set iMode 1\n');
           fprintf(fileID,'set jMode 3\n');
           fprintf(fileID,'set xi 0.05\n');
           fprintf(fileID,'set Pi [expr 4*atan(1)]\n');
           fprintf(fileID,'set omega2list [eigen 12]\n');
           fprintf(fileID,'set omegai [expr sqrt([lindex $omega2list $iMode-1])]\n');
           fprintf(fileID,'set omegaj [expr sqrt([lindex $omega2list $jMode-1])]\n');
           fprintf(fileID,'set alphaM [expr 2*$xi*$omegai*$omegaj/($omegai+$omegaj)]\n');
           fprintf(fileID,'set betaKinit [expr 2*$xi/($omegai+$omegaj)]\n');
           fprintf(fileID,'set betaKinit [expr $betaKinit*(1 + 1.0/$n)]\n');
           fprintf(fileID,'set betaK 0.\n');
           fprintf(fileID,'set betaKcomm 0.\n');
           fprintf(fileID,'rayleigh $alphaM $betaK $betaKinit $betaKcomm\n');
           
           fclose(fileID);
       end
       
       function createTheFinalOpenseesModel(this,...
               HYSTERETIC_MODEL_FLAG, PERIOD_FLAG)
           file = strcat(this.openseesModelDir,'model.tcl');
           fileID = fopen(file,'w'); 
           Domain.writeTitleInFile(fileID,'OPENSEES MODEL');
           fprintf(fileID,'source basementwalls.tcl\n');
           
           fprintf(fileID,'model basic -ndm 2 -ndf 3\n');
           fprintf(fileID,'set nStories %d\n',this.nStories);
           % writing a list containing stories mass. lindex corresponds to
           % story name
           fprintf(fileID,'set storiesMass {0. ');
           storiesBotUpMasses = flip(this.storiesMass_pushover);
           for s = 1:this.nStories
               fprintf(fileID,'%d ',storiesBotUpMasses(s));
               if s == this.nStories
                  fprintf(fileID,'}\n'); 
               end
           end
           openseesModelWeight = 0.5 * this.buildingWeight_upperLevels;
           fprintf(fileID,'# buildingWeight is the weight of the opensees model [non-basement stories]\n');
           fprintf(fileID,'set buildingWeight %d\n',openseesModelWeight);
           fprintf(fileID,'set buildingH %d\n',this.calculateSMRFheight);
           fprintf(fileID,'set smallMass 1\n');
           fprintf(fileID,'set rigidMatE 1.e16\n');
           fprintf(fileID,'set rigidMatTag 40000000\n');
           fprintf(fileID,'uniaxialMaterial Elastic $rigidMatTag $rigidMatE\n');
           fprintf(fileID,'set HingedMatE 10\n');
           fprintf(fileID,'set HingedMatTag 40000003\n');
           fprintf(fileID,'uniaxialMaterial Elastic $HingedMatTag $HingedMatE\n');
           fprintf(fileID,'set rigidConnectorsE 1.e13\n');
           fprintf(fileID,'set LrgDspTag 0\n');
           fprintf(fileID,'set transfTag 1\n');
           fprintf(fileID,'geomTransf PDelta $transfTag\n');
           
           fprintf(fileID,'source nodes.tcl\n');
           
           switch HYSTERETIC_MODEL_FLAG
               case 1
                   fileName = 'bilinearMaterial.tcl';
               case 2
                   fileName = 'peakOrientedMaterial.tcl';
               case 3
                   fileName = 'pinchingMaterial.tcl';
           end           
           fprintf(fileID,'source %s\n',fileName);

           fprintf(fileID,'source elasticBeams.tcl\n');
           fprintf(fileID,'source elasticColumns.tcl\n');
           fprintf(fileID,'source joint2d_zerolength.tcl\n');
           fprintf(fileID,'source basementWallsEqualDOFs.tcl\n');
           fprintf(fileID,'source perpendicularBasementWalls.tcl\n');
           fprintf(fileID,'source rigidSlabConditions.tcl\n');
%            fprintf(fileID,'source soilAndGravityLoads.tcl\n');
           fprintf(fileID,'source frameConnectors.tcl\n');
           fprintf(fileID,'source rayleighDamping.tcl\n');
           if PERIOD_FLAG == 1
               % use FEMA period
               fprintf(fileID,'set Tperiod %i\n',this.femaPeriod);
           elseif PERIOD_FLAG == 2
               % use first mode period (opensees model modal analysis)
               fprintf(fileID,'set Pi [expr 4*atan(1)]\n');
               fprintf(fileID,'set omega2 [eigen 1]\n');
               fprintf(fileID,'set Tperiod [expr 2*$Pi/sqrt($omega2)]\n\n');               
           else
               warndlg('PERIOD_FLAG can be either 1 or 2 (and it''s not)')
           end
           
           fprintf(fileID,'# static analysis for gravity loads\n');
%            fprintf(fileID,'source gravityAnalysis.tcl\n');
           fclose(fileID);
       end       
       
       %% retrieving domain elements
       function frameELement = findByStoryNameAndLabel(this,storyName,label,frmObjType)
          % frmObjType (frame object type), could be 'beam' or 'column'
           function sameObject = compareData(frmObj,storyName,label)
               sameStory = strcmp(storyName,frmObj.storyName);
               sameLabel = strcmp(label,frmObj.nonUniqueID_etabs);
               sameObject   = sameStory && sameLabel;
           end
          isBeam = strcmp('beam',frmObjType);
          if isBeam
              for b = 1:this.nBeams
                 beam = this.beams(b);
                 if compareData(beam,storyName,label)
                     frameELement = beam;
                 end
              end
          elseif strcmp('column',frmObjType) 
              for c = 1:this.nColumns
                  column = this.columns(c);
                  if compareData(column,storyName,label)
                      frameELement = column;
                  end
              end
          else
              disp('frame object should be either ''beam'' or ''column''')
          end
       end
       
       function frameElmnt = findByEtabsUniqueID(this,uniqID)
          for c = 1:this.nColumns
              col = this.columns(c);
              if col.uniqueID_etabs == uniqID
                  frameElmnt = col;
                  return
              end
          end
          
          for b = 1:this.nBeams
              beam = this.beams(b);
              if beam.uniqueID_etabs == uniqID
                  frameElmnt = beam;
                  return
              end
          end
       end
       
       function displayOpenseesBeams(this)
           for b = 1:this.nBeams
               beam = this.beams(b);
               if beam.isOnOpenseesFrame
                   disp(beam)
               end
           end
       end
       
       function displayOpenseesColumns(this)
           for c = 1:this.nColumns
               column = this.columns(c);
               if column.isOnOpenseesFrame
                   disp(column)
               end
           end
       end
              
   end
end






