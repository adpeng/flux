$certPath = "build\windows\x64\runner\Release\test_certificate.pfx"
if (-not (Test-Path $certPath)) {
    $certPath = "test_certificate.pfx"
}

if (-not (Test-Path $certPath)) {
    Write-Host "Error: Certificate file not found." -ForegroundColor Red
    exit 1
}

Write-Host "Installing certificate '$certPath' to Trusted Root Authorities..."
try {
    # Requires RunAs Administrator
    Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
    Write-Host "Certificate installed successfully!" -ForegroundColor Green
    Write-Host "You can now install the MSIX package."
} catch {
    Write-Host "Failed to install certificate. Please run this script as Administrator." -ForegroundColor Red
    Write-Host $_
}
pause
