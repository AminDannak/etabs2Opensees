clc
Es = 200e3;
Ec = 28502;
fy = 500;
fc = 36.77;

% beams
d = 255;
dPrime = 45;
alpha_sl = 1;
b = 300;
h = 300;
Ag = b*h;
I = (b*h^3)/12;
LclrSpn = 3600;
Ls = LclrSpn/2;
s = 75;
AWeb = 0;
N = 0;
db = 20;

A10 = pi * 10^2 / 4;
A16 = pi * 16^2 / 4;
A20 = pi * 20^2 / 4;
AsTop = 4 * A20;
AsBot = 3 * A16;

sn    = (s/db)*sqrt(fy/100);
nu    = N/(Ag*fc);
rhoSh = 3 * A10/(b*s);

% modify unit: Nmm * 1e-3 = Nm [Nm is the SI unit for rotaional stiffness]
initialStiffness = (6*Ec*I/LclrSpn) * 1e-3;
KNm2Nm = 1000;

% beam calculations
disp('************** BEAM STUFF **************')

format short
Ky         = FrameElement.calcKy(N,Ag,fc,Ls,h);
% ADD
initStf_y  = Ky * initialStiffness
Kstf       = FrameElement.calcKstf(N,Ag,fc,Ls,h);
% ADD
initStf_stf= Kstf * initialStiffness; 

MyPos      = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsBot,AsTop,AWeb,N)
McPos      = 1.13 * MyPos;
MyNeg      = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsTop,AsBot,AWeb,N)
McNeg      = 1.13 * MyNeg;


thetapPos  = FrameElement.calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,AsBot,AsTop,b,h)
thetapNeg  = FrameElement.calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,AsTop,AsBot,b,h)

asPos      = (McPos - MyPos)/(thetapPos * initStf_y)
asNeg      = (McNeg - MyNeg)/(thetapPos * initStf_y)

thetapcPos = FrameElement.calcThetaPC(nu,rhoSh,AsBot,AsTop,b,h,fc,fy)
thetapcNeg = FrameElement.calcThetaPC(nu,rhoSh,AsTop,AsBot,b,h,fc,fy)

% ADD
thetayPos  = MyPos/initStf_y;
thetayNeg  = MyNeg/initStf_y;

thetauPos = thetayPos + thetapPos + thetapcPos
thetauNeg = thetayNeg + thetapNeg + thetapcNeg

lambda     = FrameElement.calcLambda(nu,s,d);
% ADD
LAMBDA     = lambda * thetapPos

thetayPos
thetayNeg

% *************************************************************************
% *************************************************************************
% columns: story 1
d = 355;
dPrime = 45;
alpha_sl = 1;
b = 400;
h = 400;
Ag = b*h;
I = (b*h^3)/12;
LclrSpn = 2850;
Ls = LclrSpn/2;
s = 75;
N = 2 * 4 * 3000;  % unit: Newton
% 2 is number of stories above column
% 4 = 2*2 tributary area of column.
% 3000 N/m2 is distributed load

db = 25;

A22 = pi * 22^2 / 4;
A25 = pi * 25^2 / 4;
AsTop = 2 * A25 + 3 * A22;
AsBot = AsTop;
AWeb = 3 * A22;

sn    = (s/db)*sqrt(fy/100);
nu    = N/(Ag*fc);
rhoSh = 3 * A10/(b*s);
% modify unit: Nmm * 1e-3 = Nm [Nm is the SI unit for rotaional stiffness]
initialStiffness = (6*Ec*I/LclrSpn) * 1e-3;

disp('************** 1ST STORY COLUMNS STUFF **************')

Ky         = FrameElement.calcKy(N,Ag,fc,Ls,h);
% ADD
initStf_y  = Ky * initialStiffness
Kstf       = FrameElement.calcKstf(N,Ag,fc,Ls,h);
% ADD
initStf_stf= Kstf * initialStiffness; 

MyPos      = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsBot,AsTop,AWeb,N)
McPos      = 1.13 * MyPos;
MyNeg      = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsTop,AsBot,AWeb,N)
McNeg      = 1.13 * MyNeg;


thetapPos  = FrameElement.calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,AsBot,AsTop,b,h)
thetapNeg  = FrameElement.calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,AsTop,AsBot,b,h)

asPos      = (McPos - MyPos)/(thetapPos * initStf_y)
asNeg      = (McNeg - MyNeg)/(thetapPos * initStf_y)

thetapcPos = FrameElement.calcThetaPC(nu,rhoSh,AsBot,AsTop,b,h,fc,fy)
thetapcNeg = FrameElement.calcThetaPC(nu,rhoSh,AsTop,AsBot,b,h,fc,fy)

% ADD
thetay  = MyPos/initStf_y;
thetay  = MyNeg/initStf_y;

thetauPos = thetay + thetapPos + thetapcPos
thetauNeg = thetay + thetapNeg + thetapcNeg

lambda     = FrameElement.calcLambda(nu,s,d);
% ADD
LAMBDA     = lambda * thetapPos

thetay
% ************************************************************************
% ************************************************************************
LclrSpn = 2700;
Ls = LclrSpn/2;
N = 1 * 4 * 3000;  % unit: Newton
% 1 is number of stories above column
% 4 = 2*2 tributary area of column.
% 3000 N/m2 is distributed load
nu    = N/(Ag*fc);
% modify unit: Nmm * 1e-3 = Nm [Nm is the SI unit for rotaional stiffness]
initialStiffness = (6*Ec*I/LclrSpn) * 1e-3;

disp('************** 2ND STORY COLUMNS STUFF **************')

Ky         = FrameElement.calcKy(N,Ag,fc,Ls,h);
% ADD
initStf_y  = Ky * initialStiffness
Kstf       = FrameElement.calcKstf(N,Ag,fc,Ls,h);
% ADD
initStf_stf= Kstf * initialStiffness; 

MyPos      = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsBot,AsTop,AWeb,N)
McPos      = 1.13 * MyPos;
MyNeg      = FrameElement.calcMy(fc,Ec,fy,Es,d,dPrime,b,AsTop,AsBot,AWeb,N)
McNeg      = 1.13 * MyNeg;


thetapPos  = FrameElement.calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,AsBot,AsTop,b,h)
thetapNeg  = FrameElement.calcThetaP(alpha_sl,nu,rhoSh,fc,fy,sn,AsTop,AsBot,b,h)

asPos      = (McPos - MyPos)/(thetapPos * initStf_y)
asNeg      = (McNeg - MyNeg)/(thetapPos * initStf_y)

thetapcPos = FrameElement.calcThetaPC(nu,rhoSh,AsBot,AsTop,b,h,fc,fy)
thetapcNeg = FrameElement.calcThetaPC(nu,rhoSh,AsTop,AsBot,b,h,fc,fy)

% ADD
thetay  = MyPos/initStf_y;

thetauPos = thetay + thetapPos + thetapcPos
thetauNeg = thetay + thetapNeg + thetapcNeg

lambda     = FrameElement.calcLambda(nu,s,d);
% ADD
LAMBDA     = lambda * thetapPos

thetay