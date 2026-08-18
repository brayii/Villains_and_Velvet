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
        # Decimal bounds force the floating-point overload. Integer bounds
        # silently rounded most quiet samples to zero.
        $value = [Math]::Max(-1.0, [Math]::Min(1.0, [double]$sample))
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
    (Tone $f $t) * 0.22 * [Math]::Sin([Math]::PI*[Math]::Min(1.0,[double](($t%0.3)/0.3))) * (1-0.35*$p)
})
Write-Wave "defeat" (New-Sound 0.95 { param($t,$p)
    $f = if ($t -lt .30) {392.00} elseif ($t -lt .60) {311.13} else {233.08}
    ((Tone $f $t) + 0.35*(Tone ($f/2) $t)) * 0.20 * (1-$p)
})

# The music generator is compiled so a full seamless loop can be rendered quickly.
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;

public static class VelvetMusicGenerator {
    static double Frequency(int midi) { return 440.0 * Math.Pow(2.0, (midi - 69) / 12.0); }
    static double Sine(int midi, double t) { return Math.Sin(2.0 * Math.PI * Frequency(midi) * t); }
    static double NoteEnvelope(double phase, double length) {
        return (1.0 - Math.Exp(-55.0 * phase)) * Math.Exp(-4.5 * phase / length);
    }

    public static void Generate(string path) {
        const int rate = 22050;
        const double bpm = 84.0;
        double beat = 60.0 / bpm;
        double barLength = beat * 4.0;
        int[][] chords = {
            new[]{50,57,62,65}, new[]{46,53,58,62}, new[]{41,48,53,57}, new[]{48,55,60,64},
            new[]{50,57,62,65}, new[]{43,50,55,58}, new[]{45,52,57,61}, new[]{45,52,57,61},
            new[]{50,57,62,65}, new[]{46,53,58,62}, new[]{41,48,53,57}, new[]{48,55,60,64},
            new[]{43,50,55,58}, new[]{46,53,58,62}, new[]{45,52,57,61}, new[]{50,57,62,65}
        };
        int[] melody = {
            74,77,81,77, 72,74,70,69, 69,72,77,76, 67,72,76,74,
            74,77,81,84, 79,77,74,70, 73,76,81,76, 73,71,69,73,
            74,77,81,77, 82,81,77,74, 72,77,81,79, 76,74,72,67,
            70,74,79,77, 70,72,74,77, 76,73,69,73, 74,72,69,74
        };
        int count = (int)Math.Round(chords.Length * barLength * rate);
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        using (var writer = new BinaryWriter(File.Create(path))) {
            int bytes = count * 2;
            writer.Write(Encoding.ASCII.GetBytes("RIFF")); writer.Write(36 + bytes);
            writer.Write(Encoding.ASCII.GetBytes("WAVEfmt ")); writer.Write(16);
            writer.Write((short)1); writer.Write((short)1); writer.Write(rate); writer.Write(rate * 2);
            writer.Write((short)2); writer.Write((short)16);
            writer.Write(Encoding.ASCII.GetBytes("data")); writer.Write(bytes);
            uint noiseState = 84721;
            for (int i = 0; i < count; i++) {
                double t = (double)i / rate;
                int bar = Math.Min(chords.Length - 1, (int)(t / barLength));
                double inBar = t - bar * barLength;
                double barShape = Math.Sin(Math.PI * inBar / barLength);
                double sample = 0.0;

                // Soft chamber strings establish the fairy-tale harmony.
                foreach (int note in chords[bar]) sample += Sine(note, t) * 0.025 * barShape;

                // A harp-like broken chord gives the loop gentle forward motion.
                double eighth = beat / 2.0;
                int arpStep = (int)(inBar / eighth);
                double arpPhase = inBar - arpStep * eighth;
                int arpNote = chords[bar][arpStep % 4] + 12;
                sample += (Sine(arpNote, t) + 0.35 * Sine(arpNote + 12, t))
                    * 0.075 * NoteEnvelope(arpPhase, eighth);

                // Rounded bass notes keep the music calm rather than percussive.
                int beatStep = (int)(inBar / beat);
                double beatPhase = inBar - beatStep * beat;
                sample += Sine(chords[bar][0] - 12, t) * 0.09 * NoteEnvelope(beatPhase, beat);

                // Bell melody: charming on top, with a few minor-key turns underneath.
                int melodyIndex = bar * 4 + beatStep;
                int melodyNote = melody[Math.Min(melody.Length - 1, melodyIndex)];
                sample += (Sine(melodyNote, t) + 0.28 * Sine(melodyNote + 12, t))
                    * 0.055 * NoteEnvelope(beatPhase, beat * 0.82);

                // Barely audible brushed pulse adds life without competing with card sounds.
                noiseState = noiseState * 1664525u + 1013904223u;
                double noise = ((noiseState >> 8) / 16777215.0) * 2.0 - 1.0;
                double brushPhase = inBar % eighth;
                sample += noise * 0.008 * NoteEnvelope(brushPhase, eighth * 0.35);

                sample = Math.Max(-0.92, Math.Min(0.92, sample));
                writer.Write((short)Math.Round(sample * 32760.0));
            }
        }
    }
}
'@

[VelvetMusicGenerator]::Generate((Join-Path $OutputDirectory "velvet_storybook_loop.wav"))

Write-Host "Generated feedback audio and music in $OutputDirectory"
