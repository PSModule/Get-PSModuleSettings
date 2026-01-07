#Requires -Modules GitHub

[CmdletBinding()]
param(
    [Parameter()]
    [string] $SettingsPath = $env:PSMODULE_GET_SETTINGS_INPUT_SettingsPath
)

begin {
    $scriptName = $MyInvocation.MyCommand.Name
    Write-Debug "[$scriptName] - Start"
}

process {
    try {
        'powershell-yaml' | Install-PSResource -Repository PSGallery -TrustRepository -Reinstall

        LogGroup 'Inputs' {
            [pscustomobject]@{
                PWD          = (Get-Location).Path
                SettingsPath = $SettingsPath
            } | Format-List | Out-String
        }

        if (![string]::IsNullOrEmpty($SettingsPath) -and (Test-Path -Path $SettingsPath)) {
            LogGroup 'Import settings' {
                $settingsFile = Get-Item -Path $SettingsPath
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
                        throw "Unsupported settings file format: [$SettingsPath]. Supported formats are json, yaml/yml and psd1."
                    }
                }
            }
        } else {
            Write-Host 'No settings file present.'
            $settings = @{}
        }

        LogGroup 'Name' {
            [pscustomobject]@{
                InputName      = $inputName
                SettingsName   = $settings.Name
                RepositoryName = $env:GITHUB_REPOSITORY_NAME
            } | Format-List | Out-String

            if (![string]::IsNullOrEmpty($inputName)) {
                $name = $inputName
            } elseif (![string]::IsNullOrEmpty($settings.Name)) {
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
                    StepSummaryMode = $settings.Test.CodeCoverage.StepSummary_Mode ?? 'Missed, Files'
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

        # Calculate job run conditions
        LogGroup 'Calculate Job Run Conditions:' {
            # Common conditions
            $isPR = $env:GITHUB_EVENT_NAME -eq 'pull_request'
            $isOpenOrUpdatedPR = $isPR -and $env:GITHUB_EVENT_ACTION -ne 'closed'
            $isAbandonedPR = $isPR -and $env:GITHUB_EVENT_ACTION -eq 'closed' -and $env:GITHUB_EVENT_PULL_REQUEST_MERGED -ne 'true'
            $isMergedPR = $isPR -and $env:GITHUB_EVENT_PULL_REQUEST_MERGED -eq 'true'
            $isNotAbandonedPR = -not $isAbandonedPR

            Write-Host "isPR: $isPR"
            Write-Host "isOpenOrUpdatedPR: $isOpenOrUpdatedPR"
            Write-Host "isAbandonedPR: $isAbandonedPR"
            Write-Host "isMergedPR: $isMergedPR"
            Write-Host "isNotAbandonedPR: $isNotAbandonedPR"
        }

        # Get-TestSuites
        if ($settings.Test.Skip) {
            Write-Host 'Skipping all tests.'
            $sourceCodeTestSuites = @()
            $psModuleTestSuites = @()
            $moduleTestSuites = @()
        } else {

            # Define test configurations as an array of hashtables.
            $linux = [PSCustomObject]@{ RunsOn = 'ubuntu-latest'; OSName = 'Linux' }
            $macOS = [PSCustomObject]@{ RunsOn = 'macos-latest'; OSName = 'macOS' }
            $windows = [PSCustomObject]@{ RunsOn = 'windows-latest'; OSName = 'Windows' }

            LogGroup 'Source Code Test Suites:' {
                $sourceCodeTestSuites = if ($settings.Test.SourceCode.Skip) {
                    Write-Host 'Skipping all source code tests.'
                    @()
                } else {
                    @(
                        if (-not $settings.Test.Linux.Skip -and -not $settings.Test.SourceCode.Linux.Skip) { $linux }
                        if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.SourceCode.MacOS.Skip) { $macOS }
                        if (-not $settings.Test.Windows.Skip -and -not $settings.Test.SourceCode.Windows.Skip) { $windows }
                    )
                }
                $sourceCodeTestSuites | Format-Table -AutoSize | Out-String
            }

            LogGroup 'PSModule Test Suites:' {
                $psModuleTestSuites = if ($settings.Test.PSModule.Skip) {
                    Write-Host 'Skipping all PSModule tests.'
                    @()
                } else {
                    @(
                        if (-not $settings.Test.Linux.Skip -and -not $settings.Test.PSModule.Linux.Skip) { $linux }
                        if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.PSModule.MacOS.Skip) { $macOS }
                        if (-not $settings.Test.Windows.Skip -and -not $settings.Test.PSModule.Windows.Skip) { $windows }
                    )
                }
                $psModuleTestSuites | Format-Table -AutoSize | Out-String
            }

            LogGroup 'Module Local Test Suites:' {
                if ($settings.Test.Module.Skip) {
                    Write-Host 'Skipping all module tests.'
                    $moduleTestSuites = @()
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
                            Searches for test configuration, container, or test script files within the specified folder.

                            .OUTPUTS
                            System.IO.FileInfo[]
                            Returns an array of FileInfo objects representing the test items found.
                        #>
                        [CmdletBinding()]
                        param (
                            # The path to the folder containing test items.
                            [string]$FolderPath
                        )

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
                            Recursively finds all test directories.

                            .DESCRIPTION
                            Recursively searches for all subdirectories within the specified path.

                            .OUTPUTS
                            System.String[]
                            Returns an array of directory paths.
                        #>
                        [CmdletBinding()]
                        param(
                            #The root path to search for test directories.
                            [string]$Path
                        )

                        $directories = @()
                        $childDirs = Get-ChildItem -Path $Path -Directory

                        foreach ($dir in $childDirs) {
                            $directories += $dir.FullName
                            $directories += Find-TestDirectory -Path $dir.FullName
                        }

                        return $directories
                    }

                    $allTestFolders = @($testsPath) + (Find-TestDirectory -Path $testsPath)

                    $moduleTestSuites = [System.Collections.ArrayList]::new()
                    foreach ($folder in $allTestFolders) {
                        $testItems = Get-TestItemsFromFolder -FolderPath $folder
                        foreach ($item in $testItems) {
                            if (-not $settings.Test.Linux.Skip -and -not $settings.Test.Module.Linux.Skip) {
                                [void]$moduleTestSuites.Add([pscustomobject]@{
                                        RunsOn   = $linux.RunsOn
                                        OSName   = $linux.OSName
                                        TestPath = Resolve-Path -Path $item.FullName -Relative
                                        TestName = ($item.BaseName).Split('.')[0]
                                    })
                            }
                            if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.Module.MacOS.Skip) {
                                [void]$moduleTestSuites.Add([pscustomobject]@{
                                        RunsOn   = $macOS.RunsOn
                                        OSName   = $macOS.OSName
                                        TestPath = Resolve-Path -Path $item.FullName -Relative
                                        TestName = ($item.BaseName).Split('.')[0]
                                    })
                            }
                            if (-not $settings.Test.Windows.Skip -and -not $settings.Test.Module.Windows.Skip) {
                                [void]$moduleTestSuites.Add([pscustomobject]@{
                                        RunsOn   = $windows.RunsOn
                                        OSName   = $windows.OSName
                                        TestPath = Resolve-Path -Path $item.FullName -Relative
                                        TestName = ($item.BaseName).Split('.')[0]
                                    })
                            }
                        }
                    }
                }
                $moduleTestSuites | Format-Table -AutoSize | Out-String
            }
        }

        # Add test suites to settings
        $settings | Add-Member -MemberType NoteProperty -Name TestSuites -Value ([pscustomobject]@{
                SourceCode = $sourceCodeTestSuites
                PSModule   = $psModuleTestSuites
                Module     = $moduleTestSuites
            })

        # Add input parameters directly to settings
        $settings | Add-Member -MemberType NoteProperty -Name SettingsPath -Value $env:PSMODULE_GET_SETTINGS_INPUT_SettingsPath
        $settings | Add-Member -MemberType NoteProperty -Name Debug -Value ($env:PSMODULE_GET_SETTINGS_INPUT_Debug ?? 'false')
        $settings | Add-Member -MemberType NoteProperty -Name Verbose -Value ($env:PSMODULE_GET_SETTINGS_INPUT_Verbose ?? 'false')
        $settings | Add-Member -MemberType NoteProperty -Name Version -Value $env:PSMODULE_GET_SETTINGS_INPUT_Version
        $settings | Add-Member -MemberType NoteProperty -Name Prerelease -Value ($env:PSMODULE_GET_SETTINGS_INPUT_Prerelease ?? 'false')
        $settings | Add-Member -MemberType NoteProperty -Name WorkingDirectory -Value $env:PSMODULE_GET_SETTINGS_INPUT_WorkingDirectory

        # Calculate job-specific conditions and add to settings
        LogGroup 'Calculate Job Run Conditions:' {
            # Create Run object with all job-specific conditions
            $settings | Add-Member -MemberType NoteProperty -Name Run -Value ([pscustomobject]@{
                    LintRepository       = $isOpenOrUpdatedPR -and (-not $settings.Linter.Skip)
                    BuildModule          = $isNotAbandonedPR -and (-not $settings.Build.Module.Skip)
                    TestSourceCode       = $isNotAbandonedPR -and ($sourceCodeTestSuites.Count -gt 0)
                    LintSourceCode       = $isNotAbandonedPR -and ($sourceCodeTestSuites.Count -gt 0)
                    TestModule           = $isNotAbandonedPR -and ($psModuleTestSuites.Count -gt 0)
                    BeforeAllModuleLocal = $isNotAbandonedPR -and ($moduleTestSuites.Count -gt 0)
                    TestModuleLocal      = $isNotAbandonedPR -and ($moduleTestSuites.Count -gt 0)
                    AfterAllModuleLocal  = $true # Always runs if Test-ModuleLocal was not skipped
                    GetTestResults       = $isNotAbandonedPR -and (-not $settings.Test.TestResults.Skip) -and (
                        $sourceCodeTestSuites.Count -gt 0 -or $psModuleTestSuites.Count -gt 0 -or $moduleTestSuites.Count -gt 0
                    )
                    GetCodeCoverage      = $isNotAbandonedPR -and (-not $settings.Test.CodeCoverage.Skip) -and (
                        $psModuleTestSuites.Count -gt 0 -or $moduleTestSuites.Count -gt 0
                    )
                    PublishModule        = $isPR -and (
                        $isAbandonedPR -or
                        ($isOpenOrUpdatedPR -or $isMergedPR)
                    )
                    BuildDocs            = $isNotAbandonedPR -and (-not $settings.Build.Docs.Skip)
                    BuildSite            = $isNotAbandonedPR -and (-not $settings.Build.Site.Skip)
                    PublishSite          = $isMergedPR
                })

            Write-Host 'Run conditions:'
            $settings.Run | Format-List | Out-String
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
    } catch {
        throw $_
    }
}

end {
    Write-Debug "[$scriptName] - End"
}
