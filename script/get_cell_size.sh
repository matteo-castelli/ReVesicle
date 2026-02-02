#!/bin/bash
# Usage: ./update_conf_from_xst.sh input.xst target.conf

xst_file="$1"
conf_file="$2"

# 1️⃣ Extract last line from .xst
last_line=$(tail -n 1 "$xst_file")

# 2️⃣ Read columns
read -r step a b c d e f g h i ox oy oz _ <<< "$last_line"

# 3️⃣ Prepare temporary replacement block
tmpblock=$(mktemp)
cat <<EOF > "$tmpblock"
cellBasisVector1 $a 0 0
cellBasisVector2 0 $e 0
cellBasisVector3 0 0 $i
cellOrigin $ox $oy $oz
EOF

# 4️⃣ Replace the 4 lines in the .conf file
# This assumes the .conf file ALREADY has lines starting with those keywords
# and replaces all of them in-place
awk -v repl="$(cat "$tmpblock")" '
BEGIN { split(repl, newlines, "\n") }
/^cellBasisVector1/ {print newlines[1]; next}
/^cellBasisVector2/ {print newlines[2]; next}
/^cellBasisVector3/ {print newlines[3]; next}
/^cellOrigin/       {print newlines[4]; next}
{print}
' "$conf_file" > "${conf_file}.tmp" && mv "${conf_file}.tmp" "$conf_file"

rm "$tmpblock"

echo "✅ Updated $conf_file with cell info from $xst_file"

