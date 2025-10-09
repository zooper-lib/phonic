# Silence Audio Tool

The silence audio tool is a utility script designed to replace the audio content of files with silence while preserving all metadata and tags. This is particularly useful for testing audio metadata handling without including copyrighted or sensitive audio content.

## Overview

The tool processes audio files and replaces their audio content with a short (0.5 second) silent track while preserving:

- All metadata tags (ID3v1, ID3v2, Vorbis comments, MP4 metadata, etc.)
- Original audio properties (sample rate, channels, bit rate)
- File format and codec settings

## Supported Formats

The tool supports the following audio formats:

- **MP3** (`.mp3`) - Preserves ID3v1 and ID3v2 tags
- **M4A** (`.m4a`) - Preserves MP4 metadata
- **AAC** (`.aac`) - Preserves metadata
- **FLAC** (`.flac`) - Preserves Vorbis comments
- **OGG** (`.ogg`) - Supports both Vorbis and Opus codecs
- **OPUS** (`.opus`) - Preserves Opus tags
- **WAV** (`.wav`) - Preserves RIFF metadata
- **MP4** (`.mp4`) - Preserves MP4 metadata (audio stream only)

## Prerequisites

Before using the tool, ensure you have the following installed:

- **FFmpeg** - Required for audio processing
- **FFprobe** - Included with FFmpeg, used for reading audio properties

### Installing FFmpeg

#### Linux (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install ffmpeg
```

#### Linux (Fedora)
```bash
sudo dnf install ffmpeg
```

#### macOS
```bash
brew install ffmpeg
```

#### Windows
Download from [ffmpeg.org](https://ffmpeg.org/download.html) or use a package manager like Chocolatey:
```powershell
choco install ffmpeg
```

## Usage

### Linux/macOS (Bash Script)

The bash script is located at `tools/silence_audio.sh`.

#### Process Directory (Batch Mode)

Process all audio files in the current directory:
```bash
./tools/silence_audio.sh
```

Process files in a specific directory:
```bash
./tools/silence_audio.sh -d /path/to/audio/files
# or using legacy positional argument:
./tools/silence_audio.sh /path/to/audio/files
```

#### Process Single File

Process a single file with auto-generated output name:
```bash
./tools/silence_audio.sh -i song.mp3
# Creates: song.silenced.mp3
```

Process a single file with custom output name:
```bash
./tools/silence_audio.sh -i song.mp3 -o silent_song.mp3
# Creates: silent_song.mp3
```

#### Help

Display usage information:
```bash
./tools/silence_audio.sh -h
# or
./tools/silence_audio.sh --help
```

### Windows (PowerShell Script)

The PowerShell script is located at `tools/silence_audio.ps1`.

#### Process Directory (Batch Mode)

Process all audio files in the current directory:
```powershell
.\tools\silence_audio.ps1
```

Process files in a specific directory:
```powershell
.\tools\silence_audio.ps1 -Root "C:\path\to\audio\files"
```

#### Process Single File

Process a single file with auto-generated output name:
```powershell
.\tools\silence_audio.ps1 -InputFile song.mp3
# Creates: song.silenced.mp3
```

Process a single file with custom output name:
```powershell
.\tools\silence_audio.ps1 -InputFile song.mp3 -OutputFile silent_song.mp3
# Creates: silent_song.mp3
```

#### Help

Display usage information:
```powershell
.\tools\silence_audio.ps1 -Help
```

## How It Works

1. **File Discovery**: The tool recursively searches the specified directory for supported audio files
2. **Property Extraction**: Uses FFprobe to read the original audio properties (sample rate, channels, bit rate)
3. **Silent Audio Generation**: Creates a 0.5-second silent audio track with matching properties
4. **Metadata Preservation**: 
   - For MP3: Extracts and preserves ID3v2 (header) and ID3v1 (footer) tags
   - For other formats: Uses FFmpeg's metadata mapping to preserve tags
5. **Output Creation**: Combines metadata with silent audio and saves as a new file
6. **File Naming**: Output files are named with `.silenced` suffix (e.g., `song.mp3` → `song.silenced.mp3`)

## Output

### Batch Mode (Directory Processing)

The tool creates new files with the `.silenced` suffix before the extension:

- `original.mp3` → `original.silenced.mp3`
- `track.m4a` → `track.silenced.m4a`
- `audio.flac` → `audio.silenced.flac`

Original files are **not modified** or deleted.

### Single File Mode

When processing a single file:

- **Without `-o`/`-OutputFile`**: Auto-generates output name with `.silenced` suffix
  - `song.mp3` → `song.silenced.mp3`
  
- **With `-o`/`-OutputFile`**: Uses the specified output path
  - Can be in the same directory or a different location
  - Can have any filename

## Progress Output

The tool provides progress feedback:

```
Found 15 audio files to process...
Processing (1/15): song1.mp3
Processing (2/15): song2.m4a
Processing (3/15): track.flac
...
Completed processing 15 files.
```

## Use Cases

### Testing Metadata Handling

Replace audio content in test files to avoid including copyrighted material in your repository:

```bash
# Batch mode: Create silenced versions of test fixtures
./tools/silence_audio.sh -d ./test/fixtures

# Single file mode: Process specific test file
./tools/silence_audio.sh -i ./test/fixtures/sample.mp3 -o ./test/fixtures/test.mp3
```

### Creating Sample Files

Generate lightweight sample files with real metadata but no audio content:

```bash
# Process a collection of files
./tools/silence_audio.sh -d ./samples

# Create a specific sample file
./tools/silence_audio.sh -i myalbum.mp3 -o samples/album_metadata_only.mp3
```

### Privacy Protection

Remove audio content while preserving metadata structure:

```bash
# Process sensitive recordings
./tools/silence_audio.sh -d ./recordings

# Process single sensitive file
./tools/silence_audio.sh -i interview.mp3 -o interview_metadata.mp3
```

### Custom Workflows

Single file mode enables integration with other tools:

```bash
# Process and move to different location
./tools/silence_audio.sh -i input/song.mp3 -o output/processed.mp3

# Use in a script
for file in *.mp3; do
    ./tools/silence_audio.sh -i "$file" -o "processed/${file}"
done
```

## Technical Details

### MP3 Format Handling

The MP3 processor uses a byte-level approach to preserve tags:

1. **ID3v2 Detection**: Checks for "ID3" header and calculates tag size using synchsafe integers
2. **Silent Audio**: Generates minimal MP3 with no ID3 tags
3. **ID3v1 Detection**: Checks last 128 bytes for "TAG" marker
4. **Assembly**: Combines ID3v2 + silent audio + ID3v1

### Other Formats

Other formats use FFmpeg's metadata mapping:

```bash
ffmpeg -f lavfi -i anullsrc=... -i original_file \
  -map 0:a -map_metadata 1 -c:a [codec] output_file
```

This approach:
- Maps silent audio from the null source (`-map 0:a`)
- Copies all metadata from the original file (`-map_metadata 1`)
- Uses the appropriate codec for the format

## Troubleshooting

### "Command not found: ffmpeg"

Install FFmpeg (see Prerequisites section above).

### "Permission denied"

On Linux/macOS, ensure the script is executable:
```bash
chmod +x ./tools/silence_audio.sh
```

### No output files created

Check that:
- FFmpeg is installed and in your PATH
- You have write permissions in the directory
- The input files are valid audio files

### Files skipped

The tool only processes supported audio formats. Unsupported files will show:
```
Warning: Skipped unsupported file: file.txt
```

## Limitations

- Only processes audio files (ignores video containers with audio tracks)
- Output files are always 0.5 seconds in duration
- Requires FFmpeg to be installed and available in PATH
- Does not modify original files (creates new files with `.silenced` suffix)

## Contributing

If you encounter issues or have suggestions for improving the silence audio tool, please open an issue or submit a pull request to the repository.
