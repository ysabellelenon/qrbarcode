# Create a timestamp for the log file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$logFile = "app_diagnostic_$timestamp.txt"

Write-Output "QRBarcode Diagnostic Log - $timestamp" | Tee-Object -FilePath $logFile

Write-Output "`n=== System Information ===" | Tee-Object -FilePath $logFile -Append
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer | Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Virtualization Check ===" | Tee-Object -FilePath $logFile -Append
$hyperv = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
Write-Output "System Model: $hyperv" | Tee-Object -FilePath $logFile -Append
$virtualization = Get-WmiObject Win32_ComputerSystem | Select-Object Manufacturer, Model, HypervisorPresent
$virtualization | Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Display Adapters (Detailed) ===" | Tee-Object -FilePath $logFile -Append
Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion, VideoProcessor, VideoMemoryType, AdapterRAM, DriverDate | Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Window Manager Information ===" | Tee-Object -FilePath $logFile -Append
Get-Process -Name "dwm", "explorer" -ErrorAction SilentlyContinue | Select-Object Name, Id, StartTime, CPU, WorkingSet | Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Recent Application Errors (Last 30 minutes) ===" | Tee-Object -FilePath $logFile -Append
Get-WinEvent -FilterHashtable @{
    LogName='Application'
    Level=2  # Error
    StartTime=(Get-Date).AddMinutes(-30)
} -ErrorAction SilentlyContinue | Select-Object TimeCreated, Source, Message | Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Flutter/QRBarcode Related Events (Last 30 minutes) ===" | Tee-Object -FilePath $logFile -Append
Get-WinEvent -FilterHashtable @{
    LogName='Application'
    StartTime=(Get-Date).AddMinutes(-30)
} -ErrorAction SilentlyContinue | Where-Object { 
    $_.Message -match "qrbarcode|flutter|MSVCP140|VCRUNTIME140|OpenGL|Direct3D"
} | Select-Object TimeCreated, Source, Message | Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Running Processes (Graphics Related) ===" | Tee-Object -FilePath $logFile -Append
Get-Process | Where-Object { $_.Name -match 'qrbarcode|flutter|dwm|explorer|parallels' } | 
    Select-Object Name, Id, Path, StartTime, CPU, WorkingSet, Handle | 
    Format-List | Tee-Object -FilePath $logFile -Append

Write-Output "`n=== Visual C++ Runtime Information ===" | Tee-Object -FilePath $logFile -Append
$vcRedistKeys = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86"
)

foreach ($key in $vcRedistKeys) {
    if (Test-Path $key) {
        Get-ItemProperty $key | Select-Object Version, Installed | Format-List | Tee-Object -FilePath $logFile -Append
    }
}

Write-Output "`n=== Window Information ===" | Tee-Object -FilePath $logFile -Append
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
        
        [DllImport("user32.dll")]
        public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
        
        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);
        
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    }
"@

$windows = New-Object System.Collections.ArrayList
[Win32]::EnumWindows({
    param([IntPtr]$hwnd, [IntPtr]$lparam)
    $title = New-Object System.Text.StringBuilder 256
    [Win32]::GetWindowText($hwnd, $title, 256)
    if ([Win32]::IsWindowVisible($hwnd) -and $title.Length -gt 0) {
        $windows.Add(@{
            Handle = $hwnd
            Title = $title.ToString()
        }) | Out-Null
    }
    return $true
}, [IntPtr]::Zero)

$windows | Where-Object { $_.Title -match 'QRBarcode|Flutter' } | 
    Format-Table -AutoSize | Out-String | Tee-Object -FilePath $logFile -Append

Write-Output "`nDiagnostic log has been saved to: $logFile"
Write-Output "Please check this file for detailed information about any errors." 