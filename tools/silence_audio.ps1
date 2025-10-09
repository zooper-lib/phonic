param(
	[string]$Root = ".",
	[string]$InputFile = "",
	[string]$OutputFile = "",
	[switch]$Help
)

# Display usage information
function Show-Usage {
	Write-Host "Usage: .\silence_audio.ps1 [OPTIONS]"
	Write-Host ""
	Write-Host "Options:"
	Write-Host "  -InputFile FILE    Process a single input file"
	Write-Host "  -OutputFile FILE   Output file path (requires -InputFile)"
	Write-Host "  -Root DIR          Process all audio files in directory (default: current directory)"
	Write-Host "  -Help              Display this help message"
	Write-Host ""
	Write-Host "Examples:"
	Write-Host "  .\silence_audio.ps1 -Root 'C:\audio'                    # Process all files in directory"
	Write-Host "  .\silence_audio.ps1 -InputFile song.mp3 -OutputFile silent.mp3   # Process single file with custom output"
	Write-Host "  .\silence_audio.ps1 -InputFile song.mp3                          # Process single file (auto-named output)"
	exit 0
}

if ($Help) {
	Show-Usage
}

# Validate arguments
$singleFileMode = -not [string]::IsNullOrEmpty($InputFile)

if ($singleFileMode) {
	if (-not (Test-Path $InputFile)) {
		Write-Error "Input file '$InputFile' not found"
		exit 1
	}
	if ($OutputFile -and (Test-Path $OutputFile -PathType Container)) {
		Write-Error "Output path '$OutputFile' is a directory"
		exit 1
	}
}

# Function to process a single file
function Process-AudioFile {
	param(
		[string]$inputFile,
		[string]$outputFile = ""
	)
	
	$fileName = Split-Path $inputFile -Leaf
	$ext = [System.IO.Path]::GetExtension($fileName).ToLowerInvariant().TrimStart('.')
	
	# Auto-generate output filename if not provided
	if ([string]::IsNullOrEmpty($outputFile)) {
		$baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
		$directory = Split-Path $inputFile -Parent
		$outputFile = Join-Path $directory "$baseName.silenced.$ext"
	}
	
	try {
		switch ($ext) {
			"mp3" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
				
					# Read original file as bytes
					$originalBytes = [System.IO.File]::ReadAllBytes($inputFile)
				
					# Create minimal silent MP3
					$fileId = [System.IO.Path]::GetRandomFileName()
					$silentPath = Join-Path $PWD "tmp_silent_$fileId.mp3"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -c:a libmp3lame -b:a $bitRate -write_id3v1 0 -id3v2_version 0 "$silentPath" 2>$null
					$silentBytes = [System.IO.File]::ReadAllBytes($silentPath)
				
					# Extract ID3v2 tag from original (if present)
					$id3v2Size = 0
					$id3v1Size = 0
				
					# Check for ID3v2 header (first 3 bytes: "ID3")
					if ($originalBytes.Length -gt 10 -and $originalBytes[0] -eq 0x49 -and $originalBytes[1] -eq 0x44 -and $originalBytes[2] -eq 0x33) {
						# Calculate ID3v2 size (synchsafe integer at bytes 6-9)
						$id3v2Size = (($originalBytes[6] -band 0x7F) -shl 21) -bor (($originalBytes[7] -band 0x7F) -shl 14) -bor (($originalBytes[8] -band 0x7F) -shl 7) -bor ($originalBytes[9] -band 0x7F)
						$id3v2Size += 10  # Add header size
					}
				
					# Check for ID3v1 tag (last 128 bytes: starts with "TAG")
					if ($originalBytes.Length -gt 128) {
						$tagPos = $originalBytes.Length - 128
						if ($originalBytes[$tagPos] -eq 0x54 -and $originalBytes[$tagPos + 1] -eq 0x41 -and $originalBytes[$tagPos + 2] -eq 0x47) {
							$id3v1Size = 128
						}
					}
				
					# Combine: ID3v2 + silent audio + ID3v1
					$outputStream = [System.IO.MemoryStream]::new()
				
					if ($id3v2Size -gt 0) {
						$outputStream.Write($originalBytes, 0, $id3v2Size)
					}
					$outputStream.Write($silentBytes, 0, $silentBytes.Length)
					if ($id3v1Size -gt 0) {
						$id3v1Start = $originalBytes.Length - $id3v1Size
						$outputStream.Write($originalBytes, $id3v1Start, $id3v1Size)
					}
				
					# Write final file
					$tempPath = Join-Path $PWD "tmp_$fileId.mp3"
					[System.IO.File]::WriteAllBytes($tempPath, $outputStream.ToArray())
					$outputStream.Dispose()
				
					Remove-Item $silentPath -ErrorAction SilentlyContinue
					if (Test-Path $tempPath) { 
						Move-Item -Force $tempPath $outputFile
						Write-Host "Created: $outputFile" -ForegroundColor Green
						return $true
					}
				}
			}
			"m4a" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
					$fileId = [System.IO.Path]::GetRandomFileName()
					$tempPath = "tmp_$fileId.m4a"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a aac -b:a $bitRate -movflags +faststart "$tempPath" 2>$null
					if (Test-Path $tempPath) { 
						Move-Item -Force $tempPath $outputFile
						Write-Host "Created: $outputFile" -ForegroundColor Green
						return $true
					}
				}
			}
			"aac" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
					$tempPath = "tmp.aac"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a aac -b:a $bitRate "$tempPath" 2>$null
					if (Test-Path $tempPath) { 
						Move-Item -Force $tempPath $outputFile
						Write-Host "Created: $outputFile" -ForegroundColor Green
						return $true
					}
				}
			}
			"flac" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 3) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }
					$tempPath = "tmp.flac"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a flac -compression_level 5 "$tempPath" 2>$null
					if (Test-Path $tempPath) { 
						Move-Item -Force $tempPath $outputFile
						Write-Host "Created: $outputFile" -ForegroundColor Green
						return $true
					}
				}
			}
			"ogg" {
				$codec = ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$inputFile"
				if ($codec -eq "opus") {
					$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
					if ($props.Count -ge 4) {
						$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "96000" }
						$tempPath = "tmp.opus"
						ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a libopus -b:a $bitRate "$tempPath" 2>$null
						if (Test-Path $tempPath) { 
							Move-Item -Force $tempPath $outputFile
							Write-Host "Created: $outputFile" -ForegroundColor Green
							return $true
						}
					}
				}
				else {
					$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
					if ($props.Count -ge 4) {
						$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }
						$tempPath = "tmp.ogg"
						ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a libvorbis -qscale:a 5 "$tempPath" 2>$null
						if (Test-Path $tempPath) { 
							Move-Item -Force $tempPath $outputFile
							Write-Host "Created: $outputFile" -ForegroundColor Green
							return $true
						}
					}
				}
			}
			"wav" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 3) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }
					$tempPath = "tmp.wav"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a pcm_s16le "$tempPath" 2>$null
					if (Test-Path $tempPath) { 
						Move-Item -Force $tempPath $outputFile
						Write-Host "Created: $outputFile" -ForegroundColor Green
						return $true
					}
				}
			}
			"mp4" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
					$fileId = [System.IO.Path]::GetRandomFileName()
					$tempPath = "tmp_$fileId.mp4"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a aac -b:a $bitRate -movflags +faststart "$tempPath" 2>$null
					if (Test-Path $tempPath) { 
						Move-Item -Force $tempPath $outputFile
						Write-Host "Created: $outputFile" -ForegroundColor Green
						return $true
					}
				}
			}
			default {
				Write-Error "Unsupported file format: $ext"
				return $false
			}
		}  # End switch
		
		Write-Error "Failed to process $fileName"
		return $false
	}
	catch {
		Write-Error "Error processing $fileName`: $($_.Exception.Message)"
		return $false
	}
}

# Main execution
if ($singleFileMode) {
	# Process single file
	Write-Host "Processing: $(Split-Path $InputFile -Leaf)" -ForegroundColor Cyan
	if (Process-AudioFile -inputFile $InputFile -outputFile $OutputFile) {
		Write-Host "`nCompleted successfully." -ForegroundColor Green
		exit 0
	}
	else {
		Write-Host "`nProcessing failed." -ForegroundColor Red
		exit 1
	}
}
else {
	# Process directory (original batch mode)
	$files = @(Get-ChildItem -Path $Root -Recurse -File -Include *.mp3, *.m4a, *.aac, *.flac, *.ogg, *.opus, *.wav, *.mp4)
	Write-Host "Found $($files.Count) audio files to process..."

	$processedCount = 0
	$errorCount = 0

	$files | ForEach-Object {
		$inputFile = $_.FullName
		$fileName = $_.Name
		
		$processedCount++
		Write-Host "Processing ($processedCount/$($files.Count)): $fileName" -ForegroundColor Cyan
		
		if (-not (Process-AudioFile -inputFile $inputFile)) {
			$errorCount++
		}
	}

	Write-Host "`nCompleted processing $processedCount files." -ForegroundColor Green
	if ($errorCount -gt 0) {
		Write-Host "$errorCount files had errors." -ForegroundColor Red
	}
}
