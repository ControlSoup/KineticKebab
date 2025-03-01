rm -rf .zig-cache && 
clear && 
zig build && 
cp zig-out/bin/kinetic_kebab kinetic_kebab_api/ && 
cp zig-out/lib/libkinetic_kebab.so kinetic_kebab_api/ &&
pip install .