[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$assetsDirectory = Join-Path $projectRoot 'assets/images'
$androidDirectory = Join-Path $projectRoot 'android/app/src/main/res'
$webDirectory = Join-Path $projectRoot 'web'
New-Item -ItemType Directory -Force -Path $assetsDirectory | Out-Null

function New-RoundedPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-BrandImage {
    param(
        [int]$Inset,
        [bool]$Opaque
    )

    $canvasSize = 1024
    $bitmap = [System.Drawing.Bitmap]::new(
        $canvasSize,
        $canvasSize,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)

        if ($Opaque) {
            $backgroundBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                [System.Drawing.Rectangle]::new(0, 0, $canvasSize, $canvasSize),
                [System.Drawing.Color]::FromArgb(255, 55, 35, 27),
                [System.Drawing.Color]::FromArgb(255, 105, 65, 43),
                [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
            )
            $graphics.FillRectangle($backgroundBrush, 0, 0, $canvasSize, $canvasSize)
            $backgroundBrush.Dispose()
        }

        $boardSize = $canvasSize - 2 * $Inset
        $radius = $boardSize * 0.18

        for ($step = 18; $step -ge 0; $step--) {
            $shadowPath = New-RoundedPath `
                -X ($Inset - $step * 0.25) `
                -Y ($Inset + 12 + $step * 0.45) `
                -Width ($boardSize + $step * 0.5) `
                -Height ($boardSize + $step * 0.5) `
                -Radius ($radius + $step * 0.25)
            $shadowBrush = [System.Drawing.SolidBrush]::new(
                [System.Drawing.Color]::FromArgb(5, 37, 21, 14)
            )
            $graphics.FillPath($shadowBrush, $shadowPath)
            $shadowBrush.Dispose()
            $shadowPath.Dispose()
        }

        $boardPath = New-RoundedPath -X $Inset -Y $Inset -Width $boardSize -Height $boardSize -Radius $radius
        $boardBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.RectangleF]::new($Inset, $Inset, $boardSize, $boardSize),
            [System.Drawing.Color]::FromArgb(255, 231, 183, 112),
            [System.Drawing.Color]::FromArgb(255, 177, 105, 57),
            [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
        )
        $graphics.FillPath($boardBrush, $boardPath)
        $boardBrush.Dispose()

        $graphics.SetClip($boardPath)
        $grainRandom = [System.Random]::new(51)
        for ($line = 0; $line -lt 45; $line++) {
            $y = $Inset + ($line + 1) * $boardSize / 46
            $sway = $grainRandom.Next(-22, 23)
            $grainPen = [System.Drawing.Pen]::new(
                [System.Drawing.Color]::FromArgb(25, 102, 54, 27),
                2 + $grainRandom.Next(0, 3)
            )
            $graphics.DrawBezier(
                $grainPen,
                $Inset - 20,
                $y,
                $Inset + $boardSize * 0.28,
                $y + $sway,
                $Inset + $boardSize * 0.7,
                $y - $sway,
                $Inset + $boardSize + 20,
                $y + 4
            )
            $grainPen.Dispose()
        }

        $first = $Inset + $boardSize * 0.30
        $second = $Inset + $boardSize * 0.70
        $gridStart = $Inset + $boardSize * 0.12
        $gridEnd = $Inset + $boardSize * 0.88
        $gridPen = [System.Drawing.Pen]::new(
            [System.Drawing.Color]::FromArgb(112, 83, 47, 28),
            $boardSize * 0.011
        )
        $gridPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $gridPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        foreach ($position in @($first, $second)) {
            $graphics.DrawLine($gridPen, $position, $gridStart, $position, $gridEnd)
            $graphics.DrawLine($gridPen, $gridStart, $position, $gridEnd, $position)
        }
        $gridPen.Dispose()
        $graphics.ResetClip()

        $stoneRadius = $boardSize * 0.19
        $stones = @(
            @{ X = $first; Y = $first; Black = $true; Cross = $true },
            @{ X = $second; Y = $first; Black = $false; Cross = $false },
            @{ X = $first; Y = $second; Black = $false; Cross = $false },
            @{ X = $second; Y = $second; Black = $true; Cross = $true }
        )

        foreach ($stone in $stones) {
            $x = [float]$stone.X
            $y = [float]$stone.Y
            for ($step = 14; $step -ge 0; $step--) {
                $shadowBrush = [System.Drawing.SolidBrush]::new(
                    [System.Drawing.Color]::FromArgb(4, 43, 25, 16)
                )
                $graphics.FillEllipse(
                    $shadowBrush,
                    $x - $stoneRadius - $step * 0.25 + 6,
                    $y - $stoneRadius + 13 + $step * 0.6,
                    2 * ($stoneRadius + $step * 0.25),
                    2 * ($stoneRadius + $step * 0.25)
                )
                $shadowBrush.Dispose()
            }

            $stoneRect = [System.Drawing.RectangleF]::new(
                $x - $stoneRadius,
                $y - $stoneRadius,
                $stoneRadius * 2,
                $stoneRadius * 2
            )
            if ($stone.Black) {
                $stoneBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                    $stoneRect,
                    [System.Drawing.Color]::FromArgb(255, 72, 72, 67),
                    [System.Drawing.Color]::FromArgb(255, 7, 10, 12),
                    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
                )
                $edgeColor = [System.Drawing.Color]::FromArgb(210, 2, 4, 5)
                $markColor = [System.Drawing.Color]::FromArgb(225, 231, 196, 132)
            }
            else {
                $stoneBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                    $stoneRect,
                    [System.Drawing.Color]::FromArgb(255, 255, 255, 251),
                    [System.Drawing.Color]::FromArgb(255, 207, 201, 188),
                    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
                )
                $edgeColor = [System.Drawing.Color]::FromArgb(170, 132, 117, 96)
                $markColor = [System.Drawing.Color]::FromArgb(205, 74, 48, 34)
            }
            $graphics.FillEllipse($stoneBrush, $stoneRect)
            $stoneBrush.Dispose()

            $edgePen = [System.Drawing.Pen]::new($edgeColor, 4)
            $graphics.DrawEllipse($edgePen, $stoneRect)
            $edgePen.Dispose()

            $highlightBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                [System.Drawing.RectangleF]::new(
                    $x - $stoneRadius * 0.58,
                    $y - $stoneRadius * 0.65,
                    $stoneRadius * 0.82,
                    $stoneRadius * 0.46
                ),
                [System.Drawing.Color]::FromArgb(76, 255, 255, 255),
                [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
                [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
            )
            $graphics.FillEllipse(
                $highlightBrush,
                $x - $stoneRadius * 0.58,
                $y - $stoneRadius * 0.65,
                $stoneRadius * 0.82,
                $stoneRadius * 0.46
            )
            $highlightBrush.Dispose()

            $markPen = [System.Drawing.Pen]::new($markColor, $stoneRadius * 0.105)
            $markPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $markPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $extent = $stoneRadius * 0.26
            if ($stone.Cross) {
                $graphics.DrawLine($markPen, $x - $extent, $y - $extent, $x + $extent, $y + $extent)
                $graphics.DrawLine($markPen, $x + $extent, $y - $extent, $x - $extent, $y + $extent)
            }
            else {
                $graphics.DrawEllipse(
                    $markPen,
                    $x - $extent,
                    $y - $extent,
                    $extent * 2,
                    $extent * 2
                )
            }
            $markPen.Dispose()
        }

        $boardEdgePen = [System.Drawing.Pen]::new(
            [System.Drawing.Color]::FromArgb(175, 116, 67, 36),
            8
        )
        $graphics.DrawPath($boardEdgePen, $boardPath)
        $boardEdgePen.Dispose()
        $boardPath.Dispose()

        return $bitmap
    }
    finally {
        $graphics.Dispose()
    }
}

function Save-ResizedImage {
    param(
        [System.Drawing.Bitmap]$Image,
        [string]$Path,
        [int]$Size
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $resized = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($resized)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage(
            $Image,
            [System.Drawing.Rectangle]::new(0, 0, $Size, $Size),
            0,
            0,
            $Image.Width,
            $Image.Height,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $resized.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $resized.Dispose()
    }
}

$logo = New-BrandImage -Inset 64 -Opaque $false
$launcher = New-BrandImage -Inset 64 -Opaque $true
$maskable = New-BrandImage -Inset 150 -Opaque $true

try {
    $logoPath = Join-Path $assetsDirectory 'gomoku_logo.png'
    $logo.Save($logoPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $androidSizes = @{
        'mipmap-mdpi' = 48
        'mipmap-hdpi' = 72
        'mipmap-xhdpi' = 96
        'mipmap-xxhdpi' = 144
        'mipmap-xxxhdpi' = 192
    }
    foreach ($density in $androidSizes.Keys) {
        $path = Join-Path (Join-Path $androidDirectory $density) 'ic_launcher.png'
        Save-ResizedImage -Image $launcher -Path $path -Size $androidSizes[$density]
    }

    Save-ResizedImage -Image $logo -Path (Join-Path $webDirectory 'favicon.png') -Size 64
    Save-ResizedImage -Image $logo -Path (Join-Path $webDirectory 'icons/Icon-192.png') -Size 192
    Save-ResizedImage -Image $logo -Path (Join-Path $webDirectory 'icons/Icon-512.png') -Size 512
    Save-ResizedImage -Image $maskable -Path (Join-Path $webDirectory 'icons/Icon-maskable-192.png') -Size 192
    Save-ResizedImage -Image $maskable -Path (Join-Path $webDirectory 'icons/Icon-maskable-512.png') -Size 512
}
finally {
    $logo.Dispose()
    $launcher.Dispose()
    $maskable.Dispose()
}

Write-Output 'Branding PNG files generated.'
