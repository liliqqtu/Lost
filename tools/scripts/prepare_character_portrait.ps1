param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Output,
    [string]$Preview,
    [ValidateRange(8, 64)][int]$Colors = 20
)

# Normalize generated portrait art; never overwrite an existing deliverable.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (Test-Path -LiteralPath $Output) { throw "Output already exists: $Output" }
if ($Preview -and (Test-Path -LiteralPath $Preview)) { throw "Preview already exists: $Preview" }
$sourceImage = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $Source).Path)
if ([math]::Abs($sourceImage.Width / $sourceImage.Height - 80.0 / 72.0) -gt 0.02) {
    $sourceImage.Dispose()
    throw 'Source aspect ratio must be approximately 10:9; compose/crop explicitly first.'
}
$portrait = [System.Drawing.Bitmap]::new(80, 72)
$graphics = [System.Drawing.Graphics]::FromImage($portrait)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphics.DrawImage($sourceImage, [System.Drawing.Rectangle]::new(0, 0, 80, 72))
$graphics.Dispose()
$sourceImage.Dispose()

# Build a deterministic palette from opaque samples. Binary alpha avoids fringes.
$samples = [System.Collections.Generic.List[object]]::new()
for ($y = 0; $y -lt 72; $y++) {
    for ($x = 0; $x -lt 80; $x++) {
        $color = $portrait.GetPixel($x, $y)
        if ($color.A -ge 128) { $samples.Add(@([double]$color.R, [double]$color.G, [double]$color.B)) }
    }
}
if ($samples.Count -eq 0) { throw 'Source has no visible portrait pixels.' }
$centers = [System.Collections.Generic.List[object]]::new()
$centers.Add($samples[0].Clone())
for ($index = 1; $index -lt $Colors; $index++) {
    $largest = -1.0
    $candidate = $samples[0]
    foreach ($sample in $samples) {
        $nearest = [double]::MaxValue
        foreach ($center in $centers) {
            $distance = 0.0
            for ($c = 0; $c -lt 3; $c++) { $distance += [math]::Pow($sample[$c] - $center[$c], 2) }
            if ($distance -lt $nearest) { $nearest = $distance }
        }
        if ($nearest -gt $largest) { $largest = $nearest; $candidate = $sample }
    }
    $centers.Add($candidate.Clone())
}
for ($iteration = 0; $iteration -lt 10; $iteration++) {
    $sums = @()
    for ($index = 0; $index -lt $Colors; $index++) { $sums += ,@(0.0, 0.0, 0.0, 0.0) }
    foreach ($sample in $samples) {
        $nearest = [double]::MaxValue
        $best = 0
        for ($index = 0; $index -lt $Colors; $index++) {
            $distance = 0.0
            for ($c = 0; $c -lt 3; $c++) { $distance += [math]::Pow($sample[$c] - $centers[$index][$c], 2) }
            if ($distance -lt $nearest) { $nearest = $distance; $best = $index }
        }
        for ($c = 0; $c -lt 3; $c++) { $sums[$best][$c] += $sample[$c] }
        $sums[$best][3]++
    }
    for ($index = 0; $index -lt $Colors; $index++) {
        if ($sums[$index][3] -eq 0) { continue }
        for ($c = 0; $c -lt 3; $c++) { $centers[$index][$c] = $sums[$index][$c] / $sums[$index][3] }
    }
}
$palette = @($centers | ForEach-Object {
    [System.Drawing.Color]::FromArgb(255, [int][math]::Round($_[0]), [int][math]::Round($_[1]), [int][math]::Round($_[2]))
})
for ($y = 0; $y -lt 72; $y++) {
    for ($x = 0; $x -lt 80; $x++) {
        $color = $portrait.GetPixel($x, $y)
        if ($color.A -lt 128) {
            $portrait.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            continue
        }
        $nearest = [double]::MaxValue
        $chosen = $palette[0]
        foreach ($entry in $palette) {
            $distance = [math]::Pow($color.R - $entry.R, 2) + [math]::Pow($color.G - $entry.G, 2) + [math]::Pow($color.B - $entry.B, 2)
            if ($distance -lt $nearest) { $nearest = $distance; $chosen = $entry }
        }
        $portrait.SetPixel($x, $y, $chosen)
    }
}
$portrait.Save([System.IO.Path]::GetFullPath($Output), [System.Drawing.Imaging.ImageFormat]::Png)
if ($Preview) {
    $enlarged = [System.Drawing.Bitmap]::new(480, 432)
    $graphics = [System.Drawing.Graphics]::FromImage($enlarged)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.DrawImage($portrait, [System.Drawing.Rectangle]::new(0, 0, 480, 432))
    $graphics.Dispose()
    $enlarged.Save([System.IO.Path]::GetFullPath($Preview), [System.Drawing.Imaging.ImageFormat]::Png)
    $enlarged.Dispose()
}
$portrait.Dispose()
Write-Output "Saved 80x72 RGBA portrait, at most $Colors opaque colors: $Output"
