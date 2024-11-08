#!/bin/bash

# Enhanced menu function with color support
menu() {
    local prompt="$1" outvar="$2" selected_outvar="$3"
    shift 3
    local options=("$@")
    local count=${#options[@]}
    local cur=0
    local esc=$(echo -en "\e")
    local selected=() # Array to track "keep" (green) or "delete" (red)
    for ((i=0; i<count; i++)); do
        selected[i]=0 # Default to no action
    done

    printf "$prompt\n"
    while true; do
        # Render menu options with colors
        for ((i=0; i<count; i++)); do
            if [ "$i" -eq "$cur" ]; then
                if [ "${selected[i]}" -eq 1 ]; then
                    echo -e " > \e[32m${options[i]}\e[0m (keep)" # Green for keep
                elif [ "${selected[i]}" -eq 2 ]; then
                    echo -e " > \e[31m${options[i]}\e[0m (delete)" # Red for delete
                else
                    echo -e " > \e[7m${options[i]}\e[0m" # Highlight current option
                fi
            else
                if [ "${selected[i]}" -eq 1 ]; then
                    echo -e "   \e[32m${options[i]}\e[0m (keep)" # Green for keep
                elif [ "${selected[i]}" -eq 2 ]; then
                    echo -e "   \e[31m${options[i]}\e[0m (delete)" # Red for delete
                else
                    echo "   ${options[i]}"
                fi
            fi
        done

        # Read user input (single character, no need for Enter)
        IFS= read -rsn1 key

        if [[ $key == $esc ]]; then
            read -rsn2 -t 0.1 key # Read remaining escape sequence characters
            if [[ $key == '[A' ]]; then
                ((cur--)); ((cur < 0)) && cur=$((count - 1))
            elif [[ $key == '[B' ]]; then
                ((cur++)); ((cur >= count)) && cur=0
            fi
        elif [[ $key == "k" ]]; then
            selected[cur]=1 # Mark as keep
        elif [[ $key == "d" ]]; then
            selected[cur]=2 # Mark as delete
        elif [[ $key == "p" ]]; then
            # Show preview of the selected note using 'bat'
            local selected_note="${options[$cur]}"
            local note_path="$notes_dir/$selected_note"
            echo -e "\nPreviewing note: $selected_note"
            bat "$note_path"  # Show the content of the selected note with 'bat'
            echo -e "\nPress any key to continue..."
            read -rsn1 # Wait for user to press a key to continue
        elif [[ $key == "" ]]; then
            break
        fi
        echo -en "\e[${count}A" # Move cursor up to re-render
    done

    # Output the final selection
    printf -v "$outvar" "${options[$cur]}"
    eval "$selected_outvar=(${selected[@]})"
}
# Function to extract and clean the tag from a YAML-formatted note
extract_tag() {
    local file="$1"
    # Using awk to get the tag line and sed to clean it up
    local tag=$(awk '/tags:/{getline; print; exit}' "$file" | sed -e 's/^ *- *//' -e 's/^ *//;s/ *$//')
    echo "$tag"
}

# Function to find the appropriate folder based on the cleaned tag (handles spaces)
find_folder() {
    local tag="$1"
    # Use find with iname to handle spaces and case insensitivity
    local folder=$(find "$HOME/notes" -type d -iname "$tag" 2>/dev/null | head -n 1)
    echo "$folder"
}

# Main script to manage notes
notes_dir="$HOME/notes/Inbox"
notes=("$notes_dir"/*) # Array of all notes in the Inbox
note_names=()

if [ ! -e "${notes[0]}" ]; then
    echo "No files in Inbox."
    exit 0
fi

for note in "${notes[@]}"; do
    note_names+=("$(basename "$note")")
done

selected_note=""
declare -a actions
menu "Select a note to keep (k), delete (d), or preview (p). Press ENTER when done:" selected_note actions "${note_names[@]}"

confirm=""
menu "Confirm your choices (ok to apply, cancel to discard):" confirm _ "ok" "cancel"

if [[ $confirm == "ok" ]]; then
    for ((i=0; i<${#actions[@]}; i++)); do
        note_file="${notes[i]}"
        if [[ ${actions[i]} -eq 1 ]]; then
            tag=$(extract_tag "$note_file")
            if [ -n "$tag" ]; then
                folder=$(find_folder "$tag")
                if [ -n "$folder" ]; then
                    mv "$note_file" "$folder"
                    echo "Moved '${note_names[i]}' to '$folder'"
                else
                    echo "Folder for tag '$tag' not found. Skipping '${note_names[i]}'."
                fi
            else
                echo "No tag found in '${note_names[i]}'. Skipping."
            fi
        elif [[ ${actions[i]} -eq 2 ]]; then
            rm -f "${note_file}"
            echo "Deleted '${note_names[i]}'"
        fi
    done
else
    echo "No changes made."
fi
