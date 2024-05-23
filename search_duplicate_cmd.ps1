# Загрузка сборок Windows Forms
Add-Type -AssemblyName System.Windows.Forms

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
    [System.Windows.Forms.MessageBox]::Show("Указанная директория не существует. Завершение работы скрипта.", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
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

# Создание графического интерфейса для выбора дубликатов файлов
$form = New-Object System.Windows.Forms.Form
$form.Text = "Выбор файлов для удаления"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Dock = "Fill"
$form.Controls.Add($checkedListBox)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Удалить выбранные"
$okButton.Dock = "Bottom"
$okButton.Add_Click({
    $checkedItems = @($checkedListBox.CheckedItems)
    if ($checkedItems.Count -gt 0) {
        $result = [System.Windows.Forms.MessageBox]::Show("Вы уверены, что хотите удалить выбранные файлы?", "Подтверждение", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            $itemsToRemove = @()
            foreach ($item in $checkedItems) {
                try {
                    Remove-Item -Path $item -Force
                    $itemsToRemove += $item
                    Write-Host "Удален: $item"
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Ошибка при удалении ${item}: $_", "Ошибка", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
            foreach ($item in $itemsToRemove) {
                $checkedListBox.Items.Remove($item)
            }
        }
    }
})
$form.Controls.Add($okButton)

# Заполнение списка дубликатов
if ($duplicateFiles.Count -gt 0) {
    foreach ($fileGroup in $duplicateFiles.Values) {
        foreach ($filePath in $fileGroup) {
            $checkedListBox.Items.Add($filePath)
        }
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("Дубликаты файлов не найдены.", "Информация", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

# Запуск формы
[System.Windows.Forms.Application]::Run($form)
