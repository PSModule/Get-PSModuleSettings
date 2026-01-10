'powershell-yaml', 'Hashtable' | Install-PSResource -Repository PSGallery -TrustRepository

$settingsPath = $env:PSMODULE_GET_SETTINGS_INPUT_SettingsPath
$debug = $env:PSMODULE_GET_SETTINGS_INPUT_Debug
$verbose = $env:PSMODULE_GET_SETTINGS_INPUT_Verbose
$version = $env:PSMODULE_GET_SETTINGS_INPUT_Version
$prerelease = $env:PSMODULE_GET_SETTINGS_INPUT_Prerelease
$workingDirectory = $env:PSMODULE_GET_SETTINGS_INPUT_WorkingDirectory

LogGroup 'Inputs' {
    [pscustomobject]@{
        PWD          = (Get-Location).Path
        SettingsPath = $settingsPath
    } | Format-List | Out-String
}

if (![string]::IsNullOrEmpty($settingsPath) -and (Test-Path -Path $settingsPath)) {
    LogGroup 'Import settings' {
        $settingsFile = Get-Item -Path $settingsPath
        $relativeSettingsPath = $settingsFile | Resolve-Path -Relative
        Write-Host "Importing settings from [$relativeSettingsPath]"
        $content = $settingsFile | Get-Content -Raw
        switch -Regex ($settingsFile.Extension) {
            '.json' {
                $settings = $content | ConvertFrom-Json
                Write-Host ($settings | ConvertTo-Json -Depth 5 | Out-String)
            }
            '.yaml|.yml' {
                $settings = $content | ConvertFrom-Yaml
                Write-Host ($settings | ConvertTo-Yaml | Out-String)
            }
            '.psd1' {
                $settings = $content | ConvertFrom-Hashtable
                Write-Host ($settings | ConvertTo-Hashtable | Format-Hashtable | Out-String)
            }
            default {
                throw "Unsupported settings file format: [$settingsPath]. Supported formats are json, yaml/yml and psd1."
            }
        }
    }

    LogGroup 'Validate settings against schema' {
        $schemaPath = Join-Path $PSScriptRoot 'Settings.schema.json'
        if (Test-Path -Path $schemaPath) {
            Write-Host 'Validating settings against schema...'
            $schema = Get-Content $schemaPath -Raw

            # Convert settings to JSON for validation
            $settingsJson = $settings | ConvertTo-Json -Depth 10

            try {
                $isValid = Test-Json -Json $settingsJson -Schema $schema -ErrorAction Stop
                if ($isValid) {
                    Write-Host '✓ Settings conform to schema'
                } else {
                    throw 'Settings do not conform to the schema'
                }
            } catch {
                Write-Error "Schema validation failed: $_"
                Write-Error 'Your settings file does not match the expected schema structure.'
                Write-Error 'Please refer to the schema documentation: https://github.com/PSModule/Get-PSModuleSettings#schema'
                throw
            }
        } else {
            Write-Warning "Schema file not found at [$schemaPath]. Skipping validation."
        }
    }
} else {
    Write-Host 'No settings file present.'
    $settings = @{}
}

LogGroup 'Name' {
    [pscustomobject]@{
        SettingsName   = $settings.Name
        RepositoryName = $env:GITHUB_REPOSITORY_NAME
    } | Format-List | Out-String

    if (![string]::IsNullOrEmpty($settings.Name)) {
        $name = $settings.Name
    } else {
        $name = $env:GITHUB_REPOSITORY_NAME
    }

    Write-Host "Using [$name] as the module name."
}

$settings = [pscustomobject]@{
    Name    = $name
    Test    = [pscustomobject]@{
        Skip         = $settings.Test.Skip ?? $false
        Linux        = [pscustomobject]@{
            Skip = $settings.Test.Linux.Skip ?? $false
        }
        MacOS        = [pscustomobject]@{
            Skip = $settings.Test.MacOS.Skip ?? $false
        }
        Windows      = [pscustomobject]@{
            Skip = $settings.Test.Windows.Skip ?? $false
        }
        SourceCode   = [pscustomobject]@{
            Skip    = $settings.Test.SourceCode.Skip ?? $false
            Linux   = [pscustomobject]@{
                Skip = $settings.Test.SourceCode.Linux.Skip ?? $false
            }
            MacOS   = [pscustomobject]@{
                Skip = $settings.Test.SourceCode.MacOS.Skip ?? $false
            }
            Windows = [pscustomobject]@{
                Skip = $settings.Test.SourceCode.Windows.Skip ?? $false
            }
        }
        PSModule     = [pscustomobject]@{
            Skip    = $settings.Test.PSModule.Skip ?? $false
            Linux   = [pscustomobject]@{
                Skip = $settings.Test.PSModule.Linux.Skip ?? $false
            }
            MacOS   = [pscustomobject]@{
                Skip = $settings.Test.PSModule.MacOS.Skip ?? $false
            }
            Windows = [pscustomobject]@{
                Skip = $settings.Test.PSModule.Windows.Skip ?? $false
            }
        }
        Module       = [pscustomobject]@{
            Skip    = $settings.Test.Module.Skip ?? $false
            Linux   = [pscustomobject]@{
                Skip = $settings.Test.Module.Linux.Skip ?? $false
            }
            MacOS   = [pscustomobject]@{
                Skip = $settings.Test.Module.MacOS.Skip ?? $false
            }
            Windows = [pscustomobject]@{
                Skip = $settings.Test.Module.Windows.Skip ?? $false
            }
        }
        TestResults  = [pscustomobject]@{
            Skip = $settings.Test.TestResults.Skip ?? $false
        }
        CodeCoverage = [pscustomobject]@{
            Skip            = $settings.Test.CodeCoverage.Skip ?? $false
            PercentTarget   = $settings.Test.CodeCoverage.PercentTarget ?? 0
            StepSummaryMode = $settings.Test.CodeCoverage.StepSummaryMode ?? 'Missed, Files'
        }
    }
    Build   = [pscustomobject]@{
        Skip   = $settings.Build.Skip ?? $false
        Module = [pscustomobject]@{
            Skip = $settings.Build.Module.Skip ?? $false
        }
        Docs   = [pscustomobject]@{
            Skip                 = $settings.Build.Docs.Skip ?? $false
            ShowSummaryOnSuccess = $settings.Build.Docs.ShowSummaryOnSuccess ?? $false
        }
        Site   = [pscustomobject]@{
            Skip = $settings.Build.Site.Skip ?? $false
        }
    }
    Publish = [pscustomobject]@{
        Module = [pscustomobject]@{
            Skip                  = $settings.Publish.Module.Skip ?? $false
            AutoCleanup           = $settings.Publish.Module.AutoCleanup ?? $true
            AutoPatching          = $settings.Publish.Module.AutoPatching ?? $true
            IncrementalPrerelease = $settings.Publish.Module.IncrementalPrerelease ?? $true
            DatePrereleaseFormat  = $settings.Publish.Module.DatePrereleaseFormat ?? ''
            VersionPrefix         = $settings.Publish.Module.VersionPrefix ?? 'v'
            MajorLabels           = $settings.Publish.Module.MajorLabels ?? 'major, breaking'
            MinorLabels           = $settings.Publish.Module.MinorLabels ?? 'minor, feature'
            PatchLabels           = $settings.Publish.Module.PatchLabels ?? 'patch, fix'
            IgnoreLabels          = $settings.Publish.Module.IgnoreLabels ?? 'NoRelease'
        }
    }
    Linter  = [pscustomobject]@{
        Skip                 = $settings.Linter.Skip ?? $false
        ShowSummaryOnSuccess = $settings.Linter.ShowSummaryOnSuccess ?? $false
        env                  = $settings.Linter.env ?? @{}
    }
}

# Add input properties to settings
$settings | Add-Member -MemberType NoteProperty -Name SettingsPath -Value $settingsPath
$settings | Add-Member -MemberType NoteProperty -Name Debug -Value $debug
$settings | Add-Member -MemberType NoteProperty -Name Verbose -Value $verbose
$settings | Add-Member -MemberType NoteProperty -Name Version -Value $version
$settings | Add-Member -MemberType NoteProperty -Name Prerelease -Value $prerelease
$settings | Add-Member -MemberType NoteProperty -Name WorkingDirectory -Value $workingDirectory

# Calculate job run conditions
LogGroup 'Calculate Job Run Conditions:' {
    # Common conditions
    $isPR = $env:GITHUB_EVENT_NAME -eq 'pull_request'
    $isOpenOrUpdatedPR = $isPR -and $env:GITHUB_EVENT_ACTION -ne 'closed'
    $isAbandonedPR = $isPR -and $env:GITHUB_EVENT_ACTION -eq 'closed' -and $env:GITHUB_EVENT_PULL_REQUEST_MERGED -ne 'true'
    $isMergedPR = $isPR -and $env:GITHUB_EVENT_PULL_REQUEST_MERGED -eq 'true'
    $isNotAbandonedPR = -not $isAbandonedPR

    [pscustomobject]@{
        isPR              = $isPR
        isOpenOrUpdatedPR = $isOpenOrUpdatedPR
        isAbandonedPR     = $isAbandonedPR
        isMergedPR        = $isMergedPR
        isNotAbandonedPR  = $isNotAbandonedPR
    } | Format-List | Out-String
}

# Get-TestSuites
if ($settings.Test.Skip) {
    Write-Host 'Skipping all tests.'
    $sourceCodeTestSuites = $null
    $psModuleTestSuites = $null
    $moduleTestSuites = $null

    # Add TestSuites to settings
    $settings | Add-Member -MemberType NoteProperty -Name TestSuites -Value ([pscustomobject]@{
            SourceCode = $null
            PSModule   = $null
            Module     = $null
        })
} else {

    # Define test configurations as an array of hashtables.
    $linux = [PSCustomObject]@{ RunsOn = 'ubuntu-latest'; OSName = 'Linux' }
    $macOS = [PSCustomObject]@{ RunsOn = 'macos-latest'; OSName = 'macOS' }
    $windows = [PSCustomObject]@{ RunsOn = 'windows-latest'; OSName = 'Windows' }

    LogGroup 'Source Code Test Suites:' {
        $sourceCodeTestSuites = if ($settings.Test.SourceCode.Skip) {
            Write-Host 'Skipping all source code tests.'
            $null
        } else {
            $result = @()
            if (-not $settings.Test.Linux.Skip -and -not $settings.Test.SourceCode.Linux.Skip) { $result += $linux }
            if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.SourceCode.MacOS.Skip) { $result += $macOS }
            if (-not $settings.Test.Windows.Skip -and -not $settings.Test.SourceCode.Windows.Skip) { $result += $windows }
            if ($result.Count -gt 0) { $result } else { $null }
        }
        $sourceCodeTestSuites | Format-Table -AutoSize | Out-String
    }

    LogGroup 'PSModule Test Suites:' {
        $psModuleTestSuites = if ($settings.Test.PSModule.Skip) {
            Write-Host 'Skipping all PSModule tests.'
            $null
        } else {
            $result = @()
            if (-not $settings.Test.Linux.Skip -and -not $settings.Test.PSModule.Linux.Skip) { $result += $linux }
            if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.PSModule.MacOS.Skip) { $result += $macOS }
            if (-not $settings.Test.Windows.Skip -and -not $settings.Test.PSModule.Windows.Skip) { $result += $windows }
            if ($result.Count -gt 0) { $result } else { $null }
        }
        $psModuleTestSuites | Format-Table -AutoSize | Out-String
    }

    LogGroup 'Module Local Test Suites:' {
        $moduleTestSuites = if ($settings.Test.Module.Skip) {
            Write-Host 'Skipping all module tests.'
        } else {
            # Locate the tests directory.
            $testsPath = Resolve-Path 'tests' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
            if (-not $testsPath) {
                Write-Warning 'No tests found'
            }
            Write-Host "Tests found at [$testsPath]"

            function Get-TestItemsFromFolder {
                <#
                    .SYNOPSIS
                        Retrieves test items from a specified folder.

                    .DESCRIPTION
                        This function searches for test-related files in the specified folder.
                        It looks for configuration files (*.Configuration.ps1), container files (*.Container.ps1),
                        and test files (*.Tests.ps1) in that order of precedence.

                    .PARAMETER FolderPath
                        The path to the folder to search for test items.

                    .OUTPUTS
                        System.IO.FileInfo[]
                        Returns an array of test-related files found in the folder.
                #>
                param ([string]$FolderPath)

                $configFiles = Get-ChildItem -Path $FolderPath -File -Filter '*.Configuration.ps1'
                if ($configFiles.Count -eq 1) {
                    return @($configFiles)
                } elseif ($configFiles.Count -gt 1) {
                    throw "Multiple configuration files found in [$FolderPath]. Please separate configurations into different folders."
                }

                $containerFiles = Get-ChildItem -Path $FolderPath -File -Filter '*.Container.ps1'
                if ($containerFiles.Count -ge 1) {
                    return $containerFiles
                }

                $testFiles = Get-ChildItem -Path $FolderPath -File -Filter '*.Tests.ps1'
                return $testFiles
            }

            function Find-TestDirectory {
                <#
                    .SYNOPSIS
                        Finds test directories recursively.

                    .DESCRIPTION
                        This function recursively searches for all directories starting from the specified path.
                        It returns a flat array of all directory paths found.

                    .PARAMETER Path
                        The root path to start searching for directories.

                    .OUTPUTS
                        System.String[]
                        Returns an array of directory paths.
                #>
                param ([string]$Path)

                $directories = @()
                $childDirs = Get-ChildItem -Path $Path -Directory

                foreach ($dir in $childDirs) {
                    $directories += $dir.FullName
                    $directories += Find-TestDirectory -Path $dir.FullName
                }

                return $directories
            }

            $allTestFolders = @($testsPath) + (Find-TestDirectory -Path $testsPath)

            foreach ($folder in $allTestFolders) {
                $testItems = Get-TestItemsFromFolder -FolderPath $folder
                foreach ($item in $testItems) {
                    if (-not $settings.Test.Linux.Skip -and -not $settings.Test.Module.Linux.Skip) {
                        [pscustomobject]@{
                            RunsOn   = $linux.RunsOn
                            OSName   = $linux.OSName
                            TestPath = Resolve-Path -Path $item.FullName -Relative
                            TestName = ($item.BaseName).Split('.')[0]
                        }
                    }
                    if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.Module.MacOS.Skip) {
                        [pscustomobject]@{
                            RunsOn   = $macOS.RunsOn
                            OSName   = $macOS.OSName
                            TestPath = Resolve-Path -Path $item.FullName -Relative
                            TestName = ($item.BaseName).Split('.')[0]
                        }
                    }
                    if (-not $settings.Test.Windows.Skip -and -not $settings.Test.Module.Windows.Skip) {
                        [pscustomobject]@{
                            RunsOn   = $windows.RunsOn
                            OSName   = $windows.OSName
                            TestPath = Resolve-Path -Path $item.FullName -Relative
                            TestName = ($item.BaseName).Split('.')[0]
                        }
                    }
                }
            }
        }
        $moduleTestSuites | Format-Table -AutoSize | Out-String
    }

    # Add TestSuites to settings
    $settings | Add-Member -MemberType NoteProperty -Name TestSuites -Value ([pscustomobject]@{
            SourceCode = $sourceCodeTestSuites
            PSModule   = $psModuleTestSuites
            Module     = $moduleTestSuites
        })
}

# Calculate job-specific conditions and add to settings
LogGroup 'Calculate Job Run Conditions:' {
    # Create Run object with all job-specific conditions
    $run = [pscustomobject]@{
        LintRepository       = $isOpenOrUpdatedPR -and (-not $settings.Linter.Skip)
        BuildModule          = $isNotAbandonedPR -and (-not $settings.Build.Module.Skip)
        TestSourceCode       = $isNotAbandonedPR -and ($null -ne $settings.TestSuites.SourceCode)
        LintSourceCode       = $isNotAbandonedPR -and ($null -ne $settings.TestSuites.SourceCode)
        TestModule           = $isNotAbandonedPR -and ($null -ne $settings.TestSuites.PSModule)
        BeforeAllModuleLocal = $isNotAbandonedPR -and ($null -ne $settings.TestSuites.Module)
        TestModuleLocal      = $isNotAbandonedPR -and ($null -ne $settings.TestSuites.Module)
        AfterAllModuleLocal  = $true # Always runs if Test-ModuleLocal was not skipped
        GetTestResults       = $isNotAbandonedPR -and (-not $settings.Test.TestResults.Skip) -and (
            ($null -ne $settings.TestSuites.SourceCode) -or ($null -ne $settings.TestSuites.PSModule) -or ($null -ne $settings.TestSuites.Module)
        )
        GetCodeCoverage      = $isNotAbandonedPR -and (-not $settings.Test.CodeCoverage.Skip) -and (
            ($null -ne $settings.TestSuites.PSModule) -or ($null -ne $settings.TestSuites.Module)
        )
        PublishModule        = $isPR -and ($isAbandonedPR -or ($isOpenOrUpdatedPR -or $isMergedPR))
        BuildDocs            = $isNotAbandonedPR -and (-not $settings.Build.Docs.Skip)
        BuildSite            = $isNotAbandonedPR -and (-not $settings.Build.Site.Skip)
        PublishSite          = $isMergedPR
    }
    $settings | Add-Member -MemberType NoteProperty -Name Run -Value $run

    Write-Host 'Job Run Conditions:'
    $run | Format-List | Out-String
}

LogGroup 'Final settings' {
    switch -Regex ($settingsFile.Extension) {
        '.yaml|.yml' {
            Write-Host ($settings | ConvertTo-Yaml | Out-String)
        }
        '.psd1' {
            Write-Host ($settings | ConvertTo-Hashtable | Format-Hashtable | Out-String)
        }
        default {
            Write-Host ($settings | ConvertTo-Json -Depth 5 | Out-String)
        }
    }
}

Set-GitHubOutput -Name Settings -Value ($settings | ConvertTo-Json -Depth 10)
