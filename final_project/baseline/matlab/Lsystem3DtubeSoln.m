
%
%L-system
%2D

clear all

%starting seed
axiom = 'F';

%number of repititions
nReps = 4;

%Rules--
rule(1).before = 'F';
rule(1).after = 'F[-&\G][\++&G]||F[--&/G][+&G]'; %'FF-[-F+F+F]-[^\F-F-F&/]';

rule(2).before = 'G';
rule(2).after = 'F[+S][-G]^^F^^[+G][-G]FG' ;%     'G'                   ;

rule(3).before = 'S';
rule(3).after = '[+G][-S][+G][-S]' ;

nRules = length(rule);

%angle: 
%    *  "+": Turn left by angle Delta, Using rotation matrix R_U(Delta).
 %   * "-" : Turn right by angle Delta, Using rotation matrix R_U(-Delta).
 %   * "&" : Pitch down by angle Delta, Using rotation matrix R_L(Delta).
  %  * "^" : Pitch up by angle Delta, Using rotation matrix R_L(-Delta).
  %  * "\" : Roll left by angle Delta, Using rotation matrix R_H(Delta).
 %   * "/" : Roll right by angle Delta, Using rotation matrix R_H(-Delta).
 %   * " | " : Turn around, Using rotation matrix R_H(180).
 
a = 22.5; %degrees 22.5

%Init the turtle
xT = 0;
yT = 0;
zT = 0;
hT = [1 0 0];
lT = [0 1 0];
uT = [0 0 1];

a = deg2rad(a) ; %convert to radians

%turn left-right matrix
Rup = [    cos(a) sin(a) 0;...
           -sin(a) cos(a) 0; ...
           0       0      1];
       
Rum = [    cos(-a) sin(-a) 0;...
           -sin(-a) cos(-a) 0; ...
            0       0      1];
       
 %pitch up-down
 Rlp = [ cos(a) 0  -sin(a) ;...
           0          1     0; ...
         sin(a)    0   cos(a)];
 
 Rlm = [    cos(-a) 0  -sin(-a) ;...
        0          1     0; ...
         sin(-a)    0   cos(-a)];
 
%roll left/right 
Rhp = [  1     0     0; ...   
        0 cos(a) -sin(a) ;...
        0 sin(a)  cos(a) ] ;

Rhm = [  1     0     0; ...   
        0 cos(-a) -sin(-a) ;...
        0 sin(-a)  cos(-a) ] ;

%back up
Rbk = [    cos(pi) sin(pi) 0;...
           -sin(pi) cos(pi) 0; ...
           0       0      1];
 
%length of the line segments corresponding to the symbols F and G
lenF = 1;
lenG = .75;

%make the string
for i=1:nReps
    
    %one character/cell, with indexes the same as original axiom string
    axiomINcells = cellstr(axiom'); 
    
    for j=1:nRules
        %the indexes of each 'before' string
        hit = strfind(axiom, rule(j).before);
        if (length(hit)>=1)
            for k=hit
                axiomINcells{k} = rule(j).after;
            end
        end
    end
    %now convert individual cells back to a string
    axiom=[];
    for j=1:length(axiomINcells)
        axiom = [axiom, axiomINcells{j}];
    end
end

% Now draw the string as turtle graphics
%Upper case (e.g. F or G) causes a line to be drawn in the current direction of the turtle
%Lower case causes a move with no draw
%angle +operator means turn left; -operator means turn right


%init the turtle stack
stkPtr = 1;

%set(gca,'xlim', [-5 5], 'ylim', [-5 5]);
figure(1)
clf
hold on

%init a sphere list
res=1/2;
[x,y,z]=meshgrid(-1-res:res:1+res, ...
    -1-res:res:1+res, -1-res:res:1+res);
w=sqrt(x.^2+y.^2+z.^2);
sphere=isosurface(x,y,z,w,1);
sc = 4;
sphere.vertices = [sphere.vertices(:,1)*.2,  ...
        sphere.vertices(:,2)*sc, ...
        sphere.vertices(:,3)*sc];
sphere.facecolor=[.5 .5 0];
allSpheres =[sphere];


%vertex counter
vNF = 1; 
vNG = 1;
for i=1:length(axiom)
    cmdT = axiom(i);
    switch cmdT
    case 'F'
        newxT = xT + lenF*hT(1);
        newyT = yT + lenF*hT(2);
        newzT = yT + lenF*hT(3);
        line([xT newxT],[yT newyT],[zT newzT], 'color',[.5 .4 0], 'linewidth',2);
        vertsF{vNF} = [xT yT zT ; newxT newyT newzT];
        vNF = vNF +1;
        xT = newxT;
        yT = newyT;
        zT = newzT;
        
    case 'G'
        newxT = xT + lenG*hT(1);
        newyT = yT + lenG*hT(2);
        newzT = yT + lenG*hT(3);
        line([xT newxT],[yT newyT],[zT newzT], 'color',[0 1 0], 'linewidth',2);
        vertsG{vNG} = [xT yT zT ; newxT newyT newzT];
        vNG = vNG +1;
        xT = newxT;
        yT = newyT;
        zT = newzT;
        
    case 'S'
        
        res=1/2;
        [x,y,z]=meshgrid(-1-res:res:1+res, ...
            -1-res:res:1+res, -1-res:res:1+res);
        w=sqrt(x.^2+y.^2+z.^2);
        sphere=isosurface(x,y,z,w,1);
        sc = .3;
        sphere.vertices = [sphere.vertices(:,1)*sc+xT,  ...
                sphere.vertices(:,2)*sc+yT, ...
                sphere.vertices(:,3)*sc+zT];
        sphere.facecolor = [1 0 0];
        sphere.facelighting = 'gouraud';
        allSpheres = combine(allSpheres,sphere);
        renderpatch(sphere);

        
    case '+'
        hT = hT * Rup;
        lT = lT * Rup;
        uT = uT * Rup;
    case '-'
        hT = hT * Rum;
        lT = lT * Rum;
        uT = uT * Rum;
        
    case '&'
        hT = hT * Rlp;
        lT = lT * Rlp;
        uT = uT * Rlp;
    case '^'
        hT = hT * Rlm;
        lT = lT * Rlm;
        uT = uT * Rlm;
        
    case '\'
        hT = hT * Rhp;
        lT = lT * Rhp;
        uT = uT * Rhp;
    case '/'
        hT = hT * Rhm;
        lT = lT * Rhm;
        uT = uT * Rhm;
        
    case '|'
        hT = hT * Rbk;
        lT = lT * Rbk;
        uT = uT * Rbk;

    case '[' %push the stack
        stack(stkPtr).xT = xT ;
        stack(stkPtr).yT = yT ;
        stack(stkPtr).zT = zT ;
        stack(stkPtr).hT = hT ;
        stack(stkPtr).lT = lT ;
        stack(stkPtr).uT = uT ;
        stkPtr = stkPtr +1 ;
    case ']' %pop the stack
        stkPtr = stkPtr -1 ;
        xT = stack(stkPtr).xT ;
        yT = stack(stkPtr).yT ;
        zT = stack(stkPtr).zT ;
        hT = stack(stkPtr).hT ;
        lT = stack(stkPtr).lT ;
        uT = stack(stkPtr).uT ;
    otherwise
        disp('error')
        return
    end
    %drawnow
end
daspect([1 1 1])
view(-70,70)
box on
rotate3d on

figure(2)
clf
daspect([1 1 1])
Nsides=8;
hsF=streamtube(vertsF,.3,[1,Nsides]);
set(hsF,'cdata',cat(3,.7*ones(2,Nsides+1), .7*ones(2,Nsides+1),zeros(2,Nsides+1)))

hsG=streamtube(vertsG,.2,[1,Nsides]);
set(hsG,'cdata',cat(3,zeros(2,Nsides+1), ones(2,Nsides+1),zeros(2,Nsides+1)))
shading interp;

renderpatch(allSpheres);

axis tight

view(-90,85);
camlight; lighting gouraud
%box on
rotate3d on



