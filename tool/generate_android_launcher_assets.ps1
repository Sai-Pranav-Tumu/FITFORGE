Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$brandingDir = Join-Path $repoRoot 'assets\branding'
$resDir = Join-Path $repoRoot 'android\app\src\main\res'

New-Item -ItemType Directory -Force -Path $brandingDir | Out-Null

function New-RoundedRectanglePath {
  param(
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Radius
  )

  $diameter = $Radius * 2
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
  $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
  $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-ParallelogramPath {
  param(
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Slant
  )

  $points = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new($X + $Slant, $Y),
    [System.Drawing.PointF]::new($X + $Width, $Y),
    [System.Drawing.PointF]::new($X + $Width - $Slant, $Y + $Height),
    [System.Drawing.PointF]::new($X, $Y + $Height)
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddPolygon($points)
  return $path
}

function New-DiamondPath {
  param(
    [float]$CenterX,
    [float]$CenterY,
    [float]$Radius
  )

  $points = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new($CenterX, $CenterY - $Radius),
    [System.Drawing.PointF]::new($CenterX + $Radius, $CenterY),
    [System.Drawing.PointF]::new($CenterX, $CenterY + $Radius),
    [System.Drawing.PointF]::new($CenterX - $Radius, $CenterY)
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddPolygon($points)
  return $path
}

function New-Color {
  param(
    [int]$A,
    [int]$R,
    [int]$G,
    [int]$B
  )

  return [System.Drawing.Color]::FromArgb($A, $R, $G, $B)
}

function Draw-Background {
  param(
    [System.Drawing.Graphics]$Graphics,
    [int]$Size
  )

  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  $mainRect = [System.Drawing.RectangleF]::new(0, 0, $Size, $Size)
  $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    [System.Drawing.PointF]::new(0, 0),
    [System.Drawing.PointF]::new($Size, $Size),
    (New-Color 255 9 18 33),
    (New-Color 255 26 86 219)
  )

  try {
    $graphics.FillRectangle($gradient, $mainRect)
  } finally {
    $gradient.Dispose()
  }

  $glowRect = [System.Drawing.RectangleF]::new($Size * 0.46, $Size * 0.12, $Size * 0.46, $Size * 0.46)
  $orangeGlow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $orangeGlow.AddEllipse($glowRect)
  $orangeBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($orangeGlow)
  $orangeBrush.CenterColor = New-Color 185 255 182 144
  $orangeBrush.SurroundColors = [System.Drawing.Color[]]@((New-Color 0 255 182 144))
  try {
    $graphics.FillEllipse($orangeBrush, $glowRect)
  } finally {
    $orangeBrush.Dispose()
    $orangeGlow.Dispose()
  }

  $blueRect = [System.Drawing.RectangleF]::new($Size * -0.18, $Size * 0.66, $Size * 0.62, $Size * 0.38)
  $blueGlow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $blueGlow.AddEllipse($blueRect)
  $blueBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($blueGlow)
  $blueBrush.CenterColor = New-Color 150 78 222 163
  $blueBrush.SurroundColors = [System.Drawing.Color[]]@((New-Color 0 78 222 163))
  try {
    $graphics.FillEllipse($blueBrush, $blueRect)
  } finally {
    $blueBrush.Dispose()
    $blueGlow.Dispose()
  }

  $highlightRect = [System.Drawing.RectangleF]::new($Size * 0.08, $Size * 0.08, $Size * 0.84, $Size * 0.84)
  $highlightPath = New-RoundedRectanglePath -X $highlightRect.X -Y $highlightRect.Y -Width $highlightRect.Width -Height $highlightRect.Height -Radius ($Size * 0.18)
  $highlightPen = New-Object System.Drawing.Pen -ArgumentList @((New-Color 44 255 255 255), [float]($Size * 0.02))
  try {
    $graphics.DrawPath($highlightPen, $highlightPath)
  } finally {
    $highlightPen.Dispose()
    $highlightPath.Dispose()
  }
}

function Draw-ForegroundMark {
  param(
    [System.Drawing.Graphics]$Graphics,
    [int]$Size,
    [switch]$Monochrome
  )

  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  $mainColor = if ($Monochrome) {
    New-Color 255 20 26 38
  } else {
    New-Color 255 246 241 231
  }
  $accentColor = if ($Monochrome) {
    $mainColor
  } else {
    New-Color 255 255 182 144
  }

  $shadowBrush = New-Object System.Drawing.SolidBrush((New-Color 60 0 0 0))
  $mainBrush = New-Object System.Drawing.SolidBrush($mainColor)
  $accentBrush = New-Object System.Drawing.SolidBrush($accentColor)

  $shadowTransform = $graphics.Transform.Clone()
  $baseTransform = $graphics.Transform.Clone()

  try {
    $graphics.TranslateTransform($Size * 0.03, $Size * 0.045)
    $graphics.RotateTransform(-10)
    foreach ($shape in @(
      (New-ParallelogramPath -X ($Size * 0.27) -Y ($Size * 0.18) -Width ($Size * 0.18) -Height ($Size * 0.60) -Slant ($Size * 0.055)),
      (New-ParallelogramPath -X ($Size * 0.39) -Y ($Size * 0.18) -Width ($Size * 0.38) -Height ($Size * 0.15) -Slant ($Size * 0.055)),
      (New-ParallelogramPath -X ($Size * 0.39) -Y ($Size * 0.43) -Width ($Size * 0.29) -Height ($Size * 0.13) -Slant ($Size * 0.055)),
      (New-DiamondPath -CenterX ($Size * 0.76) -CenterY ($Size * 0.18) -Radius ($Size * 0.055))
    )) {
      try {
        $graphics.FillPath($shadowBrush, $shape)
      } finally {
        $shape.Dispose()
      }
    }

    $graphics.Transform = $baseTransform
    $graphics.RotateTransform(-10)

    $stem = New-ParallelogramPath -X ($Size * 0.27) -Y ($Size * 0.18) -Width ($Size * 0.18) -Height ($Size * 0.60) -Slant ($Size * 0.055)
    $topBar = New-ParallelogramPath -X ($Size * 0.39) -Y ($Size * 0.18) -Width ($Size * 0.38) -Height ($Size * 0.15) -Slant ($Size * 0.055)
    $midBar = New-ParallelogramPath -X ($Size * 0.39) -Y ($Size * 0.43) -Width ($Size * 0.29) -Height ($Size * 0.13) -Slant ($Size * 0.055)
    $spark = New-DiamondPath -CenterX ($Size * 0.76) -CenterY ($Size * 0.18) -Radius ($Size * 0.055)

    try {
      $graphics.FillPath($mainBrush, $stem)
      $graphics.FillPath($mainBrush, $topBar)
      $graphics.FillPath($mainBrush, $midBar)
      $graphics.FillPath($accentBrush, $spark)
    } finally {
      $stem.Dispose()
      $topBar.Dispose()
      $midBar.Dispose()
      $spark.Dispose()
    }
  } finally {
    $graphics.Transform = $shadowTransform
    $shadowTransform.Dispose()
    $baseTransform.Dispose()
    $shadowBrush.Dispose()
    $mainBrush.Dispose()
    $accentBrush.Dispose()
  }
}

function Save-Png {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    [string]$Path
  )

  $directory = Split-Path -Parent $Path
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-Canvas {
  param(
    [int]$Size,
    [switch]$Transparent
  )

  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
  $bitmap.SetResolution(144, 144)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  if ($Transparent) {
    $graphics.Clear([System.Drawing.Color]::Transparent)
  }
  return @{
    Bitmap = $bitmap
    Graphics = $graphics
  }
}

function Export-FullIcon {
  param(
    [int]$Size,
    [string]$Path
  )

  $canvas = New-Canvas -Size $Size
  try {
    Draw-Background -Graphics $canvas.Graphics -Size $Size
    Draw-ForegroundMark -Graphics $canvas.Graphics -Size $Size
    Save-Png -Bitmap $canvas.Bitmap -Path $Path
  } finally {
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
  }
}

function Export-ForegroundIcon {
  param(
    [int]$Size,
    [string]$Path,
    [switch]$Monochrome
  )

  $canvas = New-Canvas -Size $Size -Transparent
  try {
    Draw-ForegroundMark -Graphics $canvas.Graphics -Size $Size -Monochrome:$Monochrome
    Save-Png -Bitmap $canvas.Bitmap -Path $Path
  } finally {
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
  }
}

$legacySizes = @{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}

$adaptiveSizes = @{
  'mipmap-mdpi' = 108
  'mipmap-hdpi' = 162
  'mipmap-xhdpi' = 216
  'mipmap-xxhdpi' = 324
  'mipmap-xxxhdpi' = 432
}

Export-FullIcon -Size 1024 -Path (Join-Path $brandingDir 'fitforge_app_icon_1024.png')
Export-FullIcon -Size 512 -Path (Join-Path $brandingDir 'fitforge_playstore_icon_512.png')
Export-ForegroundIcon -Size 1024 -Path (Join-Path $brandingDir 'fitforge_adaptive_foreground_1024.png')
Export-ForegroundIcon -Size 1024 -Path (Join-Path $brandingDir 'fitforge_adaptive_monochrome_1024.png') -Monochrome

foreach ($entry in $legacySizes.GetEnumerator()) {
  Export-FullIcon -Size $entry.Value -Path (Join-Path $resDir "$($entry.Key)\ic_launcher.png")
  Export-FullIcon -Size $entry.Value -Path (Join-Path $resDir "$($entry.Key)\ic_launcher_round.png")
}

foreach ($entry in $adaptiveSizes.GetEnumerator()) {
  Export-ForegroundIcon -Size $entry.Value -Path (Join-Path $resDir "$($entry.Key)\ic_launcher_foreground.png")
  Export-ForegroundIcon -Size $entry.Value -Path (Join-Path $resDir "$($entry.Key)\ic_launcher_monochrome.png") -Monochrome
}

Write-Output "Generated launcher assets under $brandingDir and Android mipmap resources."
