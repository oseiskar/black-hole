#!/bin/bash
htlatex physics.tex "myconfig, imgdir:images/, charset=utf-8" " -cunihtf -utf8"
pdflatex physics.tex
cp physics.html ../../black-hole/docs/
cp physics.css ../../black-hole/docs/
cp physics-extras.css ../../black-hole/docs/
cp physics.pdf ../../black-hole/docs/