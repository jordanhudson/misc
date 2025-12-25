#!/usr/bin/env bash

set -euo pipefail

# Default values
DELETE_ORIGINAL=false
CREATE_MKV=false
FILE_PATH=""
MOVIES_PATH="/mnt/wd/torrents/movies"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--create-mkv)
            CREATE_MKV=true
            shift
            ;;
        -d|--delete-original)
            DELETE_ORIGINAL=true
            shift
            ;;
        -f|--file)
            FILE_PATH="$2"
            shift 2
            ;;
        -p|--path)
            MOVIES_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "By default, this script reports VFR MP4 files without converting them."
            echo ""
            echo "Options:"
            echo "  -f, --file PATH          Process a single file"
            echo "  -c, --create-mkv         Actually create MKV files (default: report only)"
            echo "  -d, --delete-original    Delete original MP4 after successful conversion"
            echo "  -p, --path PATH          Directory to scan (default: $MOVIES_PATH)"
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            exit 1
            ;;
    esac
done

# Function to process a single file
process_file() {
    local file="$1"

    # Get frame rate info
    local avg_fps
    local r_fps

    avg_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
    r_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")

    # Check if we got valid frame rates
    if [[ -z "$avg_fps" || -z "$r_fps" ]]; then
        echo "Skipping (could not read frame rates): $file"
        return
    fi

    # Check if they don't match (indicating VFR)
    if [[ "$avg_fps" != "$r_fps" ]]; then
        local output="${file%.mp4}.mkv"

        # Check if mkv already exists
        if [[ -f "$output" ]]; then
            echo "Skipping (already exists): $output"
        else
            if [[ "$CREATE_MKV" == true ]]; then
                echo "Converting VFR file: $file"
                if ffmpeg -i "$file" -c:a copy -c:v libx265 -preset ultrafast -crf 18 -r 24 "$output" 2>&1; then
                    # Check if conversion was successful
                    if [[ $? -eq 0 ]]; then
                        if [[ "$DELETE_ORIGINAL" == true ]]; then
                            echo "Conversion successful, deleting original: $file"
                            rm "$file"
                        else
                            echo "Conversion successful, keeping original: $file"
                        fi
                    else
                        echo "Conversion failed, keeping original: $file"
                    fi
                else
                    echo "Conversion failed, keeping original: $file"
                fi
            else
                echo "VFR file needs MKV: $file"
            fi
        fi
    fi
}

# Main logic
if [[ -n "$FILE_PATH" ]]; then
    # Process single file
    if [[ ! -f "$FILE_PATH" ]]; then
        echo "Error: File not found: $FILE_PATH"
        exit 1
    fi

    if [[ ! "$FILE_PATH" =~ \.mp4$ ]]; then
        echo "Error: File must be an MP4"
        exit 1
    fi

    process_file "$FILE_PATH"
else
    # Process all files in directory
    if [[ ! -d "$MOVIES_PATH" ]]; then
        echo "Error: Directory not found: $MOVIES_PATH"
        exit 1
    fi

    # Find all MP4 files recursively
    while IFS= read -r -d '' file; do
        process_file "$file"
    done < <(find "$MOVIES_PATH" -type f -name "*.mp4" -print0)
fi
