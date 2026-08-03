# Crops a PNG down to its non-background content, plus a fixed margin.
# Used by render.sh to tighten pieces.png after OpenSCAD's --viewall
# leaves a lot of unused border (viewall fits the render's bounding
# SPHERE to the image, not the actual 2D silhouette, so a wide/flat
# grid of parts ends up small in the middle of a mostly-empty frame).
#
# Usage: trim_png.ps1 <path-to-png> [margin-px]

param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$Margin = 40
)

Add-Type -AssemblyName System.Drawing

$bmp = [System.Drawing.Bitmap]::FromFile($Path)
$rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$stride = $data.Stride
$w = $bmp.Width
$h = $bmp.Height
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$bmp.UnlockBits($data)

# Background = top-left pixel (BGRA byte order in memory).
$bgB = $bytes[0]; $bgG = $bytes[1]; $bgR = $bytes[2]
$tol = 8

$minX = $w; $maxX = -1; $minY = $h; $maxY = -1

for ($y = 0; $y -lt $h; $y++) {
    $rowOff = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
        $o = $rowOff + $x * 4
        $b = $bytes[$o]; $g = $bytes[$o + 1]; $r = $bytes[$o + 2]
        if ([Math]::Abs($r - $bgR) -gt $tol -or [Math]::Abs($g - $bgG) -gt $tol -or [Math]::Abs($b - $bgB) -gt $tol) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -lt 0) {
    Write-Warning "trim_png.ps1: no non-background content found in $Path -- leaving it untouched"
    $bmp.Dispose()
    exit 0
}

$cropX = [Math]::Max(0, $minX - $Margin)
$cropY = [Math]::Max(0, $minY - $Margin)
$cropR = [Math]::Min($w - 1, $maxX + $Margin)
$cropB = [Math]::Min($h - 1, $maxY + $Margin)
$cropW = $cropR - $cropX + 1
$cropH = $cropB - $cropY + 1

$cropRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$cropped = New-Object System.Drawing.Bitmap($cropW, $cropH)
$g2 = [System.Drawing.Graphics]::FromImage($cropped)
$g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$bmp.Dispose()

$cropped.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
$cropped.Dispose()

Write-Output "trim_png.ps1: cropped to ${cropW}x${cropH} (from ${w}x${h})"
