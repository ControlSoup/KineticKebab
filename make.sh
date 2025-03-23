rm -rf .zig-cache && 
clear && 
zig build && 
cp zig-out/bin/kinetic_kebab kinetic_kebab/ && 
cp zig-out/lib/libkinetic_kebab.so kinetic_kebab/ &&
pip install . --break-system-packages