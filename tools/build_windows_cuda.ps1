#!/usr/bin/env powershell

<#
.SYNOPSIS
    Build Decord with CUDA/NVDEC support on Windows

.DESCRIPTION
    This script automates the build process for Decord with CUDA and NVDEC hardware acceleration support on Windows.
    It handles dependency installation, CUDA toolkit setup, and compilation.

.PARAMETER CudaVersion
    CUDA toolkit version to use (default: "11.8")

.PARAMETER BuildType
    CMake build type (default: "Release")

.PARAMETER Generator
    Visual Studio generator to use (default: "Visual Studio 17 2022")

.PARAMETER Architecture
    Target architecture (default: "x64")

.PARAMETER SkipDependencies
    Skip dependency installation (default: $false)

.PARAMETER EnableTests
    Enable building tests (default: $false)

.EXAMPLE
    .\build_windows_cuda.ps1
    Build with default settings

.EXAMPLE
    .\build_windows_cuda.ps1 -CudaVersion "12.0" -BuildType "Debug"
    Build with CUDA 12.0 in Debug mode

.NOTES
    Requirements:
    - Windows 10/11
    - Visual Studio 2019 or later with C++ build tools
    - NVIDIA GPU with compute capability 3.5 or higher
    - PowerShell 5.1 or later
#>

param(
    [string]$CudaVersion = "12.6",
    [string]$BuildType = "Release",
    [string]$Generator = "Visual Studio 17 2022",
    [string]$Architecture = "x64",
    [switch]$SkipDependencies = $false,
    [switch]$EnableTests = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Function to install Chocolatey if not present
function Install-Chocolatey {
    if (-not (Test-Command "choco")) {
        Write-ColorOutput "Installing Chocolatey..." "Yellow"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        refreshenv
    } else {
        Write-ColorOutput "Chocolatey already installed" "Green"
    }
}

# Function to install dependencies
function Install-Dependencies {
    Write-ColorOutput "Installing dependencies..." "Yellow"
    
    # Install Chocolatey
    Install-Chocolatey
    
    # Install required packages
    $packages = @(
        "git",
        "cmake",
        "ffmpeg",
        "python3",
        "visualstudio2022buildtools"
    )
    
    foreach ($package in $packages) {
        Write-ColorOutput "Installing $package..." "Cyan"
        try {
            choco install $package -y --no-progress
        } catch {
            Write-ColorOutput "Warning: Failed to install $package via Chocolatey" "Yellow"
        }
    }
    
    # Install Python packages
    Write-ColorOutput "Installing Python packages..." "Cyan"
    python -m pip install --upgrade pip
    python -m pip install wheel numpy cython setuptools
    
    refreshenv
}

# Function to install CUDA toolkit
function Install-CudaToolkit {
    param([string]$Version)
    
    Write-ColorOutput "Installing CUDA Toolkit $Version..." "Yellow"
    
    # Check if CUDA is already installed
    if ($env:CUDA_PATH -and (Test-Path "$env:CUDA_PATH\bin\nvcc.exe")) {
        Write-ColorOutput "CUDA already installed at $env:CUDA_PATH" "Green"
        return
    }
    
    try {
        choco install cuda --version=$Version -y --no-progress
        refreshenv
        
        # Set CUDA_PATH if not set
        if (-not $env:CUDA_PATH) {
            $cudaPaths = @(
                "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$Version",
                "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($Version.Split('.')[0]).$($Version.Split('.')[1])"
            )
            
            foreach ($path in $cudaPaths) {
                if (Test-Path $path) {
                    $env:CUDA_PATH = $path
                    [Environment]::SetEnvironmentVariable("CUDA_PATH", $path, "User")
                    break
                }
            }
        }
        
        Write-ColorOutput "CUDA Toolkit installed successfully" "Green"
    } catch {
        Write-ColorOutput "Failed to install CUDA Toolkit: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to install NVIDIA Video Codec SDK headers
function Install-VideoCodecSDK {
    Write-ColorOutput "Installing NVIDIA Video Codec SDK headers..." "Yellow"
    
    if (-not $env:CUDA_PATH) {
        throw "CUDA_PATH environment variable not set"
    }
    
    try {
        # Download nv-codec-headers
        $url = "https://github.com/FFmpeg/nv-codec-headers/archive/refs/heads/master.zip"
        $zipPath = "nv-codec-headers.zip"
        
        Write-ColorOutput "Downloading Video Codec SDK headers..." "Cyan"
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        
        # Extract headers
        Expand-Archive -Path $zipPath -DestinationPath "." -Force
        
        # Copy headers to CUDA include directory
        $includeSource = "nv-codec-headers-master\include\*"
        $includeDestination = "$env:CUDA_PATH\include\"
        
        Write-ColorOutput "Copying headers to $includeDestination" "Cyan"
        Copy-Item -Path $includeSource -Destination $includeDestination -Recurse -Force
        
        # Cleanup
        Remove-Item $zipPath -Force
        Remove-Item "nv-codec-headers-master" -Recurse -Force
        
        # Verify nvcuvid.lib exists
        $nvcuvidLib = "$env:CUDA_PATH\lib\x64\nvcuvid.lib"
        if (Test-Path $nvcuvidLib) {
            Write-ColorOutput "nvcuvid.lib found at $nvcuvidLib" "Green"
        } else {
            Write-ColorOutput "Warning: nvcuvid.lib not found at $nvcuvidLib" "Yellow"
            Write-ColorOutput "NVDEC functionality may not work properly" "Yellow"
        }
        
        Write-ColorOutput "Video Codec SDK headers installed successfully" "Green"
    } catch {
        Write-ColorOutput "Failed to install Video Codec SDK headers: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to configure and build
function Build-Decord {
    param(
        [string]$BuildType,
        [string]$Generator,
        [string]$Architecture,
        [bool]$EnableTests
    )
    
    Write-ColorOutput "Configuring and building Decord..." "Yellow"
    
    # Ensure we're in the correct directory
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $rootDir = Split-Path -Parent $scriptDir
    Set-Location $rootDir
    
    # Create build directory
    $buildDir = "build" 
    if (Test-Path $buildDir) {
        Write-ColorOutput "Removing existing build directory..." "Cyan"
        Remove-Item $buildDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $buildDir | Out-Null
    Set-Location $buildDir
    
    try {
        # Configure CMake
        Write-ColorOutput "Configuring CMake..." "Cyan"
        $cmakeArgs = @(
            "..",
            "-DUSE_CUDA=ON",
            "-DCMAKE_BUILD_TYPE=$BuildType",
            "-G", "$Generator",
            "-A", $Architecture
        )
        
        if ($EnableTests) {
            $cmakeArgs += "-DBUILD_TESTS=ON"
        }
        
        & cmake @cmakeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "CMake configuration failed"
        }
        
        # Build
        Write-ColorOutput "Building Decord..." "Cyan"
        & cmake --build . --config $BuildType --parallel
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
        
        Write-ColorOutput "C++ library built successfully" "Green"
        
        # Build Python wheel
        Write-ColorOutput "Building Python wheel..." "Cyan"
        Set-Location "../python"
        
        & python setup.py build_ext --inplace
        if ($LASTEXITCODE -ne 0) {
            throw "Python build_ext failed"
        }
        
        & python setup.py bdist_wheel
        if ($LASTEXITCODE -ne 0) {
            throw "Python wheel build failed"
        }
        
        Write-ColorOutput "Python wheel built successfully" "Green"
        
        # Test installation
        Write-ColorOutput "Testing installation..." "Cyan"
        $wheelFile = Get-ChildItem "dist\*.whl" | Select-Object -First 1
        if ($wheelFile) {
            & python -m pip install $wheelFile.FullName --force-reinstall
            if ($LASTEXITCODE -eq 0) {
                & python -c "import decord; print('Decord version:', decord.__version__); print('CUDA support:', hasattr(decord, 'gpu'))"
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Installation test passed" "Green"
                } else {
                    Write-ColorOutput "Warning: Installation test failed" "Yellow"
                }
            } else {
                Write-ColorOutput "Warning: Failed to install wheel" "Yellow"
            }
        }
        
    } catch {
        Write-ColorOutput "Build failed: $($_.Exception.Message)" "Red"
        throw
    } finally {
        Set-Location $rootDir
    }
}

# Function to verify system requirements
function Test-SystemRequirements {
    Write-ColorOutput "Checking system requirements..." "Yellow"
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        throw "Windows 10 or later is required"
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 or later is required"
    }
    
    # Check for NVIDIA GPU
    try {
        $gpus = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
        if (-not $gpus) {
            Write-ColorOutput "Warning: No NVIDIA GPU detected. CUDA functionality may not work." "Yellow"
        } else {
            Write-ColorOutput "NVIDIA GPU detected: $($gpus[0].Name)" "Green"
        }
    } catch {
        Write-ColorOutput "Warning: Could not detect GPU information" "Yellow"
    }
    
    Write-ColorOutput "System requirements check completed" "Green"
}

# Main execution
try {
    Write-ColorOutput "=== Decord Windows CUDA Build Script ===" "Magenta"
    Write-ColorOutput "CUDA Version: $CudaVersion" "White"
    Write-ColorOutput "Build Type: $BuildType" "White"
    Write-ColorOutput "Generator: $Generator" "White"
    Write-ColorOutput "Architecture: $Architecture" "White"
    Write-ColorOutput "Skip Dependencies: $SkipDependencies" "White"
    Write-ColorOutput "Enable Tests: $EnableTests" "White"
    Write-ColorOutput "" "White"
    
    # Check system requirements
    Test-SystemRequirements
    
    # Install dependencies if not skipped
    if (-not $SkipDependencies) {
        Install-Dependencies
        Install-CudaToolkit -Version $CudaVersion
        Install-VideoCodecSDK
    } else {
        Write-ColorOutput "Skipping dependency installation" "Yellow"
    }
    
    # Build Decord
    Build-Decord -BuildType $BuildType -Generator $Generator -Architecture $Architecture -EnableTests $EnableTests
    
    Write-ColorOutput "" "White"
    Write-ColorOutput "=== Build completed successfully! ===" "Green"
    Write-ColorOutput "" "White"
    Write-ColorOutput "Next steps:" "White"
    Write-ColorOutput "1. The Python wheel is available in python/dist/" "White"
    Write-ColorOutput "2. Install with: pip install python/dist/*.whl" "White"
    Write-ColorOutput "3. Test with: python -c 'import decord; print(decord.__version__)'" "White"
    
} catch {
    Write-ColorOutput "" "White"
    Write-ColorOutput "=== Build failed! ===" "Red"
    Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
    Write-ColorOutput "" "White"
    Write-ColorOutput "Troubleshooting tips:" "White"
    Write-ColorOutput "1. Ensure Visual Studio 2019/2022 with C++ tools is installed" "White"
    Write-ColorOutput "2. Check that CUDA Toolkit is properly installed" "White"
    Write-ColorOutput "3. Verify NVIDIA GPU drivers are up to date" "White"
    Write-ColorOutput "4. Run as Administrator if permission issues occur" "White"
    
    exit 1
}