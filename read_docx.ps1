Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-DocxText {
    param([string]$Path)
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $entry = $zip.GetEntry("word/document.xml")
        $stream = $entry.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        $xmlContent = $reader.ReadToEnd()
        $reader.Close()
        $zip.Dispose()
        
        $xml = [xml]$xmlContent
        $text = ($xml.SelectNodes("//*[local-name()='t']") | ForEach-Object { $_.InnerText }) -join " "
        return $text
    } catch {
        return "Error: $_"
    }
}

Write-Output "=== 附件1 ==="
Get-DocxText -Path "E:\国赛建模\B\附件\附件1.docx"

Write-Output "=== 附件2 ==="
Get-DocxText -Path "E:\国赛建模\B\附件\附件2.docx"
