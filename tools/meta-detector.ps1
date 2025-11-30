<#
.SYNOPSIS
    Intelligent metadata detector for markdown files with YAML/TOML front matter.

.DESCRIPTION
    This PowerShell script analyzes markdown files in the repository to detect,
    validate, and report on metadata (front matter) in YAML or TOML format.
    It provides intelligent analysis of documentation artifacts and metadata patterns.

.PARAMETER Path
    The path to scan for markdown files. Defaults to the content directory.

.PARAMETER OutputFormat
    Output format: 'Table', 'JSON', or 'Summary'. Defaults to 'Summary'.

.PARAMETER ValidateRequired
    If specified, validates that required fields are present.

.EXAMPLE
    ./tools/meta-detector.ps1
    Scans the content directory and outputs a summary.

.EXAMPLE
    ./tools/meta-detector.ps1 -Path "./content/docs" -OutputFormat JSON
    Scans docs directory and outputs JSON format.

.EXAMPLE
    ./tools/meta-detector.ps1 -ValidateRequired
    Validates required metadata fields are present.
#>

param(
    [Parameter(Position = 0)]
    [string]$Path = "",
    
    [Parameter()]
    [ValidateSet('Table', 'JSON', 'Summary')]
    [string]$OutputFormat = 'Summary',
    
    [Parameter()]
    [switch]$ValidateRequired
)

# Set script root for relative path resolution
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot

if ([string]::IsNullOrEmpty($Path)) {
    $Path = Join-Path $RepoRoot "content"
}

# Required metadata fields for validation
$RequiredFields = @('title')
$OptionalFields = @('weight', 'summary', 'aliases', 'layout', 'include_summaries')

class MarkdownMetadata {
    [string]$FilePath
    [string]$RelativePath
    [string]$FrontMatterType
    [hashtable]$Metadata
    [string[]]$MissingRequired
    [bool]$IsValid
    [string]$Title
    [int]$Weight
    [string]$Summary
}

function Get-FrontMatterType {
    param([string]$Content)
    
    if ($Content -match '^---\s*\r?\n') {
        return 'YAML'
    }
    elseif ($Content -match '^\+\+\+\s*\r?\n') {
        return 'TOML'
    }
    return 'None'
}

function Parse-TOMLFrontMatter {
    param([string]$FrontMatter)
    
    $metadata = @{}
    $lines = $FrontMatter -split '\r?\n'
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        # Parse key=value pairs
        if ($line -match '^(\w+)\s*=\s*(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            
            # Remove quotes from string values
            if ($value -match '^"(.+)"$' -or $value -match "^'(.+)'$") {
                $value = $Matches[1]
            }
            # Parse boolean
            elseif ($value -eq 'true') {
                $value = $true
            }
            elseif ($value -eq 'false') {
                $value = $false
            }
            # Parse numbers
            elseif ($value -match '^\d+$') {
                $value = [int]$value
            }
            # Parse arrays
            elseif ($value -match '^\[') {
                $arrayContent = $value -replace '^\[|\]$', ''
                $value = @($arrayContent -split ',' | ForEach-Object { 
                    $_.Trim() -replace '^["'']|["'']$', ''
                } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            
            $metadata[$key] = $value
        }
    }
    
    return $metadata
}

function Parse-YAMLFrontMatter {
    param([string]$FrontMatter)
    
    $metadata = @{}
    $lines = $FrontMatter -split '\r?\n'
    
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        # Parse key: value pairs (simple YAML parsing)
        if ($line -match '^(\w+):\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            
            # Remove quotes from string values
            if ($value -match '^"(.+)"$' -or $value -match "^'(.+)'$") {
                $value = $Matches[1]
            }
            # Parse boolean
            elseif ($value -eq 'true') {
                $value = $true
            }
            elseif ($value -eq 'false') {
                $value = $false
            }
            # Parse numbers
            elseif ($value -match '^\d+$') {
                $value = [int]$value
            }
            
            $metadata[$key] = $value
        }
    }
    
    return $metadata
}

function Get-MarkdownMetadata {
    param([string]$FilePath, [string]$BasePath)
    
    $result = [MarkdownMetadata]::new()
    $result.FilePath = $FilePath
    $result.RelativePath = $FilePath.Replace($BasePath, '').TrimStart('\', '/')
    $result.Metadata = @{}
    $result.MissingRequired = @()
    $result.IsValid = $true
    
    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            $result.FrontMatterType = 'Empty'
            $result.IsValid = $false
            return $result
        }
        
        $result.FrontMatterType = Get-FrontMatterType -Content $content
        
        switch ($result.FrontMatterType) {
            'TOML' {
                if ($content -match '^\+\+\+\s*\r?\n([\s\S]*?)\r?\n\+\+\+') {
                    $frontMatter = $Matches[1]
                    $result.Metadata = Parse-TOMLFrontMatter -FrontMatter $frontMatter
                }
            }
            'YAML' {
                if ($content -match '^---\s*\r?\n([\s\S]*?)\r?\n---') {
                    $frontMatter = $Matches[1]
                    $result.Metadata = Parse-YAMLFrontMatter -FrontMatter $frontMatter
                }
            }
            default {
                $result.IsValid = $false
            }
        }
        
        # Extract common fields
        if ($result.Metadata.ContainsKey('title')) {
            $result.Title = $result.Metadata['title']
        }
        if ($result.Metadata.ContainsKey('weight')) {
            $result.Weight = $result.Metadata['weight']
        }
        if ($result.Metadata.ContainsKey('summary')) {
            $result.Summary = $result.Metadata['summary']
        }
        
        # Validate required fields
        foreach ($field in $RequiredFields) {
            if (-not $result.Metadata.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($result.Metadata[$field])) {
                $result.MissingRequired += $field
                $result.IsValid = $false
            }
        }
    }
    catch {
        $result.FrontMatterType = 'Error'
        $result.IsValid = $false
        Write-Warning "Error processing $FilePath : $_"
    }
    
    return $result
}

function Get-ArtifactAnalysis {
    param([MarkdownMetadata[]]$Results)
    
    $analysis = @{
        TotalFiles = $Results.Count
        ValidFiles = ($Results | Where-Object { $_.IsValid }).Count
        InvalidFiles = ($Results | Where-Object { -not $_.IsValid }).Count
        FrontMatterTypes = @{}
        MetadataFieldUsage = @{}
        MissingRequiredSummary = @()
        FilesWithoutWeight = @()
        FilesWithoutSummary = @()
    }
    
    foreach ($result in $Results) {
        # Count front matter types
        if (-not $analysis.FrontMatterTypes.ContainsKey($result.FrontMatterType)) {
            $analysis.FrontMatterTypes[$result.FrontMatterType] = 0
        }
        $analysis.FrontMatterTypes[$result.FrontMatterType]++
        
        # Count field usage
        foreach ($key in $result.Metadata.Keys) {
            if (-not $analysis.MetadataFieldUsage.ContainsKey($key)) {
                $analysis.MetadataFieldUsage[$key] = 0
            }
            $analysis.MetadataFieldUsage[$key]++
        }
        
        # Track missing required fields
        if ($result.MissingRequired.Count -gt 0) {
            $analysis.MissingRequiredSummary += @{
                File = $result.RelativePath
                Missing = $result.MissingRequired
            }
        }
        
        # Track files without weight
        if (-not $result.Metadata.ContainsKey('weight')) {
            $analysis.FilesWithoutWeight += $result.RelativePath
        }
        
        # Track files without summary
        if (-not $result.Metadata.ContainsKey('summary')) {
            $analysis.FilesWithoutSummary += $result.RelativePath
        }
    }
    
    return $analysis
}

# Main execution
Write-Host "Markdown Metadata Detector" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host "Scanning: $Path" -ForegroundColor Gray
Write-Host ""

# Find all markdown files
$markdownFiles = Get-ChildItem -Path $Path -Filter "*.md" -Recurse -File

if ($markdownFiles.Count -eq 0) {
    Write-Warning "No markdown files found in $Path"
    exit 1
}

Write-Host "Found $($markdownFiles.Count) markdown files" -ForegroundColor Green
Write-Host ""

# Process each file
$results = @()
foreach ($file in $markdownFiles) {
    $metadata = Get-MarkdownMetadata -FilePath $file.FullName -BasePath $Path
    $results += $metadata
}

# Generate analysis
$analysis = Get-ArtifactAnalysis -Results $results

# Output based on format
switch ($OutputFormat) {
    'JSON' {
        $output = @{
            ScanPath = $Path
            ScanDate = (Get-Date -Format 'o')
            Analysis = $analysis
            Files = $results | ForEach-Object {
                @{
                    RelativePath = $_.RelativePath
                    FrontMatterType = $_.FrontMatterType
                    IsValid = $_.IsValid
                    Title = $_.Title
                    Weight = $_.Weight
                    Summary = $_.Summary
                    Metadata = $_.Metadata
                    MissingRequired = $_.MissingRequired
                }
            }
        }
        $output | ConvertTo-Json -Depth 10
    }
    'Table' {
        $results | Format-Table -Property @(
            'RelativePath',
            'FrontMatterType',
            'IsValid',
            'Title',
            'Weight'
        ) -AutoSize
    }
    'Summary' {
        Write-Host "=== Analysis Summary ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Total Files:    $($analysis.TotalFiles)" -ForegroundColor White
        Write-Host "Valid Files:    $($analysis.ValidFiles)" -ForegroundColor Green
        Write-Host "Invalid Files:  $($analysis.InvalidFiles)" -ForegroundColor $(if ($analysis.InvalidFiles -gt 0) { 'Red' } else { 'Green' })
        Write-Host ""
        
        Write-Host "Front Matter Types:" -ForegroundColor Yellow
        foreach ($type in $analysis.FrontMatterTypes.Keys | Sort-Object) {
            Write-Host "  $type : $($analysis.FrontMatterTypes[$type])"
        }
        Write-Host ""
        
        Write-Host "Metadata Field Usage:" -ForegroundColor Yellow
        foreach ($field in $analysis.MetadataFieldUsage.Keys | Sort-Object) {
            $usage = $analysis.MetadataFieldUsage[$field]
            $percentage = [math]::Round(($usage / $analysis.TotalFiles) * 100, 1)
            Write-Host "  $field : $usage ($percentage%)"
        }
        Write-Host ""
        
        if ($ValidateRequired -and $analysis.MissingRequiredSummary.Count -gt 0) {
            Write-Host "Files Missing Required Fields:" -ForegroundColor Red
            foreach ($item in $analysis.MissingRequiredSummary) {
                Write-Host "  $($item.File): Missing [$($item.Missing -join ', ')]" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        if ($analysis.FilesWithoutWeight.Count -gt 0 -and $analysis.FilesWithoutWeight.Count -le 10) {
            Write-Host "Files Without Weight (first 10):" -ForegroundColor DarkYellow
            $analysis.FilesWithoutWeight | Select-Object -First 10 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkYellow
            }
            if ($analysis.FilesWithoutWeight.Count -gt 10) {
                Write-Host "  ... and $($analysis.FilesWithoutWeight.Count - 10) more" -ForegroundColor DarkYellow
            }
            Write-Host ""
        }
        
        Write-Host "=== Scan Complete ===" -ForegroundColor Cyan
    }
}

# Return exit code based on validation
if ($ValidateRequired -and $analysis.InvalidFiles -gt 0) {
    exit 1
}
exit 0
