param(
    [switch]$Probe,
    [string]$InputPath = "",
    [string]$OutputPath = "",
    [string]$VoiceName = "Microsoft Huihui Desktop"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

$synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $voice = $synthesizer.GetInstalledVoices() |
        Where-Object {
            $_.Enabled -and $_.VoiceInfo.Name -eq $VoiceName
        } |
        Select-Object -First 1
    if ($null -eq $voice) {
        throw "Required voice is not installed: $VoiceName"
    }

    if ($Probe) {
        exit 0
    }
    if ([string]::IsNullOrWhiteSpace($InputPath) -or
        [string]::IsNullOrWhiteSpace($OutputPath)) {
        throw "InputPath and OutputPath are required."
    }
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        throw "Input text file does not exist."
    }

    $text = [System.IO.File]::ReadAllText(
        $InputPath,
        [System.Text.Encoding]::UTF8
    )
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Input text is empty."
    }

    $synthesizer.SelectVoice($VoiceName)
    $synthesizer.Rate = 2
    $synthesizer.Volume = 100
    $synthesizer.SetOutputToWaveFile($OutputPath)
    $synthesizer.Speak($text)
    $synthesizer.SetOutputToNull()
}
finally {
    $synthesizer.Dispose()
}
