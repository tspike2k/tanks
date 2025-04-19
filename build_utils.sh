#!/bin/bash
ldc2 -of=./build/utils/build_font.bin -betterC -Isrc ./src/utils/font_builder.d ./src/fmt.d ./src/files.d ./src/memory.d

