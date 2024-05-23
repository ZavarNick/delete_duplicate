# Функция для вычисления хэша файла
function Get-FileHashString {
    param (
        [string]$filePath
    )
    $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
    $fileStream = [System.IO.File]::OpenRead($filePath)
    $hash = $hashAlgorithm.ComputeHash($fileStream)
    $fileStream.Close()
    return [BitConverter]::ToString($hash) -replace '-', ''
}

# Запрос пути к директории для поиска дубликатов у пользователя
$directory = Read-Host "Введите путь к директории для поиска дубликатов"

# Проверка существования директории
if (-Not (Test-Path -Path $directory)) {
    Write-Host "Указанная директория не существует. Завершение работы скрипта."
    exit
}

# Хранилище файлов по размеру
$sizeTable = @{}

# Поиск всех файлов в директории и группировка их по размеру
Get-ChildItem -Path $directory -Recurse -File | ForEach-Object {
    $filePath = $_.FullName
    $fileSize = $_.Length

    if ($sizeTable.ContainsKey($fileSize)) {
        $sizeTable[$fileSize] += ,$filePath
    } else {
        $sizeTable[$fileSize] = @($filePath)
    }
}

# Хранилище хэшей и файлов
$hashTable = @{}
$duplicateFiles = @{}

# Вычисление хэшей для файлов одинакового размера
foreach ($fileGroup in $sizeTable.Values) {
    if ($fileGroup.Count -gt 1) {
        foreach ($filePath in $fileGroup) {
            $fileHash = Get-FileHashString -filePath $filePath

            if ($hashTable.ContainsKey($fileHash)) {
                if (-not $duplicateFiles.ContainsKey($fileHash)) {
                    $duplicateFiles[$fileHash] = @($hashTable[$fileHash])
                }
                $duplicateFiles[$fileHash] += ,$filePath
            } else {
                $hashTable[$fileHash] = $filePath
            }
        }
    }
}

# Запись дубликатов в текстовый файл
$outputPath = Join-Path -Path $directory -ChildPath "duplicates.txt"
$duplicateFiles.GetEnumerator() | ForEach-Object {
    $hash = $_.Key
    $files = $_.Value
    "${hash}:`n$($files -join "`n")`n" | Out-File -FilePath $outputPath -Append
}

# Предложение выбрать и удалить дубликаты
if ($duplicateFiles.Count -gt 0) {
    Write-Host "Найдены дубликаты файлов:"
    $index = 0
    $fileIndexMap = @{}
    
    # Отображение списка дубликатов с индексами
    $duplicateFiles.GetEnumerator() | ForEach-Object {
        $hash = $_.Key
        $files = $_.Value
        Write-Host "Дубликаты для хэша ${hash}:"
        $files | ForEach-Object {
            Write-Host "[$index] $_"
            $fileIndexMap[$index] = $_
            $index++
        }
    }
    
    $response = Read-Host "Введите номера файлов для удаления через запятую (например: 0,2,5), или 'n' для отмены"
    
    if ($response -ne 'n') {
        $indicesToDelete = $response -split ',' | ForEach-Object { $_.Trim() }
        
        foreach ($index in $indicesToDelete) {
            if ($fileIndexMap.ContainsKey([int]$index)) {
                $filePath = $fileIndexMap[[int]$index]
                try {
                    Remove-Item -Path $filePath -Force
                    Write-Host "Удален: $filePath"
                } catch {
                    Write-Host "Ошибка при удалении ${filePath}: $_"
                }
            } else {
                Write-Host "Некорректный индекс: $index"
            }
        }
    } else {
        Write-Host "Удаление дубликатов отменено."
    }
} else {
    Write-Host "Дубликаты файлов не найдены."
}
