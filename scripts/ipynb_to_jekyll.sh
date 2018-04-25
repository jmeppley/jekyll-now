#!/bin/bash
#
# Convert Jupyter notebook files (in _jupyter folder) to markdown files (in
# _posts folder).
#
# Arguments: 
# $1 filename (full path to ipynb file)
# 
set -euo pipefail
IFS=$'\n\t'

# Generate a filename with today's date.
IPYNB_FILE=$1
FILE_DATE=${2:-$(date +%Y-%m-%d)}

POST_NAME=$(basename ${IPYNB_FILE%%.ipynb})
FILENAME=${FILE_DATE}-${POST_NAME}

# Jupyter will put all the assets associated with the notebook in a folder with
# this naming convention.
# The folder will be in the same output folder as the generated markdown file.
FOLDERNAME=$FILENAME"_files"

# Do the conversion.
jupyter nbconvert $IPYNB_FILE --to markdown --output-dir=./_posts --output=$FILENAME

# Move the images from the jupyter-generated folder to the images folder.
echo "Moving images..."
mv ./_posts/$FOLDERNAME/* ./images

# Remove the now empty folder.
rmdir ./_posts/$FOLDERNAME

# Modify the md file for blogging
FILEPATH=./_posts/$FILENAME.md
mv $FILEPATH $FILEPATH.raw

# Add a header for jekyll
echo "---
layout: post
---
" > $FILEPATH

# Go through the markdown file and rewrite image paths.
# NB: this sed command works on OSX, it might need to be tweaked for other
# platforms.
echo "Rewriting image paths..."
sed -e "s/$FOLDERNAME/\/images/g" $FILEPATH.raw >> $FILEPATH

# Remove the original
rm $FILEPATH.raw

# Remove backup file created by sed command.
rm ./_posts/$FILENAME.md.tmp

# Check if the conversion has left a blank line at the top of the file. 
# (Sometimes it does and this messes up formatting.)
firstline=$(head -n 1 ./_posts/$FILENAME.md)
if [ "$firstline" = "" ]; then
    # If it has, get rid of it.
    tail -n +2 "./_posts/$FILENAME.md" > "./_posts/$FILENAME.tmp" \
        && mv "./_posts/$FILENAME.tmp" "./_posts/$FILENAME.md"
fi

echo "Done converting."
