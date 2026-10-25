# Converts the Godot .ogg / .mp3 audio to .wav so Unreal can import it. Needs ffmpeg on PATH.
# Output goes to unreal/DarkSouls/Content/ImportSource/Audio/{Music,Vox}; import those folders into /Game/Audio/Music and /Game/Audio/Vox.
$root = Resolve-Path "$PSScriptRoot\..\.."
$out = "$root\unreal\DarkSouls\Content\ImportSource\Audio"
New-Item -ItemType Directory -Force "$out\Music", "$out\Vox" | Out-Null
Get-ChildItem "$root\assets\music" -Include *.mp3, *.ogg, *.wav -Recurse | ForEach-Object {
    ffmpeg -y -i $_.FullName -ar 44100 "$out\Music\$($_.BaseName).wav"
}
Get-ChildItem "$root\assets\audio\vox" -Include *.mp3, *.ogg -Recurse | ForEach-Object {
    ffmpeg -y -i $_.FullName -ar 44100 "$out\Vox\$($_.BaseName).wav"
}
