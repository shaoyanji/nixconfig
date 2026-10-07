param(
    [Parameter(Position=0)]
    [string]$Command = "list",

    [Parameter(Position=1)]
    [string]$Target = "",

    [switch]$Json,
    [string]$Browser = "chrome,msedge"
)

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

function Get-Tabs {
    $processNames = $Browser.Split(',')
    $procs = Get-Process $processNames -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle }
    $results = @()
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::TabItem
    )
    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker

    foreach ($proc in $procs) {
        $element = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
        $tabs = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
        $index = 1
        foreach ($tab in $tabs) {
            $parent = $walker.GetParent($tab)
            if ($parent.Current.ClassName -match 'TabContainerView|TabStrip') {
                $selPattern = $null
                try {
                    $selPattern = $tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                } catch {}
                $isSelected = if ($selPattern) { $selPattern.Current.IsSelected } else { $false }
                
                $results += [PSCustomObject]@{
                    Index = $index
                    Title = $tab.Current.Name
                    Browser = $proc.ProcessName
                    ProcessId = $proc.Id
                    MainWindowHandle = $proc.MainWindowHandle
                    IsSelected = $isSelected
                    AutomationElement = $tab
                }
                $index++
            }
        }
    }
    return $results
}

switch ($Command.ToLower()) {
    "list" {
        $tabs = Get-Tabs
        if ($Json) {
            $jsonTabs = $tabs | ForEach-Object {
                [PSCustomObject]@{
                    index = $_.Index
                    title = $_.Title
                    browser = $_.Browser
                    processId = $_.ProcessId
                    isSelected = $_.IsSelected
                }
            }
            $jsonTabs | ConvertTo-Json -Depth 3
        } else {
            Write-Host ("`n" + ("=" * 70))
            Write-Host ("  OPEN BROWSER TABS ({0})" -f $tabs.Count)
            Write-Host ("=" * 70)
            foreach ($t in $tabs) {
                $star = if ($t.IsSelected) { "[ACTIVE] " } else { "         " }
                Write-Host ("{0} #{1,-2} : {2}" -f $star, $t.Index, $t.Title)
            }
            Write-Host ("=" * 70 + "`n")
        }
    }

    "active" {
        $tabs = Get-Tabs
        $active = $tabs | Where-Object { $_.IsSelected } | Select-Object -First 1
        if ($Json) {
            if ($active) {
                [PSCustomObject]@{
                    index = $active.Index
                    title = $active.Title
                    browser = $active.Browser
                    processId = $active.ProcessId
                } | ConvertTo-Json
            } else {
                "{}"
            }
        } else {
            if ($active) {
                Write-Host ("Active Tab #{0}: {1} ({2})" -f $active.Index, $active.Title, $active.Browser)
            } else {
                Write-Host "No active tab detected."
            }
        }
    }

    "focus" {
        if (-not $Target) {
            Write-Error "Please specify a tab index or title keyword to focus."
            exit 1
        }
        $tabs = Get-Tabs
        $found = $null
        if ($Target -match '^\d+$') {
            $idx = [int]$Target
            $found = $tabs | Where-Object { $_.Index -eq $idx } | Select-Object -First 1
        } else {
            $found = $tabs | Where-Object { $_.Title -like "*$Target*" } | Select-Object -First 1
        }

        if ($found) {
            # Restore and focus window
            [Win32]::ShowWindow($found.MainWindowHandle, 9) # SW_RESTORE
            [Win32]::SetForegroundWindow($found.MainWindowHandle)
            # Select Tab
            $pat = $found.AutomationElement.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            $pat.Select()
            Write-Host ("Switched to Tab #{0}: {1}" -f $found.Index, $found.Title)
        } else {
            Write-Error ("Tab matching '{0}' not found." -f $Target)
            exit 1
        }
    }

    "close" {
        if (-not $Target) {
            Write-Error "Please specify a tab index or title keyword to close."
            exit 1
        }
        $tabs = Get-Tabs
        $found = $null
        if ($Target -match '^\d+$') {
            $idx = [int]$Target
            $found = $tabs | Where-Object { $_.Index -eq $idx } | Select-Object -First 1
        } else {
            $found = $tabs | Where-Object { $_.Title -like "*$Target*" } | Select-Object -First 1
        }

        if ($found) {
            [Win32]::ShowWindow($found.MainWindowHandle, 9)
            [Win32]::SetForegroundWindow($found.MainWindowHandle)
            $pat = $found.AutomationElement.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            $pat.Select()
            Start-Sleep -Milliseconds 100
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.SendKeys]::SendWait("^{w}")
            Write-Host ("Closed Tab #{0}: {1}" -f $found.Index, $found.Title)
        } else {
            Write-Error ("Tab matching '{0}' not found." -f $Target)
            exit 1
        }
    }

    "open" {
        if (-not $Target) {
            Write-Error "Please specify a URL to open."
            exit 1
        }
        Start-Process $Target
        Write-Host ("Opened URL: {0}" -f $Target)
    }

    default {
        Write-Host "Usage: wsl-browser.ps1 [list|active|focus|close|open] [target] [-Json]"
    }
}
