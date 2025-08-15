#!/bin/bash
COMMON="-Isrc -i -g -checkaction=C"
ldc -of=./build/utils/build_font.bin src/utils/font_builder.d $COMMON
#ldc -of=build/gen_campaign.bin src/utils/gen_campaign.d $COMMON
