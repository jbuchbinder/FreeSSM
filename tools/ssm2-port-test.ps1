<#
    ssm2-port-test.ps1 - is this cable usable by FreeSSM?

    Sends a real SSM2 "engine ECU init" request on a serial port and reports
    what comes back. Frame layout and port settings match FreeSSM's own serial
    pass-through interface: 4800 8N1, header 0x80 <ecu> 0xF0 <len>, payload,
    checksum = sum of all preceding bytes (see SSMP2communication_core.cpp and
    libFSSM::calcchecksum).

    Requirements for a meaningful result:
      * cable plugged into the vehicle's OBD-II port (the K-line is pulled up
        by the car - USB power alone produces no echo)
      * ignition ON (engine may be off)
      * no other program holding the port (close VCDS, FreeSSM, ...)

    Usage:  powershell -ExecutionPolicy Bypass -File ssm2-port-test.ps1 [-Port COM4]
#>
param(
    [string]$Port = 'COM4',
    [int]$Tries = 3
)

$ErrorActionPreference = 'Stop'

Write-Host "available ports: $([System.IO.Ports.SerialPort]::GetPortNames() -join ', ')"
Write-Host "testing $Port at 4800 8N1`n"

try {
    $p = New-Object System.IO.Ports.SerialPort $Port,4800,'None',8,'One'
    $p.ReadTimeout = 2000
    $p.Open()
} catch {
    Write-Host "OPEN FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  'Access is denied' means another program holds the port."
    exit 1
}

# 80 10 F0 01 BF 40 = read ECU identification from the engine control unit
$req  = [byte[]](0x80,0x10,0xF0,0x01,0xBF,0x40)
$best = @()

try {
    foreach ($try in 1..$Tries) {
        $p.DiscardInBuffer()
        $p.DiscardOutBuffer()
        $p.Write($req,0,$req.Length)

        $acc      = New-Object System.Collections.Generic.List[byte]
        $deadline = (Get-Date).AddSeconds(2)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 50
            while ($p.BytesToRead -gt 0) {
                $acc.Add([byte]$p.ReadByte())
                $deadline = (Get-Date).AddSeconds(1)   # keep listening while data flows
            }
        }

        if ($acc.Count -gt 0) {
            $hex = ($acc | ForEach-Object { $_.ToString('X2') }) -join ' '
            Write-Host "try $try : $($acc.Count) bytes: $hex"
            if ($acc.Count -gt $best.Count) { $best = $acc.ToArray() }
        } else {
            Write-Host "try $try : nothing"
        }
    }
} finally {
    $p.Close()
}

Write-Host ''
$hexAll  = ($best | ForEach-Object { $_.ToString('X2') }) -join ' '
$echoed  = $hexAll.StartsWith('80 10 F0 01 BF 40')
$replied = $hexAll -match '80 F0 10'

if ($best.Count -eq 0) {
    Write-Host 'VERDICT: no response.' -ForegroundColor Red
    Write-Host '  Either a microcontroller sits in the K-line path (cable unusable by'
    Write-Host '  FreeSSM), or the ignition is off / the car has no K-line on pin 7.'
} elseif ($echoed -and $replied) {
    Write-Host 'VERDICT: the ECU answered. Cable works - use FreeSSM with' -ForegroundColor Green
    Write-Host "  interface type 'serial pass-through' on $Port."
} elseif ($echoed) {
    Write-Host 'VERDICT: own frame echoed back, no ECU reply.' -ForegroundColor Yellow
    Write-Host '  The K-line is transparent, so FreeSSM can drive this cable. No answer'
    Write-Host '  from the ECU usually means ignition off, or this car predates SSM2.'
} else {
    Write-Host 'VERDICT: unexpected data - the cable is talking its own protocol.' -ForegroundColor Yellow
    Write-Host '  Not a transparent K-line interface; FreeSSM cannot use it.'
}
