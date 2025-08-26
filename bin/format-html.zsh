#!/bin/zsh

# Find all .html files in htdocs/ and its subdirectories, then process them
find htdocs/ -type f -name "*.html" | while read -r file; do
	if [[ -f "$file" ]]; then
		echo "Processing $file..."
		# Pipe file through grammartool format-html and use sponge to write back
		bin/grammartool format-html "$file" > "$file".new
		if cmp -s "$file" "$file".new; then
			rm "$file".new;
		else
			mv "$file".new "$file";
		fi
	fi
done
