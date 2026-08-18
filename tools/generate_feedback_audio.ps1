param([string]$OutputDirectory = "$PSScriptRoot\..\datafiles\audio")

$sampleRate = 22050
$random = [System.Random]::new(84721)

function Write-Wave([string]$Name, [double[]]$Samples) {
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $path = Join-Path $OutputDirectory ($Name + ".wav")
    $stream = [System.IO.File]::Create($path)
    $writer = [System.IO.BinaryWriter]::new($stream)
    $dataBytes = $Samples.Length * 2
    $writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $dataBytes))
    $writer.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
    $writer.Write([int]16); $writer.Write([int16]1); $writer.Write([int16]1)
    $writer.Write([int]$sampleRate); $writer.Write([int]($sampleRate * 2))
    $writer.Write([int16]2); $writer.Write([int16]16)
    $writer.Write([Text.Encoding]::ASCII.GetBytes("data")); $writer.Write([int]$dataBytes)
    foreach ($sample in $Samples) {
        $value = [Math]::Max(-1, [Math]::Min(1, $sample))
        $writer.Write([int16]($value * 32760))
    }
    $writer.Dispose(); $stream.Dispose()
}

function New-Sound([double]$Seconds, [scriptblock]$Wave) {
    $count = [int]($Seconds * $sampleRate)
    $samples = [double[]]::new($count)
    for ($i = 0; $i -lt $count; $i++) {
        $t = $i / $sampleRate
        $samples[$i] = & $Wave $t ($i / $count)
    }
    return $samples
}

function Noise { return $random.NextDouble() * 2 - 1 }
function Tone([double]$Frequency, [double]$Time) { return [Math]::Sin(2 * [Math]::PI * $Frequency * $Time) }
function Pulse([double]$Time, [double]$At, [double]$Width) {
    $d = ($Time - $At) / $Width
    return [Math]::Exp(-$d * $d * 5)
}

Write-Wave "card_pickup" (New-Sound 0.16 { param($t,$p)
    (Noise) * 0.16 * [Math]::Sin([Math]::PI * $p) + (Tone (420 + 180 * $p) $t) * 0.06 * (1-$p)
})
Write-Wave "card_drop" (New-Sound 0.20 { param($t,$p)
    ((Noise) * 0.12 + (Tone (105 - 35*$p) $t) * 0.34) * [Math]::Exp(-8*$p)
})
Write-Wave "button_confirm" (New-Sound 0.11 { param($t,$p)
    ((Tone 520 $t) + (Tone 780 $t) * 0.45) * 0.15 * [Math]::Exp(-10*$p)
})
Write-Wave "attack_hit" (New-Sound 0.30 { param($t,$p)
    ((Noise) * 0.30 + (Tone (145-55*$p) $t) * 0.48) * [Math]::Exp(-7*$p)
})
Write-Wave "minion_move" (New-Sound 0.42 { param($t,$p)
    $steps = (Pulse $t 0.08 0.045) + (Pulse $t 0.26 0.055)
    ((Noise) * 0.12 + (Tone 82 $t) * 0.28) * $steps
})
Write-Wave "event_reveal" (New-Sound 0.55 { param($t,$p)
    $shimmer = (Tone (460+520*$p) $t) + 0.45*(Tone (710+680*$p) $t)
    $shimmer * 0.16 * [Math]::Sin([Math]::PI*$p) + (Noise)*0.035*(1-$p)
})
Write-Wave "leader_damage" (New-Sound 0.40 { param($t,$p)
    ((Tone (92-30*$p) $t) * 0.58 + (Noise)*0.22) * [Math]::Exp(-5*$p)
})
Write-Wave "destruction" (New-Sound 0.48 { param($t,$p)
    $cracks = (Pulse $t 0.03 0.018) + (Pulse $t 0.13 0.022) + (Pulse $t 0.24 0.025)
    ((Noise)*0.34*$cracks) + (Tone (125-70*$p) $t)*0.22*[Math]::Exp(-5*$p)
})
Write-Wave "healing" (New-Sound 0.65 { param($t,$p)
    $tone = (Tone 523.25 $t) + 0.7*(Tone 659.25 $t) + 0.45*(Tone 783.99 $t)
    $tone * 0.12 * [Math]::Sin([Math]::PI*$p)
})
Write-Wave "victory" (New-Sound 0.95 { param($t,$p)
    $f = if ($t -lt .28) {523.25} elseif ($t -lt .56) {659.25} else {783.99}
    (Tone $f $t) * 0.22 * [Math]::Sin([Math]::PI*[Math]::Min(1,($t%0.3)/0.3)) * (1-0.35*$p)
})
Write-Wave "defeat" (New-Sound 0.95 { param($t,$p)
    $f = if ($t -lt .30) {392.00} elseif ($t -lt .60) {311.13} else {233.08}
    ((Tone $f $t) + 0.35*(Tone ($f/2) $t)) * 0.20 * (1-$p)
})

Write-Host "Generated feedback audio in $OutputDirectory"
