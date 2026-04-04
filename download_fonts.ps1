# Download Google Fonts for EduSHAMIIT
# Outfit font family
$outfitBaseUrl = "https://fonts.gstatic.com/s/outfit/v5"
$outfitFiles = @(
    @{ name = "Outfit-Thin.ttf"; url = "qGYsz_wNahGAdqQ43Rh_fKDp2Yz9.woff2" },
    @{ name = "Outfit-ExtraLight.ttf"; url = "qGYsz_wNahGAdqQ43Rh_cKCagfM.woff2" },
    @{ name = "Outfit-Light.ttf"; url = "qGYsz_wNahGAdqQ43Rh_ebCagfM.woff2" },
    @{ name = "Outfit-Regular.ttf"; url = "qGYsz_wNahGAdqQ43Rh_TpCagfM.woff2" },
    @{ name = "Outfit-Medium.ttf"; url = "qGYsz_wNahGAdqQ43Rh_fKCagfM.woff2" },
    @{ name = "Outfit-SemiBold.ttf"; url = "qGYsz_wNahGAdqQ43Rh_1pGagfM.woff2" },
    @{ name = "Outfit-Bold.ttf"; url = "qGYsz_wNahGAdqQ43Rh_0JCagfM.woff2" },
    @{ name = "Outfit-ExtraBold.ttf"; url = "qGYsz_wNahGAdqQ43Rh_xpKagfM.woff2" },
    @{ name = "Outfit-Black.ttf"; url = "qGYsz_wNahGAdqQ43Rh_u5OagfM.woff2" }
)

# DM Sans font family
$dmSansBaseUrl = "https://fonts.gstatic.com/s/dmsans/v11"
$dmSansFiles = @(
    @{ name = "DMSans-Thin.ttf"; url = "rP2Hp2ywxg089UriCZIIAsOQDZ5s.woff2" },
    @{ name = "DMSans-ExtraLight.ttf"; url = "rP2Fp2ywxg089UriCZaBGs-4BYTk.woff2" },
    @{ name = "DMSans-Light.ttf"; url = "rP2Fp2ywxg089UriCZIlGs-4BYTk.woff2" },
    @{ name = "DMSans-Regular.ttf"; url = "rP2Fp2ywxg089UriCZOHGs-4BYTk.woff2" },
    @{ name = "DMSans-Medium.ttf"; url = "rP2Fp2ywxg089UriCZI3G8-4BYTk.woff2" },
    @{ name = "DMSans-SemiBold.ttf"; url = "rP2Fp2ywxg089UriCZKbHs-4BYTk.woff2" },
    @{ name = "DMSans-Bold.ttf"; url = "rP2Fp2ywxg089UriCZJvH8-4BYTk.woff2" },
    @{ name = "DMSans-ExtraBold.ttf"; url = "rP2Fp2ywxg089UriCZL7GM-4BYTk.woff2" },
    @{ name = "DMSans-Black.ttf"; url = "rP2Fp2ywxg089UriCZLjH8-4BYTk.woff2" }
)

$fontsDir = "edu_shamiit_ai/assets/fonts"

Write-Host "Downloading Outfit fonts..."
foreach ($font in $outfitFiles) {
    $url = "$outfitBaseUrl/$($font.url)"
    $output = "$fontsDir/$($font.name)"
    Write-Host "  Downloading $($font.name)..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $output
        Write-Host "    ✓ Downloaded"
    } catch {
        Write-Host "    ✗ Failed: $_"
    }
}

Write-Host "Downloading DM Sans fonts..."
foreach ($font in $dmSansFiles) {
    $url = "$dmSansBaseUrl/$($font.url)"
    $output = "$fontsDir/$($font.name)"
    Write-Host "  Downloading $($font.name)..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $output
        Write-Host "    ✓ Downloaded"
    } catch {
        Write-Host "    ✗ Failed: $_"
    }
}

Write-Host "Font download complete!"