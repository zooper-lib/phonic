#!/usr/bin/env bash

# Display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --input FILE       Process a single input file"
    echo "  -o, --output FILE      Output file path (requires -i)"
    echo "  -d, --directory DIR    Process all audio files in directory (default: current directory)"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d /path/to/audio/files          # Process all files in directory"
    echo "  $0 -i song.mp3 -o silent.mp3        # Process single file with custom output"
    echo "  $0 -i song.mp3                      # Process single file (auto-named output)"
    exit 1
}

# Parse command line arguments
INPUT_FILE=""
OUTPUT_FILE=""
ROOT="."
SINGLE_FILE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_FILE="$2"
            SINGLE_FILE_MODE=true
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--directory)
            ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            # Support legacy positional argument for directory
            ROOT="$1"
            shift
            ;;
    esac
done

# Validate arguments
if [ "$SINGLE_FILE_MODE" = true ]; then
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file '$INPUT_FILE' not found"
        exit 1
    fi
    if [ -n "$OUTPUT_FILE" ] && [ -d "$OUTPUT_FILE" ]; then
        echo "Error: Output path '$OUTPUT_FILE' is a directory"
        exit 1
    fi
fi

# Function to process a single file
process_file() {
    local input_file="$1"
    local output_file="$2"
    local file_name=$(basename "$input_file")
    local ext="${file_name##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # Auto-generate output filename if not provided
    if [ -z "$output_file" ]; then
        output_file="${input_file%.*}.silenced.$ext"
    fi
    
    case "$ext" in
        mp3)
            # Get audio properties
            mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout,bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ ${#props[@]} -ge 4 ]; then
                sample_rate="${props[0]}"
                channel_layout="${props[2]:-stereo}"
                bit_rate="${props[3]:-192000}"
                
                # Generate unique file ID
                file_id=$(mktemp -u XXXXXXXX)
                silent_path="/tmp/tmp_silent_$file_id.mp3"
                
                # Create minimal silent MP3
                ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -c:a libmp3lame -b:a "$bit_rate" -write_id3v1 0 -id3v2_version 0 "$silent_path" >/dev/null 2>&1
                
                if [ -f "$silent_path" ]; then
                    # Read original file
                    original_bytes=$(cat "$input_file")
                    silent_bytes=$(cat "$silent_path")
                    
                    # Extract ID3v2 tag size (if present)
                    id3v2_size=0
                    id3v1_size=0
                    
                    # Check for ID3v2 header (first 3 bytes: "ID3")
                    header=$(head -c 3 "$input_file" 2>/dev/null)
                    if [ "$header" = "ID3" ]; then
                        # Calculate ID3v2 size (synchsafe integer at bytes 6-9)
                        id3v2_bytes=$(head -c 10 "$input_file" | tail -c 4 | od -An -tu1)
                        read -r b6 b7 b8 b9 <<< "$id3v2_bytes"
                        id3v2_size=$(( ((b6 & 0x7F) << 21) | ((b7 & 0x7F) << 14) | ((b8 & 0x7F) << 7) | (b9 & 0x7F) + 10 ))
                    fi
                    
                    # Check for ID3v1 tag (last 128 bytes: starts with "TAG")
                    file_size=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file" 2>/dev/null)
                    if [ $file_size -gt 128 ]; then
                        tag_header=$(tail -c 128 "$input_file" | head -c 3)
                        if [ "$tag_header" = "TAG" ]; then
                            id3v1_size=128
                        fi
                    fi
                    
                    # Combine: ID3v2 + silent audio + ID3v1
                    temp_output="/tmp/tmp_$file_id.mp3"
                    
                    if [ $id3v2_size -gt 0 ]; then
                        head -c $id3v2_size "$input_file" > "$temp_output"
                        cat "$silent_path" >> "$temp_output"
                    else
                        cp "$silent_path" "$temp_output"
                    fi
                    
                    if [ $id3v1_size -gt 0 ]; then
                        tail -c $id3v1_size "$input_file" >> "$temp_output"
                    fi
                    
                    # Clean up and move final file
                    rm -f "$silent_path"
                    if [ -f "$temp_output" ]; then
                        mv -f "$temp_output" "$output_file"
                        echo "Created: $output_file"
                        return 0
                    fi
                fi
            fi
            ;;
            
        m4a)
            mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout,bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ ${#props[@]} -ge 4 ]; then
                sample_rate="${props[0]}"
                channel_layout="${props[2]:-stereo}"
                bit_rate="${props[3]:-192000}"
                file_id=$(mktemp -u XXXXXXXX)
                temp_output="/tmp/tmp_$file_id.m4a"
                
                ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a aac -b:a "$bit_rate" -movflags +faststart "$temp_output" >/dev/null 2>&1
                
                if [ -f "$temp_output" ]; then
                    mv -f "$temp_output" "$output_file"
                    echo "Created: $output_file"
                    return 0
                fi
            fi
            ;;
            
        aac)
            mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout,bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ ${#props[@]} -ge 4 ]; then
                sample_rate="${props[0]}"
                channel_layout="${props[2]:-stereo}"
                bit_rate="${props[3]:-192000}"
                file_id=$(mktemp -u XXXXXXXX)
                temp_output="/tmp/tmp_$file_id.aac"
                
                ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a aac -b:a "$bit_rate" "$temp_output" >/dev/null 2>&1
                
                if [ -f "$temp_output" ]; then
                    mv -f "$temp_output" "$output_file"
                    echo "Created: $output_file"
                    return 0
                fi
            fi
            ;;
            
        flac)
            mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ ${#props[@]} -ge 3 ]; then
                sample_rate="${props[0]}"
                channel_layout="${props[2]:-stereo}"
                file_id=$(mktemp -u XXXXXXXX)
                temp_output="/tmp/tmp_$file_id.flac"
                
                ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a flac -compression_level 5 "$temp_output" >/dev/null 2>&1
                
                if [ -f "$temp_output" ]; then
                    mv -f "$temp_output" "$output_file"
                    echo "Created: $output_file"
                    return 0
                fi
            fi
            ;;
            
        ogg)
            codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ "$codec" = "opus" ]; then
                mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout,bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
                
                if [ ${#props[@]} -ge 4 ]; then
                    sample_rate="${props[0]}"
                    channel_layout="${props[2]:-stereo}"
                    bit_rate="${props[3]:-96000}"
                    file_id=$(mktemp -u XXXXXXXX)
                    temp_output="/tmp/tmp_$file_id.opus"
                    
                    ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a libopus -b:a "$bit_rate" "$temp_output" >/dev/null 2>&1
                    
                    if [ -f "$temp_output" ]; then
                        mv -f "$temp_output" "$output_file"
                        echo "Created: $output_file"
                        return 0
                    fi
                fi
            else
                mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout,bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
                
                if [ ${#props[@]} -ge 4 ]; then
                    sample_rate="${props[0]}"
                    channel_layout="${props[2]:-stereo}"
                    file_id=$(mktemp -u XXXXXXXX)
                    temp_output="/tmp/tmp_$file_id.ogg"
                    
                    ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a libvorbis -qscale:a 5 "$temp_output" >/dev/null 2>&1
                    
                    if [ -f "$temp_output" ]; then
                        mv -f "$temp_output" "$output_file"
                        echo "Created: $output_file"
                        return 0
                    fi
                fi
            fi
            ;;
            
        wav)
            mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ ${#props[@]} -ge 3 ]; then
                sample_rate="${props[0]}"
                channel_layout="${props[2]:-stereo}"
                file_id=$(mktemp -u XXXXXXXX)
                temp_output="/tmp/tmp_$file_id.wav"
                
                ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a pcm_s16le "$temp_output" >/dev/null 2>&1
                
                if [ -f "$temp_output" ]; then
                    mv -f "$temp_output" "$output_file"
                    echo "Created: $output_file"
                    return 0
                fi
            fi
            ;;
            
        mp4)
            mapfile -t props < <(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,channel_layout,bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$input_file" 2>/dev/null)
            
            if [ ${#props[@]} -ge 4 ]; then
                sample_rate="${props[0]}"
                channel_layout="${props[2]:-stereo}"
                bit_rate="${props[3]:-192000}"
                file_id=$(mktemp -u XXXXXXXX)
                temp_output="/tmp/tmp_$file_id.mp4"
                
                ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sample_rate:cl=$channel_layout" -i "$input_file" -map 0:a -map_metadata 1 -c:a aac -b:a "$bit_rate" -movflags +faststart "$temp_output" >/dev/null 2>&1
                
                if [ -f "$temp_output" ]; then
                    mv -f "$temp_output" "$output_file"
                    echo "Created: $output_file"
                    return 0
                fi
            fi
            ;;
            
        *)
            echo "Error: Unsupported file format: $ext"
            return 1
            ;;
    esac
    
    echo "Error: Failed to process $input_file"
    return 1
}

# Main execution
if [ "$SINGLE_FILE_MODE" = true ]; then
    # Process single file
    echo "Processing: $(basename "$INPUT_FILE")"
    if process_file "$INPUT_FILE" "$OUTPUT_FILE"; then
        echo -e "\n\033[32mCompleted successfully.\033[0m"
        exit 0
    else
        echo -e "\n\033[31mProcessing failed.\033[0m"
        exit 1
    fi
else
    # Process directory (original batch mode)
    # Find all audio files
    mapfile -t files < <(find "$ROOT" -type f \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.opus" -o -iname "*.wav" -o -iname "*.mp4" \))

    total_files=${#files[@]}
    echo "Found $total_files audio files to process..."

    processed_count=0
    error_count=0

    for input_file in "${files[@]}"; do
        file_name=$(basename "$input_file")
        
        ((processed_count++))
        echo -e "\033[36mProcessing ($processed_count/$total_files): $file_name\033[0m"
        
        if ! process_file "$input_file" ""; then
            ((error_count++))
        fi
    done

    echo -e "\n\033[32mCompleted processing $processed_count files.\033[0m"
    if [ $error_count -gt 0 ]; then
        echo -e "\033[31m$error_count files had errors.\033[0m"
    fi
fi

