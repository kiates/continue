# This is used in a task in .vscode/tasks.json when on windows
# Start developing with:
# - Run Task -> Install Dependencies
# - Debug -> Extension

# Capture the initial directory
$InitialDirectory = Get-Location

# Define the log file name and path using the initial directory
$LogFileName = "install-dependencies.log"
$LogFilePath = Join-Path -Path $InitialDirectory -ChildPath $LogFileName

# Clear the log file if it exists, otherwise create a new empty file
if (Test-Path -Path $LogFilePath) {
    Clear-Content -Path $LogFilePath
} else {
    New-Item -Path $LogFilePath -ItemType File | Out-Null
}

# Function to log messages to a file
function Log-Message {
    param (
        [string]$Message,
        [string]$LogFile = $LogFilePath,  # Default log file path
        [int]$LinesBefore = 0,  # Default number of empty lines before the message
        [int]$LinesAfter = 0,    # Default number of empty lines after the message
        [string]$HeaderChar = "",  # Character to use for the header
        [int]$HeaderLength = 80  # Length of the header line
    )

    # Get timestamp for the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $timestamp_prefix = "[$timestamp]"
    $logEntry = "$timestamp_prefix $Message"

    # Add empty lines before the log entry
    for ($i = 0; $i -lt $LinesBefore; $i++) {
        Add-Content -Path $LogFile -Value "$timestamp_prefix"
    }

    # Add header if specified
    if ($HeaderChar -ne "") {
        $headerLine = $HeaderChar * $HeaderLength
        Add-Content -Path $LogFile -Value "$timestamp_prefix $headerLine"
    }

    # Add the actual log entry
    Add-Content -Path $LogFile -Value $logEntry

    # Add empty lines after the log entry
    for ($i = 0; $i -lt $LinesAfter; $i++) {
        Add-Content -Path $LogFile -Value "$timestamp_prefix"
    }
}

# Function to execute a command and log its output
function Execute-Command {
    param (
        [scriptblock]$Command,
        [string]$LogFile = $LogFilePath  # Use the initial directory path
    )
    # Execute the command and capture output
    $output = & $Command 2>&1
    $bufferedOutput = @()

    # Log and optionally display each line
    $output | ForEach-Object {
        Log-Message $_ -LogFile $LogFile  # Log each line immediately
        $bufferedOutput += $_  # Buffer for potential console display
    }

    # Only display buffered output in console if command fails
    if ($LASTEXITCODE -ne 0) {
        Log-Message "Command failed: $($Command.ToString()) with exit code $LASTEXITCODE" -LogFile $LogFile
        $bufferedOutput | ForEach-Object { Write-Host $_ }
        return $false
    }

    return $true
}

# Check dependencies. Everything needs node and npm

Write-Host "Checking for dependencies that may require manual installation..." -ForegroundColor White
Log-Message "Checking for dependencies that may require manual installation..." -HeaderChar "#"

$cargo = (get-command cargo -ErrorAction SilentlyContinue)
if ($null -eq $cargo) {
    Write-Host "  - Not Found " -ForegroundColor Red -NoNewLine
    Write-Host "cargo"
    Log-Message "  - Not Found cargo"
} else {
    Write-Host "  - Found " -ForegroundColor Green -NoNewLine
    $cargoVersion = & cargo --version
    Write-Host $cargoVersion
    Log-Message "  - Found cargo: $cargoVersion"
}

$node  = (get-command node -ErrorAction SilentlyContinue)
if ($null -eq $node) {
    Write-Host "  - Not Found " -ForegroundColor Red -NoNewLine
    Write-Host "node"
    Log-Message "  - Not Found node"
} else {
    Write-Host "  - Found " -ForegroundColor Green -NoNewLine
    Write-Host "node "  -NoNewLine
    $nodeVersion = & node --version
    Write-Host $nodeVersion
    Log-Message "  - Found node: $nodeVersion"
}

if ($null -eq $cargo) {
    Write-Host "`n...`n"
    Write-Host "Cargo`n" -ForegroundColor  White
    Write-Host "Doesn't appear to be installed or is not on your Path."
    Write-Host "For how to install cargo see:" -NoNewline
    Write-Host "https://doc.rust-lang.org/cargo/getting-started/installation.html" -ForegroundColor Green
    Log-Message "Cargo doesn't appear to be installed or is not on your Path. For how to install cargo see: https://doc.rust-lang.org/cargo/getting-started/installation.html"
}

if ($null -eq $node) {
    Write-Host "`n...`n"
    Write-Host "NodeJS`n" -ForegroundColor White
    Write-Host "Doesn't appear to be installed or is not on your Path."
    Write-Host "On most Windows systems you can install node using: " -NoNewLine
    Write-Host "winget install OpenJS.NodeJS.LTS " -ForegroundColor Green
    Write-Host "After installing restart your Terminal to update your Path."
    Write-Host "Alternatively see: " -NoNewLine
    Write-Host "https://nodejs.org/" -ForegroundColor Yellow
    Log-Message "NodeJS doesn't appear to be installed or is not on your Path. On most Windows systems you can install node using: winget install OpenJS.NodeJS.LTS. After installing restart your Terminal to update your Path. Alternatively see: https://nodejs.org/"
}

if (($null -eq $cargo) -or ($null -eq $node)) {
    Log-Message "Some dependencies that may require installation could not be found. Exiting."
    return "`nSome dependencies that may require installation could not be found. Exiting"
}

# Install dependencies for different parts
$sections = @(
    @{ Path = "core"; Commands = {npm install; npm link} },
    @{ Path = "gui"; Commands = {npm install; npm link @continuedev/core; npm run build} },
    @{ Path = "extensions/vscode"; Commands = {npm install; npm link @continuedev/core; npm run prepackage; npm run package} },
    @{ Path = "binary"; Commands = {npm install; npm run build} }
    @{ Path = "docs"; Commands = {npm install} }
)

foreach ($section in $sections) {
    Write-Host "Installing $($section.Path) extension dependencies..." -ForegroundColor White
    Log-Message "Installing $($section.Path) extension dependencies..." -LinesBefore 1 -HeaderChar "#"
    Push-Location $section.Path
    foreach ($command in $section.Commands) {
        if (-not (Execute-Command -Command $command)) {
            Write-Host "Check 'install-dependencies.log' for details." -ForegroundColor Red
            Pop-Location
            return
        }
    }
    Pop-Location
}

Write-Host "All dependencies installed successfully."
Log-Message "All dependencies installed successfully."
