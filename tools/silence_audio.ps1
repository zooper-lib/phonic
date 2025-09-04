param([string]$Root = ".")

$files = @(Get-ChildItem -Path $Root -Recurse -File -Include *.mp3, *.m4a, *.aac, *.flac, *.ogg, *.opus, *.wav)
Write-Host "Found $($files.Count) audio files to process..."

$processedCount = 0
$errorCount = 0

$files | ForEach-Object {
	$inputFile = $_.FullName
	$fileName = $_.Name
	$ext = $_.Extension.ToLowerInvariant()
	
	Write-Host "Processing ($($processedCount + 1)/$($files.Count)): $fileName" -ForegroundColor Cyan
	
	try {
		switch ($ext) {
			".mp3" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
				
					# Read original file as bytes
					$originalBytes = [System.IO.File]::ReadAllBytes($inputFile)
				
					# Create minimal silent MP3
					$fileId = [System.IO.Path]::GetRandomFileName()
					$silentPath = Join-Path $PWD "tmp_silent_$fileId.mp3"
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -c:a libmp3lame -b:a $bitRate -write_id3v1 0 -id3v2_version 0 "$silentPath"
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
					$outputPath = Join-Path $PWD "tmp_$fileId.mp3"
					[System.IO.File]::WriteAllBytes($outputPath, $outputStream.ToArray())
					$outputStream.Dispose()
				
					Remove-Item $silentPath -ErrorAction SilentlyContinue
					if (Test-Path $outputPath) { Move-Item -Force $outputPath ($inputFile -replace '\.mp3$', '.silenced.mp3') }
				}
			}
			".m4a" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
					$fileId = [System.IO.Path]::GetRandomFileName()
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a aac -b:a $bitRate -movflags +faststart "tmp_$fileId.m4a"
					if (Test-Path "tmp_$fileId.m4a") { Move-Item -Force "tmp_$fileId.m4a" ($inputFile -replace '\.m4a$', '.silenced.m4a') }
				}
			}
			".aac" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 4) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "192000" }
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a aac -b:a $bitRate "tmp.aac"
					if (Test-Path "tmp.aac") { Move-Item -Force "tmp.aac" ($inputFile -replace '\.aac$', '.silenced.aac') }
				}
			}
			".flac" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 3) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a flac -compression_level 5 "tmp.flac"
					if (Test-Path "tmp.flac") { Move-Item -Force "tmp.flac" ($inputFile -replace '\.flac$', '.silenced.flac') }
				}
			}
			".ogg" {
				$codec = ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$inputFile"
				if ($codec -eq "opus") {
					$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
					if ($props.Count -ge 4) {
						$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }; $bitRate = if ($props[3]) { $props[3] } else { "96000" }
						ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a libopus -b:a $bitRate "tmp.opus"
						if (Test-Path "tmp.opus") { Move-Item -Force "tmp.opus" ($inputFile -replace '\.ogg$', '.silenced.opus') }
					}
				}
				else {
					$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout, bit_rate -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
					if ($props.Count -ge 4) {
						$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }
						ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a libvorbis -qscale:a 5 "tmp.ogg"
						if (Test-Path "tmp.ogg") { Move-Item -Force "tmp.ogg" ($inputFile -replace '\.ogg$', '.silenced.ogg') }
					}
				}
			}
			".wav" {
				$props = @(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate, channels, channel_layout -show_entries format=duration -of default=nw=1:nk=1 "$inputFile")
				if ($props.Count -ge 3) {
					$sampleRate = $props[0]; $channelLayout = if ($props[2]) { $props[2] } else { "stereo" }
					ffmpeg -y -f lavfi -t 0.5 -i "anullsrc=r=$sampleRate`:cl=$channelLayout" -i "$inputFile" -map 0:a -map_metadata 1 -c:a pcm_s16le "tmp.wav"
					if (Test-Path "tmp.wav") { Move-Item -Force "tmp.wav" ($inputFile -replace '\.wav$', '.silenced.wav') }
				}
			}
			default {
				Write-Warning "Skipped unsupported: $fileName"
			}
		}  # End switch
	}
 catch {
		Write-Error "Error processing $fileName`: $($_.Exception.Message)"
		$script:errorCount++
	}
 finally {
		$script:processedCount++
	}
}

Write-Host "`nCompleted processing $processedCount files." -ForegroundColor Green
if ($errorCount -gt 0) {
	Write-Host "$errorCount files had errors." -ForegroundColor Red
}
