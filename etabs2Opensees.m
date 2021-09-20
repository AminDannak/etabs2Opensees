clc
tic
% inputs
inputDir = 'C:\Users\Amin.DESKTOP-V4HEOS6\OneDrive\thesis\etabs_models\3U2B3B4mBL_steelCol';
% cd(inputDirPath);
xlsxFileName = '3U2B3B4mBL';
inputFilePath = strcat(inputDir,'\',xlsxFileName);


fprintf('input file: %s \n', xlsxFileName)
display('LET THE GAME BEGIN B) ')

%% FLAGS
% JOINT_SHAPE_FLAG defines how joint2D nodes 1-4 are located
% value 1: based on dimensions of largest column/beam dimensions
% JOINT_SHAPE_FLAG = 1; % I think it does not make much difference
% [to be deleted...]

% STEEL_COLUMNS_FLAG is self-explanatory!`
% value 1: model has steel columns in the basement
% value 0: model dose not have steel columns in the basement
% I can name the etabsFile in a way that this flag could be infered 4m them
% [set it always to 1 for now]
STEEL_COLUMNS_FLAG = 1;

% BEAMS_Ig_FLAG
% value 1: slab thickness is considered in calculating Ig for beams [ATC-72]
% value 0; slab thickness is NOT considered
% [set it always to 0 for now]
BEAM_Ig_FLAG = 1;


% HYSTERETIC_MODEL_FLAG
% this flag determines which of the following hysteretic models is used;
% value 1: Bilnear Model
% value 2: Peak-Oriented Model
% value 3: Pinching Model
HYSTERETIC_MODEL_FLAG = 2;


% SUBBASE_ZERO_WEIGHT
% value 1: subbase beams/columns/walls will have "NO" MASS (not weight!)
% value 0: subbase beams/columns/walls will have "NORMAL" MASS
% keep it always 1 for now. [basmeent levels load is not set
% because the wall seems to get all the load in etabs and beams seem
% to get nothing!]
SUBBASE_ZERO_WEIGHT = 1;

% BASEMENTWALL_ELEMENT_FLAG
% value 1: uses "quad" elements for modeling retaining walls
% value 2: uses "sspquad" elements for modeling retaining walls
BASEMENTWALL_ELEMENT_FLAG = 1;

% FRAMES_CONNECTOR_FLAG [ignored for now]
% value 1: uses a rigid elastic member (hinged at both ends) to connect two
% frame together.
% value 2: uses equalDOF command to 


% RIGID_SLAB_FLAG
% this flag will determine whther or not the "horizontal" DOF of joint2D
% elements' central nodes at each story should be contraint to the left
% most joint2D element's central node [each xz frame independently]
% value 0: ignores the rigid slab conditions
% value 1: creates the rigid slab conditions [constrain joint2D center Nodes]
% value 2: creates the rigid slab conditions [constrain joint2D righthand Nodes]
% value 3: creates the rigid slab conditions [constrain joint2D top Nodes]
% [constraining center nodes, reuduces the period by a factor of 10 !!!]
RIGID_SLAB_FLAG = 3; 

% PERIOD_FLAG
% value 1: uses FEMA p695 period (Cu*Ta)
% value 2: uses modal analysis period (first mode)
PERIOD_FLAG = 1;

%% Obtaining and calculating modeling parameters
domain = Domain(inputFilePath,inputDir);
domain.form3Dgrid();
domain.getJointsData();
domain.getMaterials(STEEL_COLUMNS_FLAG);
domain.getSectionData();
domain.getFrameObjectsData();
domain.getSectionAdditionalData();
domain.makeJointsExtraNodes();
domain.reviseFrmELmntsLengths();
domain.reviseBeamsIg(BEAM_Ig_FLAG);
domain.specifyReinforcement();
domain.createZareianElasticElmnts(SUBBASE_ZERO_WEIGHT);
domain.creatNonlinearFrmElmnts(HYSTERETIC_MODEL_FLAG);
domain.reviseZareianFrmELmntsI();
domain.completeJointsData();
domain.assignMassToNodes(SUBBASE_ZERO_WEIGHT);
domain.addGravityLoadToBeams();
domain.createBasementWalls();
domain.createPerpendicularWalls(SUBBASE_ZERO_WEIGHT);
domain.addSoilLoadToPerpendicularWalls();
domain.addBasementWallsWeight();
domain.calculatePeriod_fema();

%% creating opensees model

fprintf('\n\n>> GENERATING OPENSEES MODEL..\n\n')
domain.writeNodesToFile();
domain.writeElasticElmntsToFile();
domain.writeHystereticMatsToFile(HYSTERETIC_MODEL_FLAG);
domain.writeJoint2dsToFile();
domain.fixStructureSupports(); % must be done after 'domain.writeJoint2dsToFile()'
domain.writeBasementWallsToFile(BASEMENTWALL_ELEMENT_FLAG);
domain.writePerpBasementWallsToFile();
domain.createRigidSlabConditions(RIGID_SLAB_FLAG);
domain.connectTwoFramesTogether();
domain.writeGravityAndSoilLoadsToFile();
domain.createRayleighDampingFile();
domain.createTheFinalOpenseesModel(HYSTERETIC_MODEL_FLAG,PERIOD_FLAG);

fprintf('OPENSEES MODEL COMPLETED. OH YEAH.\n')
fprintf('<<< HAVE A NICE DAY BROMIE :) >>>\n')

toc

