#!/bin/bash
cd "$SRCROOT"
git add .
git commit -m 'Force commit' > ~/Desktop/debug_git.txt 2>&1
