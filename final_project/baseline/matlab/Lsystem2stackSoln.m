
%
%L-system
%2D

clear all
clf

%Rules-- Cell array {1,x} is the xth string to be replaced
%      -- {2,x}

rule(1).before = 'F';
rule(1).after = 'FF';

rule(2).before = 'G';
rule(2).after = 'F[+G][-G]F[+G][-G]FH';%  

rule(3).before = 'H';
rule(3).after = 'F[+H][-H]F[+H][-H]FG';%  


nRules = length(rule);

%angle: +operator means turn left; -operator means turn right
delta = 27.5; %degrees

%length of the line segments corresponding to the symbols F and G
lenF = 1;
lenG = 1;

%starting seed
axiom = 'G';

%number of repititions
nReps = 3;

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

%Init the turtle
xT = 0;
yT = 0;
aT = 0;
da = delta/57.29 ; %convert to radians

%init the turtle stack
stkPtr = 1;

%set(gca,'xlim', [-5 5], 'ylim', [-5 5]);
hold on

for i=1:length(axiom)
    cmdT = axiom(i);
    switch cmdT
    case 'F'
        newxT = xT + lenF*cos(aT);
        newyT = yT + lenF*sin(aT);
        %line([xT newxT], [yT newyT]);
        line([yT newyT], [xT newxT],'color',[.3 .3 0], 'linewidth',2);
        xT = newxT;
        yT = newyT;
    case 'G'
        newxT = xT + lenG*cos(aT);
        newyT = yT + lenG*sin(aT);
        %line([xT newxT], [yT newyT]);
        line([yT newyT], [xT newxT],'color','g', 'linewidth',2,'marker','d');
        xT = newxT;
        yT = newyT;
    case 'H'
        newxT = xT + lenG*cos(aT);
        newyT = yT + lenG*sin(aT);
        %line([xT newxT], [yT newyT]);
        line([yT], [xT],'color','r','marker','o','markerfacecolor','r');
        xT = newxT;
        yT = newyT;
    case '+'
        aT = aT + da;
    case '-'
        aT = aT - da;
    case '[' %push the stack
        stack(stkPtr).xT = xT ;
        stack(stkPtr).yT = yT ;
        stack(stkPtr).aT = aT ;
        stkPtr = stkPtr +1 ;
    case ']' %pop the stack
        stkPtr = stkPtr -1 ;
        xT = stack(stkPtr).xT ;
        yT = stack(stkPtr).yT ;
        aT = stack(stkPtr).aT ;
    otherwise
        disp('error')
        return
    end
    %drawnow
end

daspect([1,1,1])





