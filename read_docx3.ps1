Add-Type -AssemblyName System.IO.Compression.FileSystem
$dir = Get-ChildItem -Path . -Recurse -Filter "*.docx"
foreach ($file in $dir) {
    if ($file.Name -match "~\$") { continue }
    Write-Output ("=== " + $file.Name + " ===")
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
        $entry = $zip.GetEntry("word/document.xml")
        if ($entry) {
            $stream = $entry.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $xmlContent = $reader.ReadToEnd()
            $reader.Close()
            $xml = [xml]$xmlContent
            $text = ($xml.SelectNodes("//*[local-name()='t']") | ForEach-Object { $_.InnerText }) -join ""
            Write-Output $text
        }
        $zip.Dispose()
    } catch {
        Write-Output $_.Exception.Message
    }
}
