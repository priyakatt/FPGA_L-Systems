
%
%L-system
%2D

clear all
clf


%Rules-- Cell array {1,x} is the xth string to be replaced
%      -- {2,x}

rule(1).before = 'F';
rule(1).after = 'F[+F]F[-F]F';

rule(2).before = 'F';
rule(2).after = 'F[+F[F]-F]F'; 

rule(3).before = 'F';
rule(3).after = 'F[-F]F'; 

rule(4).before = 'F'; %F
rule(4).after = 'F[+FF]F[-FF]F';

rule(5).before = 'F';
rule(5).after = 'FF[+F+]F[-F-]FF';

rule(6).before = 'F';
rule(6).after = 'F[+F]F[-F]F';

nRules = length(rule);

%ruleList = [1  2  5 6];

%angle: +operator means turn left; -operator means turn right
delta = 25; %degrees

%length of the line segments corresponding to the symbols F and G
lenF = 1;
lenG = 1;

%number of repititions
nReps = 3;
 
%do 4 different cases
for p=1:9
    subplot(3,3,p)
    daspect([1 1 1]);
    %starting seed
    axiom = 'F';
    
    ruleList = fix(nRules*rand(nReps,1))+1
    
    for i=1:nReps
        
        %one character/cell, with indexes the same as original axiom string
        axiomINcells = cellstr(axiom'); 
        
        %choose a rule based on the iteration number
        j = ruleList(i);
        %the indexes of the chosen 'before' string
        hit = strfind(axiom, rule(j).before);
        if (length(hit)>=1)
            for k=hit
                axiomINcells{k} = rule(j).after;
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
            line([yT newyT], [xT newxT],'color',[.3 .3 0], 'linewidth',1);
            xT = newxT;
            yT = newyT;
        case 'G'
            newxT = xT + lenG*cos(aT);
            newyT = yT + lenG*sin(aT);
            line([yT newyT], [xT newxT],'color','g', 'linewidth',2);
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
        end %case
        %drawnow
    end %for axiom
    title(num2str(ruleList'));
end %the 4 subplots





