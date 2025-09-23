param(
    [Parameter(Mandatory=$false)]
    [string]$EnvFile = ".env"
)

function Load-EnvFile {
    param(
        [string]$FilePath
    )
    
    # Check if the .env file exists
    if (-Not (Test-Path $FilePath)) {
        Write-Error "Environment file '$FilePath' not found!"
        return
    }
    
    Write-Host "Loading environment variables from: $FilePath" -ForegroundColor Green
    
    # Read the .env file line by line
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments (lines starting with #)
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }
        
        # Check if line contains an equals sign
        if ($line -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove surrounding quotes if present
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or 
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            
            # Set the environment variable for the current session
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
            
            # Also set it in the current PowerShell session
            Set-Variable -Name $key -Value $value -Scope Global
            
            Write-Host "Set: $key=$value" -ForegroundColor Cyan
        }
        else {
            Write-Warning "Skipping invalid line: $line"
        }
    }
    
    Write-Host "Environment variables loaded successfully!" -ForegroundColor Green
}

# Main execution
try {
    Load-EnvFile -FilePath $EnvFile
    
    # Optional: Display all loaded variables
    Write-Host "`nLoaded environment variables:" -ForegroundColor Yellow
    Get-ChildItem Env: | Where-Object { $_.Name -match "^[A-Z_][A-Z0-9_]*$" } | 
        Sort-Object Name | ForEach-Object {
            Write-Host "$($_.Name)=$($_.Value)" -ForegroundColor Gray
        }
}
catch {
    Write-Error "Failed to load environment file: $($_.Exception.Message)"
    exit 1
}