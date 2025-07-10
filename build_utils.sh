#!/bin/bash
COMMON="-Isrc -i -g -checkaction=C"
#ldc2 -of=./build/utils/build_font.bin -g -betterC -Isrc -Isrc/utils ./src/utils/font_builder.d ./src/fmt.d ./src/files.d ./src/memory.d ./src/math.d ./src/assets.d
ldc -of=build/gen_campaign.bin src/utils/gen_campaign.d $COMMON
