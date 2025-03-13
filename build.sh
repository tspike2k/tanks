#!/bin/bash
ldc2 -i -Isrc -g ./src/app.d -of=./build/app.bin -betterC
#dmd -i -Isrc ./src/app.d -of=./build/app.bin -betterC
