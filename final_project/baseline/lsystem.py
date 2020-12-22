# ////////////////////////////////////////////////////////////////////////
#   LSYSTEM.PY
#       Baseline Python code
#       Computes and graphs entire L-Systems
#   (Priya Kattappurath, Michael Rivera, Caitlin Stanton)
# ////////////////////////////////////////////////////////////////////////

import pygame
import math
import random
import time

# other = variables
# F,A = move n forward
# - = turn left by angle
# + = turn right by angle

rules = {}

# Have to comment out rules, axioms, and angles for all L-Systems but one
# The following are the seven L-Systems for our project

# rules['X'] = 'X+YF+'  # Dragon curve
# rules['Y'] = '-FX-Y'
# axiom = 'FX'
# angle = 90

# rules['X'] = 'YF+XF+Y'  # Sierpinski arrowhead (1)
# rules['Y'] = 'XF-YF-X'
# axiom = 'YF'
# angle = 60

# rules['A'] = '+F-A-F+'  # Sierpinski arrowhead (2)
# rules['F'] = '-A+F+A-'
# axiom = 'A'
# angle = 60

# rules['F'] = 'F+F--F+F'  # Koch curve
# axiom = 'F'
# angle = 60

# rules['F'] = 'F-F++F-F'  # Koch snowflake
# axiom = 'F++F++F'
# angle = 60

# rules['F'] = 'F+FF++F+F'  # Cross
# axiom = 'F+F+F+F'
# angle = 90

# rules['F'] = 'F-F+F'  # Tessellated triangle
# axiom = 'F+F+F'
# angle = 120

iterations = 12  # number of iterations
step = 7  # step size / line length

angleoffset = 90

size = width, height = 1920, 1080  # display with/height
pygame.init()  # init display
screen = pygame.display.set_mode(size)  # open screen

# startpos = 100, height - 225
# startpos = 50, height / 2 - 50
# startpos = width / 2, height / 2
startpos = width / 2 - 200, height / 2
# startpos = 100, height / 2
# startpos = 10, 10


def applyRule(input):
    output = ""
    for rule, result in rules.items(
    ):  # applying the rule by checking the current char against it
        if (input == rule):
            output = result  # Rule 1
            break
        else:
            output = input  # else ( no rule set ) output = the current char -> no rule was applied
    return output


def processString(oldStr):
    newstr = ""
    for character in oldStr:
        newstr = newstr + applyRule(character)  # build the new string
    return newstr


def createSystem(numIters, axiom):
    startString = axiom
    endString = ""
    for i in range(numIters):  # iterate with appling the rules
        print("Iteration: {0}".format(i))
        endString = processString(startString)
        startString = endString
    return endString


def polar_to_cart(theta, r, offx, offy):
    x = r * math.cos(math.radians(theta))
    y = r * math.sin(math.radians(theta))
    return tuple([x + y for x, y in zip((int(x), int(y)), (offx, offy))])


def cart_to_polar(x, y):
    return (math.degrees(math.atan(y / x)),
            math.sqrt(math.pow(x, 2) + math.pow(y, 2)))


def drawTree(input, oldpos):
    a = 0  # angle
    i = 0  # counter for processcalculation
    processOld = 0  # old process
    newpos = oldpos
    color = (255, 255, 255)
    linesize = 1
    for character in input:  # process for drawing the l-system by writing the string to the screen

        i += 1  # print process in percent
        process = i * 100 / len(input)
        if not process == processOld:
            # print(process, "%")
            processOld = process

        if character == 'A':  # magic happens here
            newpos = polar_to_cart(a + angleoffset, step, *oldpos)
            pygame.draw.line(screen, color, oldpos, newpos, linesize)
            oldpos = newpos
        elif character == 'F':
            newpos = polar_to_cart(a + angleoffset, step, *oldpos)
            pygame.draw.line(screen, color, oldpos, newpos, linesize)
            oldpos = newpos
        elif character == '+':
            a += angle
        elif character == '-':
            a -= angle


if __name__ == '__main__':
    start = time.time()
    tree = (createSystem(iterations, axiom))
    # print(len(tree))
    drawTree(tree, startpos)
    end = time.time()
    pygame.display.flip()
    pygame.image.save(screen, "screenshot.png")
    print("Finished in " + str(end - start) + " seconds")

    while (1):
        pass
        exit()  # uncommand