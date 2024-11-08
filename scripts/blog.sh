#!/usr/bin/env bash
#
repo="https://github.com/adam-coates/adam-coates.github.io"
blogdir=~/adam-coates.github.io/posts
green='\e[32m'
red='\e[31m'
purple='\033[0;35m'
clear='\e[0m'

bkplct=/mnt/g/blog/

if [ ! -d $bkplct ];then
    bkplct=/mnt/g/notes/blog/
fi

ColorGreen(){
    echo -ne $green$1$clear
}

ColorRed(){
    echo -ne $red$1$clear
}

ColorPurple(){
    echo -ne $purple$1$clear
}

get_info() {
	read -p "Enter a title: " title

    read -p "Enter a description: " description
}
function spinner() {
    # Spinner characters
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local charwidth=3

    # Make sure we use non-unicode character type locale 
    # (that way it works for any locale as long as the font supports the characters)
    local LC_CTYPE=C

    # Run the command passed as arguments and capture its PID
    "$@" &
    local pid=$!

    local i=0
    tput civis # Cursor invisible
    while kill -0 $pid 2>/dev/null; do
        local i=$(((i + $charwidth) % ${#spin}))
        printf "\e[32m%s\e[m" "${spin:$i:$charwidth}"  # Green font color
        printf "\033[1D"  # Move the cursor back one position
        sleep .1
    done
    tput cnorm # Cursor visible
    wait $pid # Capture exit code
    return $?
}

create_file() {
    date=$(date +"%Y-%m-%d")
	timestamp="$(date +"%Y-%m-%d-%H:%m")"
    localdir="$blogdir/$date/"
	mkdir "$localdir"
    # Cd into the directory
	cd "$localdir" || exit
	# Create the file in the specified directory
	touch "$localdir/index.qmd"


	# Format the title by removing dashes
	title="${title//-/ }"

	# set up the yaml frontmatter
	echo "---" >>"$localdir/index.qmd"
    echo "title: \"$title\"" >>"$localdir/index.qmd"
    echo "description: \"$description\"" >>"$localdir/index.qmd"
    echo "#image: \"preview.png\"" >>"$localdir/index.qmd"
    echo "comments:">>"$localdir/index.qmd"
    echo "  giscus:">>"$localdir/index.qmd"
    echo "    repo: \"adam-coates/adam-coates.github.io\"">>"$localdir/index.qmd"
    echo "    mapping: \"title\"">>"$localdir/index.qmd"
    echo "date: \"$date\"" >>"$localdir/index.qmd"
    echo "categories: []">>"$localdir/index.qmd"
    echo "draft: false #  setting this to `true` will prevent your post from appearing on your listing page until you're ready" >>"$localdir/index.qmd"
    echo "#css: style.css">>"$localdir/index.qmd"
    echo "---" >>"$localdir/index.qmd" 


	# Open the file in Neovim
	nvim '+ normal 2GzzA' "$localdir/index.qmd"
}
function check_directories {
    dir1="$1"
    dir2="$2"
    differences_found=false

    # Find all files in dir1
    files=$(find "$dir1" -type f)

    # Iterate over each file in dir1
    for file in $files; do
        # Get corresponding file path in dir2
        file_in_dir2="${file/$dir1/$dir2}"

        # Check if the file exists in dir2
        if [ ! -f "$file_in_dir2" ]; then
            echo "File $file_in_dir2 does not exist in $dir2"
            differences_found=true
            continue
        fi

        # Use cmp command to check if files differ
        if ! cmp -s "$file" "$file_in_dir2"; then
            echo "Files differ:"
            echo "  $file"
            echo "  $file_in_dir2"

            # Calculate the checksums of the files
            checksum1=$(md5sum "$file" | awk '{ print $1 }')
            checksum2=$(md5sum "$file_in_dir2" | awk '{ print $1 }')

            # Compare the checksums
            if [ "$checksum1" != "$checksum2" ]; then
                echo "File contents are different."
                differences_found=true
            fi
        fi
    done

    if [ "$differences_found" = true ]; then
        return 1
    else
        return 0
    fi
}
case "$1" in 
    write)
        get_info

        create_file

        ;;

    backup)

        echo -ne "$(ColorRed 'Backing up now ... ')"; echo ""
        spinner cp -rf  ~/adam-coates.github.io/ $bkplct
        echo -ne "$(ColorGreen 'Files now backed up \u2714')"; echo ""
        ;;

    pub)
        read -p "Enter a commit message: " commitmessage
        cd $blogdir/..
        git add .
        git commit -m "$commitmessage"
        git push -u origin main

        ;;

    preview)
        cd "$blogdir/.."
        quarto preview

        ;;

    *)

    echo "Please enter either write|backup|pub|preview"
    ;;

esac
if [[ "$1" != "backup" ]]; then
echo -ne "Would you like to back up? $(ColorGreen 'yes')/$(ColorRed 'no')
"
read -r check
check=$(echo "$check" | tr '[:upper:]' '[:lower:]')
if [[ $check == "yes" || $check == "y" ]]; then
    echo -ne "$(ColorPurple 'Checking if needing to back up ')"; spinner sleep 5; echo -ne "$(ColorGreen '\u2714')"; echo ""
    if ! check_directories $blogdir /mnt/g/blog/adam-coates.github.io/posts/; then
        echo -ne "$(ColorRed 'Different files detected backing up now ... ')"; echo ""
        spinner cp -rf  ~/adam-coates.github.io/ $bkplct
        echo -ne "$(ColorGreen 'Files now backed up \u2714')"; echo ""
    else
        echo ""
        echo -ne "$(ColorGreen 'Files are already backed up \u2714')"; echo ""
    fi
    elif [[ $check == "no" || $check == "n" ]]; then
    exit
else
    echo "Invalid choice. Please enter 'yes' or 'no'. Exiting now."
 fi
fi






