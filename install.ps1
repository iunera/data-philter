# install.ps1 - Data Philter Installer for Windows

Write-Host @"

 ▄▄▄▄▄                                             ▄▄▄▄▄▄    ▄▄           ██     ▄▄▄▄
 ██▀▀▀██               ██                          ██▀▀▀▀█▄  ██           ▀▀     ▀▀██        ██
 ██    ██   ▄█████▄  ███████    ▄█████▄            ██    ██  ██▄████▄   ████       ██      ███████    ▄████▄    ██▄████
 ██    ██   ▀ ▄▄▄██    ██       ▀ ▄▄▄██            ██████▀   ██▀   ██     ██       ██        ██      ██▄▄▄▄██   ██▀
 ██    ██  ▄██▀▀▀██    ██      ▄██▀▀▀██            ██        ██    ██     ██       ██        ██      ██▀▀▀▀▀▀   ██
 ██▄▄▄██   ██▄▄▄███    ██▄▄▄   ██▄▄▄███            ██        ██    ██  ▄▄▄██▄▄▄    ██▄▄▄     ██▄▄▄   ▀██▄▄▄▄█   ██
 ▀▀▀▀▀      ▀▀▀▀ ▀▀     ▀▀▀▀    ▀▀▀▀ ▀▀            ▀▀        ▀▀    ▀▀  ▀▀▀▀▀▀▀▀     ▀▀▀▀      ▀▀▀▀     ▀▀▀▀▀    ▀▀


"@

#region Helper Functions
function Write-Log {
    param (
        [string]$Message
    )
    Write-Host -ForegroundColor Green $Message
}

function Write-Info {
    param (
        [string]$Message
    )
    Write-Host $Message
}

function Write-ErrorAndExit {
    param (
        [string]$Message,
        [int]$ExitCode = 1
    )
    Write-Host -ForegroundColor Red $Message
    exit $ExitCode
}

function Invoke-DownloadFile {
    param (
        [string]$Url,
        [string]$DestinationPath
    )
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $DestinationPath)
        return $true
    } catch {
        Write-ErrorAndExit "Failed to download ${Url}: $($_.Exception.Message)"
        return $false
    }
}

function Ensure-Directory {
    param (
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        } catch {
            Write-ErrorAndExit "Failed to create directory: $Path - $($_.Exception.Message)"
        }
    }
}
#endregion

#region Globals and State
# Use script-scope variables for state management
$script:DATA_PHILTER_DIR = Join-Path $HOME ".data-philter"
$script:BASE_URL = "https://raw.githubusercontent.com/iunera/data-philter/refs/heads/main"
$script:URL = "$script:BASE_URL/docker-compose.yml"
$script:APP_ENV_TEMPLATE_URL = "$script:BASE_URL/app.env_template"
$script:DRUID_ENV_TEMPLATE_URL = "$script:BASE_URL/druid.env_template"

$script:TMP_FILES = @()
$script:CREATED_ENV_FILES = @()
$script:EXISTING_ENV_FILES = @()
$script:INSTALL_OK = $false
#endregion

#region Cleanup and Signal Handling
function Cleanup {
    # Remove temporary files
    foreach ($file in $script:TMP_FILES) {
        if (Test-Path $file) {
            Remove-Item $file -ErrorAction SilentlyContinue
        }
    }

    # If installation did not complete, remove env files we created during this run
    if (-not $script:INSTALL_OK) {
        foreach ($envFile in $script:CREATED_ENV_FILES) {
            if (Test-Path $envFile) {
                $found = $false
                foreach ($exFile in $script:EXISTING_ENV_FILES) {
                    if ($exFile -eq $envFile) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    Write-Info "Installation canceled — removing $envFile"
                    Remove-Item $envFile -ErrorAction SilentlyContinue
                } else {
                    Write-Info "Installation canceled — leaving pre-existing $envFile"
                }
            }
        }
    }
}

# Hook into PowerShell exit and Ctrl+C (CancelKeyPress) events to run cleanup
# PowerShell.Exiting covers normal exits; CancelKeyPress handles Ctrl+C
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup } | Out-Null
try {
    # Use static .NET event subscription for broad PowerShell version compatibility
    [Console]::CancelKeyPress += {
        Cleanup
        Write-Host "`nCanceled by user."
        exit 1
    }
} catch {
    # If registration fails, continue — cleanup will still run on PowerShell.Exiting in many cases
}
#endregion

#region Ollama Handling
function Install-OllamaInteractive {
    Write-Host "Ollama is not installed. Do you want to install Ollama now? [Y/n]: " -NoNewline
    $consent = Read-Host
    # Default to 'y' when the user just presses Enter
    if ([string]::IsNullOrWhiteSpace($consent)) { $consent = "y" }
    $consent = $consent.Trim().ToLower()
    # Accept 'y' or 'yes' as confirmation; anything else aborts
    if ($consent -notin @("y","yes")) {
        Write-ErrorAndExit "Ollama installation skipped. Please install it manually to proceed."
    }

    Write-Info "Installing Ollama for Windows..."
    $ollamaInstallerUrl = "https://ollama.com/download/OllamaSetup.exe"
    $installerPath = Join-Path $env:TEMP "OllamaSetup.exe"
    $script:TMP_FILES += $installerPath

    Write-Info "Downloading Ollama installer from $ollamaInstallerUrl..."
    if (-not (Invoke-DownloadFile $ollamaInstallerUrl $installerPath)) {
        Write-ErrorAndExit "Failed to download Ollama installer."
    }

    Write-Info "Running Ollama installer. This may require administrator privileges."
    try {
        Start-Process -FilePath $installerPath -ArgumentList "/SILENT /NORESTART /NOCANCEL /SP-" -ErrorAction Stop
    } catch {
        Write-ErrorAndExit "Ollama installer failed to start: $($_.Exception.Message)"
    }

    Write-Info "Waiting for Ollama installation to complete (this might take some time)..."
    $timeout = New-TimeSpan -Minutes 5
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed -lt $timeout) {
        if (Get-Process -Name "ollama app" -ErrorAction SilentlyContinue) {
            break
        }
        Start-Sleep -Seconds 5
    }
    $stopwatch.Stop()

    if (-not (Get-Process -Name "ollama app" -ErrorAction SilentlyContinue)) {
        Write-ErrorAndExit "Ollama installation failed or 'ollama app.exe' process not found after installation. Please check your installation."
    }
    Write-Log "Ollama installed successfully."
}

function Ensure-Ollama {
    # Ensure ollama binary exists or offer to install
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        return
    }

    Install-OllamaInteractive
}
#endregion

#region Template Helpers
function Remove-KeyFromTemplate {
    param (
        [string]$TemplateFile,
        [string]$Key
    )
    if (Test-Path $TemplateFile) {
        $content = Get-Content -Raw -ErrorAction SilentlyContinue $TemplateFile
        if ($null -ne $content) {
            $lines = $content -split "`n"
            $filtered = @()
            foreach ($l in $lines) {
                $trim = $l.TrimStart()
                if ($trim -and $trim.StartsWith("$Key=")) { continue }
                $filtered += $l
            }
            Set-Content -Path $TemplateFile -Value ($filtered -join "`n") -ErrorAction SilentlyContinue
            Write-Log "Removed $Key from $TemplateFile"
        }
    }
}
#endregion

#region Environment File Configuration
function Configure-EnvFile {
    param (
        [string]$TemplateFile,
        [string]$EnvFile
    )

    if (Test-Path $EnvFile) {
        Write-Info "$EnvFile already exists, skipping configuration."
        return
    }

    Write-Info "Configuring $EnvFile..."
    $tmpEnv = [System.IO.Path]::GetTempFileName()
    $script:TMP_FILES += $tmpEnv

    $commentBlock = ""
    $templateContent = Get-Content $TemplateFile

    foreach ($line in $templateContent) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            Add-Content -Path $tmpEnv -Value ""
            $commentBlock = ""
        } elseif ($line.StartsWith("#")) {
            Add-Content -Path $tmpEnv -Value $line
            $commentBlock += "$line`n"
        } elseif ($line -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            if ([string]::IsNullOrEmpty($value)) {
                if ($key -eq "DRUID_SSL_ENABLED") {
                    Add-Content -Path $tmpEnv -Value "$key="
                } elseif ($key -eq "SPRING_AI_OPENAI_API_KEY" -and ($script:IUNERA_MODEL_TYPE -like "ollama-*")) {
                    # If any Ollama variant is chosen, don't ask for OpenAI API Key
                    Add-Content -Path $tmpEnv -Value "$key="
                } else {
                        # If an exported environment variable is set for this key, use it directly
                        $presetValue = [Environment]::GetEnvironmentVariable($key)
                        if (-not ([string]::IsNullOrEmpty($presetValue))) {
                            Add-Content -Path $tmpEnv -Value "$key=$presetValue"
                        } else {
                            if (-not ([string]::IsNullOrWhiteSpace($commentBlock))) {
                                Write-Host ""
                                $commentBlock.Split("`n") | ForEach-Object {
                                    if (-not ([string]::IsNullOrWhiteSpace($_))) {
                                        $rest = $_.TrimStart("# ").Trim()
                                        Write-Host -ForegroundColor Yellow -NoNewline "#"
                                        Write-Host -ForegroundColor White " $rest"
                                    }
                                }
                            }

                            while ($true) {
                                Write-Host "${key}: " -NoNewline
                                $userValue = Read-Host
                                $userValue = $userValue.Trim()

                                if (-not ([string]::IsNullOrWhiteSpace($userValue))) {
                                    Add-Content -Path $tmpEnv -Value "$key=$userValue"
                                    break
                                }

                                Write-Host "Empty value — save anyway? (y/n): " -NoNewline
                                $confirm = Read-Host
                                if ($confirm -eq "y") {
                                    Add-Content -Path $tmpEnv -Value "$key="
                                    break
                                }

                                if (-not ([string]::IsNullOrWhiteSpace($commentBlock))) {
                                    Write-Host ""
                                    $commentBlock.Split("`n") | ForEach-Object {
                                        if (-not ([string]::IsNullOrWhiteSpace($_))) {
                                            $rest = $_.TrimStart("# ").Trim()
                                            Write-Host -ForegroundColor Yellow -NoNewline "#"
                                            Write-Host -ForegroundColor White " $rest"
                                        }
                                    }
                                }
                            }
                        }
                }
            } else {
                Add-Content -Path $tmpEnv -Value $line
            }
            $commentBlock = ""
        } else {
            Add-Content -Path $tmpEnv -Value $line
        }
    }

    # If this is druid.env, determine DRUID_SSL_ENABLED based on DRUID_ROUTER_URL
    if ((Split-Path $EnvFile -Leaf) -eq "druid.env") {
        $druidRouterUrl = (Get-Content $tmpEnv | Select-String -Pattern "^DRUID_ROUTER_URL=" | ForEach-Object { $_.ToString().Split("=")[1] })
        $druidSslEnabledValue = $false
        if ($druidRouterUrl -and $druidRouterUrl.StartsWith("https://")) {
            $druidSslEnabledValue = $true
        }

        $content = Get-Content $tmpEnv
        $updatedContent = @()
        $sslFound = $false
        foreach ($line in $content) {
            if ($line.StartsWith("DRUID_SSL_ENABLED=")) {
                $updatedContent += "DRUID_SSL_ENABLED=$druidSslEnabledValue"
                $sslFound = $true
            } else {
                $updatedContent += $line
            }
        }
        if (-not $sslFound) {
            $updatedContent += "DRUID_SSL_ENABLED=$druidSslEnabledValue"
        }
        Set-Content -Path $tmpEnv -Value ($updatedContent -join "`n")
    }

    Move-Item $tmpEnv $EnvFile -Force
    $script:TMP_FILES = $script:TMP_FILES | Where-Object { $_ -ne $tmpEnv }
    $script:CREATED_ENV_FILES += $EnvFile
    Write-Log "$EnvFile configured."
}
#endregion

#region Dependency Checks and Helpers
function Check-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ErrorAndExit "Docker could not be found. Please install Docker Desktop for Windows first."
    }

    # Ensure the daemon is running by running a quick docker info/ps command
    docker ps > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorAndExit "Docker daemon is not running or not accessible. Please ensure Docker Desktop is running and you have the necessary permissions."
    }

    # Check docker compose plugin
    docker compose version > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorAndExit "'docker compose' could not be found. Please ensure you have a recent Docker Desktop installation with compose plugin."
    }
}

function Ensure-OllamaServer {
    # Ensure ollama binary present (or install), then ensure server is running
    Ensure-Ollama

    # Check if server is running; try to start it if not
    ollama ps > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Ollama is not running. Attempting to start Ollama server in the background..."
        try {
            $ollamaCmd = (Get-Command ollama).Source
            Start-Process -FilePath $ollamaCmd -ArgumentList "serve" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            ollama ps > $null 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorAndExit "Failed to start Ollama server. Please check your Ollama installation and ensure it can run."
            }
            Write-Log "Ollama server started successfully in the background."
        } catch {
            Write-ErrorAndExit "Failed to start Ollama server: $($_.Exception.Message)"
        }
    }
}
#endregion

#region Download Templates and Compose
function Download-Templates {
    Write-Log "🔧 Downloading templates..."

    Write-Info "Downloading app.env_template"
    $tmpAppTemplate = Join-Path $env:TEMP "app.env_template"
    $script:TMP_FILES += $tmpAppTemplate
    if (-not (Invoke-DownloadFile $script:APP_ENV_TEMPLATE_URL $tmpAppTemplate)) {
        Write-ErrorAndExit "Failed to download app.env_template."
    }

    Write-Info "Downloading druid.env_template"
    $tmpDruidTemplate = Join-Path $env:TEMP "druid.env_template"
    $script:TMP_FILES += $tmpDruidTemplate
    if (-not (Invoke-DownloadFile $script:DRUID_ENV_TEMPLATE_URL $tmpDruidTemplate)) {
        Write-ErrorAndExit "Failed to download druid.env_template."
    }

    Move-Item $tmpAppTemplate "app.env_template" -Force
    Move-Item $tmpDruidTemplate "druid.env_template" -Force
    $script:TMP_FILES = $script:TMP_FILES | Where-Object { $_ -ne $tmpAppTemplate -and $_ -ne $tmpDruidTemplate }
}

function Download-DockerCompose {
    Write-Log "🔧 Downloading docker-compose.yml..."
    $dockerComposePath = Join-Path $script:DATA_PHILTER_DIR "docker-compose.yml"
    if (-not (Invoke-DownloadFile $script:URL $dockerComposePath)) {
        Write-ErrorAndExit "Failed to download docker-compose.yml."
    }
}
#endregion

#region Readiness and Browser Helpers
function Wait-ForBackend {
    param (
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [int]$TimeoutSeconds = 120,
        [int]$IntervalSeconds = 2
    )

    $healthUrl = "$BaseUrl/actuator/health"
    $waited = 0
    Write-Info "Waiting for backend to become available at $BaseUrl (timeout: ${TimeoutSeconds}s)..."

    while ($waited -lt $TimeoutSeconds) {
        try {
            # Use Invoke-WebRequest; on connection refused it throws quickly. We don't fail the script.
            $resp = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -Method Get -ErrorAction Stop
            if ($resp -and $resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                Write-Log "Backend is up!"
                return
            }
        } catch {
            # ignore and retry after interval
        }
        Start-Sleep -Seconds $IntervalSeconds
        $waited += $IntervalSeconds
    }

    # Timed out — warn but continue
    Write-Host -ForegroundColor Yellow "Backend did not become ready within ${TimeoutSeconds}s. You may need to wait a bit longer."
}
#endregion

function Show-Usage {
    Write-Host "Usage: .\install.ps1"
}

function Main {
    Write-Log "🚀 Welcome to the Data Philter Installer! 🚀"
    Write-Info "This script will guide you through the setup process."

    # Step 1: create directory
    Write-Log "🔧 Step 1: Creating directory..."
    Write-Info "We will create the $script:DATA_PHILTER_DIR directory to store environment files."
    Ensure-Directory $script:DATA_PHILTER_DIR
    Set-Location $script:DATA_PHILTER_DIR

    # Record which env files already existed before we start creating any
    $envFilesToCheck = @("app.env", "druid.env")
    foreach ($f in $envFilesToCheck) {
        if (Test-Path $f) {
            $script:EXISTING_ENV_FILES += (Join-Path $script:DATA_PHILTER_DIR $f)
            while ($true) {
                Write-Host "Found existing $f. Do you want to recreate (overwrite) it? [y/N]: " -NoNewline
                $resp = Read-Host
                $resp = $resp.Trim()
                if ($resp -eq "y" -or $resp -eq "Y") {
                    Write-Info "User chose to recreate $f — it will be overwritten."
                    Remove-Item $f -ErrorAction SilentlyContinue
                    break
                } else {
                    Write-Info "Keeping existing $f — installer will skip configuring it."
                    break
                }
            }
        }
    }

    # Step 2: Download templates
    Write-Log "🔧 Step 2: Downloading templates..."
    Download-Templates

    # Step 3: Check dependencies
    Write-Log "🔧 Step 3: Checking dependencies..."
    Check-Docker

    # Step 3.5: Configure AI Model Type
    Write-Log "🔧 Step 3.5: Configuring AI Model Type..."

    # If app.env exists and IUNERA_MODEL_TYPE is set (env or inside app.env), skip interactive configuration
    $skipModelConfig = $false
    if (Test-Path "app.env") {
        $hasEnvVar = -not [string]::IsNullOrWhiteSpace($env:IUNERA_MODEL_TYPE)
        $hasInFile = $false
        try {
            $match = Select-String -Path "app.env" -Pattern "^IUNERA_MODEL_TYPE=" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) { $hasInFile = $true }
        } catch { }

        if ($hasEnvVar -or $hasInFile) {
            Write-Info "app.env exists and IUNERA_MODEL_TYPE is set — skipping model configuration."
            $skipModelConfig = $true
            if (-not $hasEnvVar) {
                $line = (Get-Content "app.env" | Where-Object { $_ -match "^IUNERA_MODEL_TYPE=" } | Select-Object -First 1)
                if ($line) {
                    $val = $line -replace "^IUNERA_MODEL_TYPE=", ""
                    $script:IUNERA_MODEL_TYPE = $val
                    $env:IUNERA_MODEL_TYPE = $val
                }
            } else {
                $script:IUNERA_MODEL_TYPE = $env:IUNERA_MODEL_TYPE
            }

            if ($script:IUNERA_MODEL_TYPE -like "ollama-*") {
                Ensure-OllamaServer
            }
    }
    }

    if (-not $skipModelConfig) {
        $modelChoice = ""
        while ($true) {
            Write-Host "Choose your AI model provider (ollama/openai) [ollama]: " -NoNewline
            $modelChoice = Read-Host
            if ([string]::IsNullOrWhiteSpace($modelChoice)) { $modelChoice = "ollama" }
            $modelChoice = $modelChoice.Trim().ToLower()

            switch ($modelChoice) {
                "ollama" {
                    # Ask for model size
                    while ($true) {
                        Write-Host "Choose Ollama model size (medium/large/xl) [medium]: " -NoNewline
                        $sizeChoice = Read-Host
                        if ([string]::IsNullOrWhiteSpace($sizeChoice)) { $sizeChoice = "medium" }
                        $sizeChoice = $sizeChoice.Trim().ToLower()
                        if ($sizeChoice -eq "medium" -or $sizeChoice -eq "m") {
                            $script:IUNERA_MODEL_TYPE = "ollama-m"
                            $env:IUNERA_MODEL_TYPE = "ollama-m"
                            break
                        } elseif ($sizeChoice -eq "large" -or $sizeChoice -eq "l") {
                            $script:IUNERA_MODEL_TYPE = "ollama-l"
                            $env:IUNERA_MODEL_TYPE = "ollama-l"
                            break
                        } elseif ($sizeChoice -eq "xl" -or $sizeChoice -eq "xlarge" -or $sizeChoice -eq "extra-large" -or $sizeChoice -eq "extra large") {
                            $script:IUNERA_MODEL_TYPE = "ollama-xl"
                            $env:IUNERA_MODEL_TYPE = "ollama-xl"
                            break
                        } else {
                            Write-Info "Invalid choice. Please enter 'medium', 'large', or 'xl'."
                        }
                    }
                    # For Ollama, remove OpenAI key from template if present
                    Remove-KeyFromTemplate -TemplateFile "app.env_template" -Key "SPRING_AI_OPENAI_API_KEY"
                    break
                }
                "openai" {
                    $script:IUNERA_MODEL_TYPE = "openai"
                    $env:IUNERA_MODEL_TYPE = "openai"
                    # Prompt for API key only if not already set
                    if ([string]::IsNullOrEmpty($env:SPRING_AI_OPENAI_API_KEY)) {
                        Write-Host "Enter your OpenAI API Key (SPRING_AI_OPENAI_API_KEY): " -NoNewline
                        $enteredKey = Read-Host
                        $enteredKey = $enteredKey.Trim()
                        if ([string]::IsNullOrEmpty($enteredKey)) {
                            # If left empty, remove key from template so we don't prompt later
                            Remove-KeyFromTemplate -TemplateFile "app.env_template" -Key "SPRING_AI_OPENAI_API_KEY"
                        } else {
                            $env:SPRING_AI_OPENAI_API_KEY = $enteredKey
                        }
                    }
                    break
                }
                default {
                    Write-Info "Invalid choice. Please enter 'ollama' or 'openai'."
                }
            }
            if ($script:IUNERA_MODEL_TYPE) { break }
        }

        if ($script:IUNERA_MODEL_TYPE -like "ollama-*") {
            Ensure-OllamaServer
        }
    }

    # Step 4: Configure environment files
    Write-Log "🔧 Step 4: Configuring environment files..."
    Configure-EnvFile "app.env_template" "app.env"
    Configure-EnvFile "druid.env_template" "druid.env"

    Remove-Item "app.env_template", "druid.env_template" -ErrorAction SilentlyContinue

    # Step 5: Download docker-compose.yml
    Write-Log "🔧 Step 5: Downloading docker-compose.yml..."
    Download-DockerCompose

    # Step 6: Start services
    Write-Log "🔧 Step 6: Starting services..."
    docker compose up -d

    Write-Log "Services started in the background."
    Write-Info "You can check the status with 'docker ps'."

    Write-Log "✅ Installation complete!"
    Write-Info "You can now access the application at http://localhost:4000"
    # Wait for backend readiness before opening the browser (up to 120s)
    try {
        Wait-ForBackend -BaseUrl "http://localhost:4000" -TimeoutSeconds 120 -IntervalSeconds 2
    } catch {
        # If readiness check fails (unexpected), continue to attempt opening the browser
    }
    Write-Log "Opening http://localhost:4000 in your default browser..."
    Start-Process "http://localhost:4000"

    $script:INSTALL_OK = $true
}

# Run the main flow and ensure cleanup runs on exit
try {
    Main
} catch {
    Write-ErrorAndExit "Installation failed: $($_.Exception.Message)"
} finally {
    Cleanup
}
#endregion
