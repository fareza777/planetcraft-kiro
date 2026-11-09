# Device helpers for testing on a USB-connected Android phone.
#   .\tools\device.ps1 shot <name>        -> test_output\<name>.png
#   .\tools\device.ps1 tap <x> <y>        (physical pixels, landscape)
#   .\tools\device.ps1 swipe <x1> <y1> <x2> <y2> <ms>
#   .\tools\device.ps1 log                -> last godot log lines
#   .\tools\device.ps1 perf               -> [PERF] lines
param([string]$cmd, [string[]]$rest)
$serial = if ($env:ANDROID_SERIAL) { $env:ANDROID_SERIAL } else { (adb devices | Select-String '\tdevice$' | Select-Object -First 1).ToString().Split("`t")[0] }
$root = Split-Path -Parent $PSScriptRoot
switch ($cmd) {
	"shot" {
		$name = if ($rest) { $rest[0] } else { "device" }
		adb -s $serial shell screencap -p /sdcard/pc_shot.png | Out-Null
		adb -s $serial pull /sdcard/pc_shot.png "$root\test_output\$name.png" | Out-Null
		Add-Type -AssemblyName System.Drawing
		$img = [Drawing.Image]::FromFile("$root\test_output\$name.png")
		$small = New-Object Drawing.Bitmap($img, 1200, [int](1200 * $img.Height / $img.Width))
		$img.Dispose()
		$small.Save("$root\test_output\$name.jpg", [Drawing.Imaging.ImageFormat]::Jpeg)
		$small.Dispose()
		"$root\test_output\$name.jpg"
	}
	"tap" { adb -s $serial shell input tap $rest[0] $rest[1] }
	"swipe" { adb -s $serial shell input swipe $rest[0] $rest[1] $rest[2] $rest[3] $rest[4] }
	"log" { adb -s $serial logcat -d -s godot:* | Select-Object -Last 40 }
	"perf" { adb -s $serial logcat -d -s godot:* | Select-String 'PERF|AUTOTEST|ERROR' | Select-Object -Last 30 }
	default { "unknown command" }
}
