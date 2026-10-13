@echo off
rem ============================================================================
rem  My Miner: έλεγχος γνησιότητας (pfournar)
rem  Λίγες γραμμές κειμένου: ανοίγει και στο Notepad για να δεις τι κάνει.
rem  Ρωτάει τα ίδια τα Windows αν το MyMiner.exe (ή το .exe μέσα στο zip) είναι
rem  υπογεγραμμένο από το πιστοποιητικό του pfournar και αν άλλαξε έστω ένα byte.
rem  Δεν κατεβάζει, δεν αλλάζει και δεν στέλνει τίποτα. Ισχύει για όλες τις εκδόσεις.
rem ============================================================================
set "MM_SELF=%~f0"
set "MM_ARG=%~1"
set "MM_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "MM_RUN=iex ([IO.File]::ReadAllText($env:MM_SELF,[Text.Encoding]::UTF8).Split([string[]]@('#=='+'PS==#'),2,'None')[1])"
if defined MM_SELFTEST goto selftest
start "" "%MM_PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "%MM_RUN%"
exit /b
:selftest
"%MM_PS%" -NoProfile -ExecutionPolicy Bypass -Command "%MM_RUN%"
exit /b %ERRORLEVEL%
#==PS==#
$env:PSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
$Thumb = 'F02CB4693F3DE90BD74F70635BD5D6058F016C26'

function Test-MyMiner([string]$path) {
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        return @{ ok = $null; title = 'Δεν βρέθηκε το MyMiner.exe'
                  detail = 'Βάλε αυτό το αρχείο μέσα στον φάκελο «My Miner», δίπλα στο MyMiner.exe, ή σύρε εδώ το MyMiner.exe ή το zip.' }
    }
    $file = $path; $tmp = $null; $what = 'Το MyMiner.exe'
    if ($path -like '*.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($path)
        try {
            $entry = $zip.Entries | Where-Object { $_.Name -ieq 'MyMiner.exe' } | Select-Object -First 1
            if (-not $entry) { return @{ ok = $false; title = 'ΠΡΟΣΟΧΗ: δεν είναι zip του My Miner'; detail = 'Δεν περιέχει MyMiner.exe.' } }
            $tmp = Join-Path $env:TEMP ('mm-check-' + [guid]::NewGuid().ToString() + '.exe')
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tmp)
            $file = $tmp; $what = 'Το MyMiner.exe μέσα στο zip'
        } finally { $zip.Dispose() }
    }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $file
        $t = $sig.SignerCertificate.Thumbprint
        $ver = (Get-Item -LiteralPath $file).VersionInfo.ProductVersion
        if ($sig.Status -eq 'HashMismatch') { $why = 'άλλαξε μετά την υπογραφή' }
        elseif (-not $t) { $why = 'δεν είναι υπογεγραμμένο' }
        elseif ($t -ne $Thumb) { $why = 'είναι υπογεγραμμένο από άλλον, όχι από τον pfournar' }
        else { $why = '' }
    } finally { if ($tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
    if (-not $why) { return @{ ok = $true; title = 'ΓΝΗΣΙΟ'; detail = "$what (έκδοση $ver) είναι του pfournar και δεν έχει αλλάξει." } }
    return @{ ok = $false; title = 'ΠΡΟΣΟΧΗ: ΔΕΝ είναι γνήσιο'; detail = "$what $why. Μην το ανοίξεις." }
}

$target = if ($env:MM_ARG) { $env:MM_ARG } else { Join-Path (Split-Path -LiteralPath $env:MM_SELF) 'MyMiner.exe' }
if ($env:MM_SELFTEST) {
    $r = Test-MyMiner $target
    Write-Output $r.title
    if ($r.ok) { exit 0 } elseif ($r.ok -eq $false) { exit 1 } else { exit 2 }
}

Add-Type -AssemblyName PresentationFramework
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="My Miner · Έλεγχος γνησιότητας" Width="460" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" Background="#1C1C1E" AllowDrop="True" FontFamily="Segoe UI">
  <StackPanel Margin="28,22,28,20">
    <TextBlock Name="Mark" FontSize="60" FontWeight="Bold" HorizontalAlignment="Center"/>
    <TextBlock Name="Head" FontSize="22" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center"/>
    <TextBlock Name="Detail" FontSize="13" Foreground="#C7C7CC" TextWrapping="Wrap" TextAlignment="Center" Margin="0,10,0,0"/>
    <TextBlock Name="Path" FontSize="11" Foreground="#8E8E93" TextWrapping="Wrap" TextAlignment="Center" Margin="0,8,0,0"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
      <Button Name="Pick" Content="Έλεγχος άλλου αρχείου…" Padding="14,6" Margin="0,0,10,0"
              Background="#3A3A3C" Foreground="White" BorderThickness="0"/>
      <Button Name="Done" Content="Κλείσιμο" Padding="18,6" IsDefault="True" IsCancel="True"
              Background="#0A84FF" Foreground="White" BorderThickness="0"/>
    </StackPanel>
    <TextBlock Text="Σύρε εδώ ένα MyMiner.exe ή zip για έλεγχο · πιστοποιητικό pfournar F02C…6C26"
               FontSize="10" Foreground="#636366" HorizontalAlignment="Center" Margin="0,14,0,0"/>
  </StackPanel>
</Window>
'@
$w = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$ui = @{}; foreach ($n in 'Mark', 'Head', 'Detail', 'Path', 'Pick', 'Done') { $ui[$n] = $w.FindName($n) }

function Show-Result([string]$path) {
    $r = Test-MyMiner $path
    $color = if ($r.ok) { '#30D158' } elseif ($r.ok -eq $false) { '#FF453A' } else { '#FF9F0A' }
    $ui.Mark.Text = if ($r.ok) { '✓' } elseif ($r.ok -eq $false) { '✗' } else { '?' }
    $ui.Mark.Foreground = $color; $ui.Head.Foreground = $color
    $ui.Head.Text = $r.title; $ui.Detail.Text = $r.detail; $ui.Path.Text = $path
}
$ui.Done.Add_Click({ $w.Close() })
$ui.Pick.Add_Click({
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Filter = 'My Miner (MyMiner.exe, zip)|*.exe;*.zip'
    if ($d.ShowDialog()) { Show-Result $d.FileName }
})
$w.Add_Drop({ $f = $_.Data.GetData('FileDrop'); if ($f) { Show-Result $f[0] } })
Show-Result $target
[void]$w.ShowDialog()
