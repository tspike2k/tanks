#!/bin/bash
ldc2 -of=./build/utils/build_font.bin -g -betterC -Isrc -Isrc/utils ./src/utils/font_builder.d ./src/fmt.d ./src/files.d ./src/memory.d ./src/math.d ./src/assets.d

