# Script to extract DLLs from Visual C++ Redistributable packages
# Run this script as Administrator

# Enable error logging
$ErrorActionPreference = "Stop"
$LogFile = ".\QRBarcode_Release_extractdll\dll_extraction_log.txt"

# Ensure log directory exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# Clear existing log file
if (Test-Path $LogFile) {
    Clear-Content $LogFile
}

function Write-Log {
    param($Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage -Encoding UTF8
}

function Clean-Directory {
    param($Path)
    if (Test-Path $Path) {
        Write-Log "Cleaning directory: $Path"
        Remove-Item -Path "$Path\*" -Force -Recurse -ErrorAction SilentlyContinue
    } else {
        Write-Log "Creating directory: $Path"
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Download-WixTools {
    param($DestinationPath)
    
    Write-Log "Setting up WiX tools..."
    
    # Create parent directory if it doesn't exist
    $parentDir = Split-Path $DestinationPath -Parent
    if (!(Test-Path $parentDir)) {
        Write-Log "Creating tools directory: $parentDir"
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }
    
    # Create WiX directory
    if (!(Test-Path $DestinationPath)) {
        Write-Log "Creating WiX directory: $DestinationPath"
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Log "Downloading WiX tools..."
    $wixUrl = "https://github.com/wixtoolset/wix3/releases/download/wix3111rtm/wix311-binaries.zip"
    $wixZip = Join-Path $DestinationPath "wix.zip"
    
    try {
        # Download WiX tools
        Invoke-WebRequest -Uri $wixUrl -OutFile $wixZip -UseBasicParsing
        
        # Extract WiX tools
        Write-Log "Extracting WiX tools..."
        Expand-Archive -Path $wixZip -DestinationPath $DestinationPath -Force
        
        # Clean up zip
        Remove-Item $wixZip -Force
        Write-Log "WiX tools setup completed"
        
        return $DestinationPath
    }
    catch {
        Write-Log "ERROR: Failed to download/extract WiX tools: $($_.Exception.Message)"
        throw
    }
}

function Copy-And-Rename-DLL {
    param(
        $SourcePath,
        $DestinationDir,
        $Architecture
    )
    
    $fileName = [System.IO.Path]::GetFileName($SourcePath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    
    # List of essential DLLs we need
    $essentialDlls = @(
        "msvcp140",
        "vcruntime140",
        "vcruntime140_1"
    )
    
    # Check if this is an essential DLL
    $isEssential = $false
    foreach ($essentialDll in $essentialDlls) {
        if ($fileName -match "^$essentialDll(\.|\.|_)") {
            $isEssential = $true
            break
        }
    }
    
    if (-not $isEssential) {
        return $false
    }
    
    # Check for architecture suffix
    $patterns = @(
        "_$($Architecture.ToLower())`$",  # Ends with _amd64, _x86, _arm64
        "\.$($Architecture.ToLower())`$",  # Ends with .amd64, .x86, .arm64
        "_$($Architecture.ToLower())\.",   # Has _amd64., _x86., _arm64. before extension
        "\.$($Architecture.ToLower())\."   # Has .amd64., .x86., .arm64. before extension
    )
    
    $matched = $false
    foreach ($pattern in $patterns) {
        if ($fileName -match $pattern) {
            $matched = $true
            break
        }
    }
    
    if ($matched) {
        # Remove any architecture suffix and clean up the name
        $newName = $fileName -replace "_$($Architecture.ToLower())\.", "." `
                            -replace "\.$($Architecture.ToLower())\.", "." `
                            -replace "_$($Architecture.ToLower())`$", "" `
                            -replace "\.$($Architecture.ToLower())`$", ""
        
        # Ensure it ends with .dll
        if (-not $newName.EndsWith(".dll")) {
            $newName = "$newName.dll"
        }
        
        $destination = Join-Path $DestinationDir $newName
        Copy-Item -Path $SourcePath -Destination $destination -Force
        Write-Log "Copied and renamed '$fileName' to '$newName'"
        return $true
    }
    return $false
}

try {
    Write-Log "Starting DLL extraction process..."
    
    # Setup directories
    $BaseDir = ".\QRBarcode_Release_extractdll"
    $TempDir = "$BaseDir\temp_extract"
    $WixDir = "$BaseDir\tools\wix"
    $DllsDir = ".\QRBarcode_Release\dlls"
    
    # Create/clean directories
    Clean-Directory $TempDir
    
    # Ensure DLLs directories exist
    @("x64", "x86", "arm64") | ForEach-Object {
        Clean-Directory "$DllsDir\$_"
    }
    
    # Download and setup WiX tools if needed
    if (!(Test-Path (Join-Path $WixDir "dark.exe"))) {
        $WixDir = Download-WixTools $WixDir
    }
    $darkExe = Join-Path $WixDir "dark.exe"
    
    # Process each architecture
    $architectures = @(
        @{Name = "x64"; Exe = "VC_redist.x64.exe"; Pattern = "*_amd64"; Suffix = "amd64"},
        @{Name = "x86"; Exe = "VC_redist.x86.exe"; Pattern = "*_x86"; Suffix = "x86"},
        @{Name = "arm64"; Exe = "VC_redist.arm64.exe"; Pattern = "*_arm64"; Suffix = "arm64"}
    )
    
    foreach ($arch in $architectures) {
        $exePath = "$BaseDir\vc_redist\$($arch.Exe)"
        Write-Log "Processing $($arch.Name) redistributable..."
        
        if (Test-Path $exePath) {
            Write-Log "Extracting from: $exePath"
            
            # Create extraction directory for this architecture
            $archExtractPath = "$TempDir\$($arch.Name)"
            Clean-Directory $archExtractPath
            
            # Extract the bundle using dark.exe
            Write-Log "Extracting bundle with dark.exe..."
            $process = Start-Process -FilePath $darkExe -ArgumentList "-nologo", "-x", $archExtractPath, $exePath -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                # Look for the CAB file in the correct location
                $packagePath = Join-Path $archExtractPath "AttachedContainer\packages"
                $archFolders = Get-ChildItem -Path $packagePath -Directory -Filter $arch.Pattern
                
                foreach ($folder in $archFolders) {
                    $cabPath = Join-Path $folder.FullName "cab1.cab"
                    if (Test-Path $cabPath) {
                        Write-Log "Found CAB file: $cabPath"
                        
                        # Extract DLLs from CAB using expand.exe
                        Write-Log "Extracting DLLs from CAB..."
                        $cabExtractPath = "$archExtractPath\cab_content"
                        Clean-Directory $cabExtractPath
                        
                        $process = Start-Process -FilePath "expand.exe" -ArgumentList $cabPath, "-F:*", $cabExtractPath -Wait -PassThru -NoNewWindow
                        
                        if ($process.ExitCode -eq 0) {
                            # Copy and rename required DLLs
                            $dlls = Get-ChildItem -Path $cabExtractPath -Filter "*.dll" -Recurse
                            if ($dlls.Count -gt 0) {
                                Write-Log "Found $($dlls.Count) DLLs in CAB"
                                $copiedCount = 0
                                
                                foreach ($dll in $dlls) {
                                    if (Copy-And-Rename-DLL -SourcePath $dll.FullName -DestinationDir "$DllsDir\$($arch.Name)" -Architecture $arch.Suffix) {
                                        $copiedCount++
                                    }
                                }
                                
                                if ($copiedCount -eq 0) {
                                    Write-Log "WARNING: No matching DLLs found in CAB for $($arch.Name)"
                                } else {
                                    Write-Log "Successfully copied $copiedCount DLLs for $($arch.Name)"
                                }
                            } else {
                                Write-Log "WARNING: No DLLs found in CAB for $($arch.Name)"
                            }
                        } else {
                            Write-Log "ERROR: Failed to extract CAB for $($arch.Name)"
                        }
                    }
                }
            } else {
                Write-Log "ERROR: Bundle extraction failed for $($arch.Name)"
            }
        } else {
            Write-Log "ERROR: Redistributable not found: $exePath"
        }
    }
    
    # Clean up temp directory
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned up temporary directory"
    
    # Verify final results
    Write-Log "`nFinal DLL Count by Architecture:"
    @("x64", "x86", "arm64") | ForEach-Object {
        $archName = $_
        $count = (Get-ChildItem -Path "$DllsDir\$archName" -Filter "*.dll").Count
        Write-Log "$archName : $count DLLs"
        
        if ($count -gt 0) {
            Write-Log "Files in $archName directory:"
            Get-ChildItem -Path "$DllsDir\$archName" -Filter "*.dll" | ForEach-Object {
                Write-Log "  - $($_.Name)"
            }
        }
    }
    
    Write-Log "`nExtraction process completed successfully!"
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
