#!/usr/bin/env bash
# Plays the whole tutorial at every common window shape (phone, tablet, PC, ultrawide, squat) and fails when Rex's
# bubble or the chapter-end panel leaves the screen or covers the spotlight. Screenshots land in $OUT/<shape>/.
#   GODOT=/path/to/godot tools/test-formfactors.sh [out_dir]
GODOT="${GODOT:-godot}"
OUT="${1:-./formfactor-shots}"
SHAPES="phone_tall:360x800 phone_16x9:540x960 tablet_portrait:768x1024 tablet_landscape:1024x768 pc_small:800x600 pc_16x9:1280x720 ultrawide:1260x540 squat:900x400"
fail=0
for s in $SHAPES; do
  name="${s%%:*}"; res="${s##*:}"
  mkdir -p "$OUT/$name"
  if "$GODOT" --path apps/mobile --resolution "$res" -- --tutorialshot="$OUT/$name/t.png" > "$OUT/$name.log" 2>&1; then
    echo "ok   $name ($res)"
  else
    echo "FAIL $name ($res) - see $OUT/$name.log"; fail=1
  fi
done
exit $fail
