#Переменная-флаг
$isRight = $false;

#Буква диска, откуда будет переносится информация
$from = "";
#Буква диска, куда будет переносится информация
$to = "";

#Требуется ли сохранить папки AppData
$isAppDataRequired = "";
#Требуется ли сохранить временные файлы
$isTempFilesRequired = "";

#Функция, проверяющая существует ли диск по переданной букве
function checkDiskExistence {
    param (
        $diskLetter
    )

    if (Test-Path ${diskLetter}) { return($true) }

    return($false);
};

#Функция возвращающая метку диска по переданной букве
function getDiskLabel {
    param (
        $diskLetter
    )

    $label = ([System.IO.DriveInfo]::GetDrives() | ? Name -eq "${diskLetter}").VolumeLabel;

    return("${label} (${diskLetter})");
};

#Функция для сбора информации о дисках: откуда и куда будет переносится информация
function askFromTo {
    param (
        $question, $from
    )

    $flag = $false;
    $diskLetter = "";

    while ($flag -ne $true) {
        Write-Host $question;

        $diskLetter = Read-Host;

        if ($diskLetter -match "^[a-zA-Z]{1}$") {
            $diskLetter = $diskLetter.ToUpper() + ":\";
        } else {
            Write-Host "Введено неверное значение, попробуйте еще раз." `n;

            continue;
        }

        if ($diskLetter -eq $from) {
            Write-Host "Для переноса данных укажите диск, не являющийся источником!" `n;

            continue;
        }

        $flag = checkDiskExistence($diskLetter);

        if ($flag -ne $true) {
            Write-Host "Диска по указанной букве не найдено, проверьте данные и повторите попытку!" `n;
        }
    }

    return($diskLetter);
};

#функция для сбора дополнительной информации по переданному вопросу
function askAdditionalInfo {
    param(
        $question
    )

    $flag = $false;
    $answer = "";

    while ($flag -ne $true) {
        Write-Host $question;

        $answer = Read-Host;

        $answer = $answer.ToUpper();

        if ($answer -eq "Y" -or $answer -eq "N") {
            $flag = $true;
        } else {
            Write-Host "Введено неверное значение, попробуйте еще раз." `n;
        }
    }

    return($answer);
};

function getSerialNumber {
    return((Get-WmiObject -class win32_bios).SerialNumber);
};

function Get-Now {
    return Get-Date -UFormat "%Y-%m-%d %T";
};

#Диалог с пользователем. Собираем необходимую информацию перед началом выполнения скрипта.
while ($isRight -ne $true) {
    #Считываем с клавиатуры и проверяем на корректность букву диска, с которого необходимо перенести данные
    $from = askFromTo("Укажите букву диска, с которого необходимо перенести данные:");

    #Считываем с клавиатуры и проверяем на корректность букву диска, на который необходимо перенести данные
    $to = askFromTo "Укажите букву диска, на который будут перенесены данные:" $from;

    #Спрашиваем у пользователя необходимо ли сохранить папки AppData и проверяем ввод на корректность
    $isAppDataRequired = askAdditionalInfo("Сохранить папки AppData? Y - да, N - нет:");

    #Спрашиваем у пользователя необходимо ли сохранить temp-файлы и проверяем ввод на корректность
    $isTempFilesRequired = askAdditionalInfo("Желаете ли сохранить временные (*.temp) файлы пользователей при переносе? Y - да, N - нет:");

    #Выводим пользователю все введенные ранее данные и спрашиваем все ли корректно
    while ($isRight -ne $true) {
        Write-Host `n;
        Write-Host "Вы ввели следующие данные:";
        Write-Host "Диск, с которого необходимо перенести данные: $(getDiskLabel($from))";
        Write-Host "Диск, куда нужно перенести данные: $(getDiskLabel($to))";
        Write-Host "Сохранить папки AppData? - ${isAppDataRequired}";
        Write-Host "Сохранить временные (*.temp) файлы? - ${isTempFilesRequired}" `n;
        Write-Host "Если все верно - Y, для внесения изменений - N:";

        $isRight = Read-Host;

        $isRight = $isRight.ToUpper();

        if ($isRight -eq "Y") {
            $isRight = $true;
        } elseif ($isRight -eq "N") {
            $isRight = $false;

            break;
        } else {
            Write-Host "Введено неверное значение, попробуйте еще раз." `n;
        }
    }
}

$destinationFolderName = "$(getSerialNumber)";
$destinationFolderPath = "$to$destinationFolderName";
$pathToLogFile = "$destinationFolderPath\logs.txt";

function writeLog {
    param (
        $text, $pathToLogFile
    )

    Write-Host "[$(Get-Now)]: $text";

    "[$(Get-Now)]: $text" >> $pathToLogFile;
};

function makeLogFile {
    param (
        $pathToLogFile
    )

    try {
        New-Item -Path "$pathToLogFile" -ItemType File;

        writeLog -text "init log file" -pathToLogFile $pathToLogFile;
    } catch {
        Write-Host "Не удалось создать файл логов.";
    }
};

function makeDestinationFolder {
    param (
        $to, $destinationFolderPath, $pathToLogFile
    )

    try {
        New-Item -Path "$destinationFolderPath" -ItemType Directory;

        makeLogFile($pathToLogFile);

        writeLog -text "Создана папка назначения $destinationFolderPath" -pathToLogFile $pathToLogFile;
    } catch {
        Write-Host "Не удалось создать папку назначения!";

        pause;

        exit 1;
    }
};

makeDestinationFolder -to $to -destinationFolderPath $destinationFolderPath -pathToLogFile $pathToLogFile;

function copyObject {
    param (
        $copiedObjectName, $pathToLogFile, $exclude, $from, $to
    )

    writeLog -text "Начато копирование ${copiedObjectName}" -pathToLogFile $pathToLogFile;

    try {
        Copy-Item "${from}" -Exclude $exclude -Recurse "$to" -Force -PassThru *>&1 | Tee-Object -FilePath $pathToLogFile -Append;

        writeLog -text "Копирование ${copiedObjectName} успешно завершено" -pathToLogFile $pathToLogFile; 
    } catch {
        writeLog -text "Что-то пошло не так при копировании ${copiedObjectName}. Проверьте результат." -pathToLogFile $pathToLogFile;
    }
};

function copyStartMenu {
    param (
        $pathToLogFile, $from, $destinationFolderPath
    )

    writeLog -text "Начато копирование стартового меню" -pathToLogFile $pathToLogFile;

    $exclude = @("desktop.ini", "Immersive Control Panel.lnk");

    try {
        Copy-Item "${from}ProgramData\Microsoft\Windows\Start Menu\Programs\" -Exclude $exclude -Recurse "$destinationFolderPath\StartMenu\" -Force -PassThru *>&1 | Tee-Object -FilePath $pathToLogFile -Append;

        writeLog -text "Копирование стартового меню успешно завершено" -pathToLogFile $pathToLogFile; 
    } catch {
        writeLog -text "Что-то пошло не так при копировании стартового меню. Проверьте результат." -pathToLogFile $pathToLogFile;
    }
};

function copyUsers {
    param (
        $pathToLogFile, $from, $destinationFolderPath
    )

    writeLog -text "Начато копирование папки Users" -pathToLogFile $pathToLogFile;

    $exclude = @(
        "AppData",
        "#Application Data",
        "Contacts",
        "Cookies",
        "IntelGraphicsProfiles",
        "Local Settings",
        "LtcJobs",
        "NetHood",
        "PrintHood",
        "Recent",
        "SendTo",
        "Searches",
        "главное меню",
        "Мои документы",
        "Music",
        "Saved Games",
        "Links",
        "Шаблоны",
        "All Users",
        "Default",
        "Default User",
        "Все пользователи",
        "LocAdmin",
        "*_wa",
        "*_adm",
        "ntuser*",
        "Ntuser*",
        "NTUSER*",
        "*.tmp",
        "*.temp",
        "~*",
        "*.bak",
        "*.ini"
    );

    try {
        Copy-Item "${from}Users\" -Exclude $exclude -Recurse "$destinationFolderPath\Users\" -Force -PassThru *>&1 | Tee-Object -FilePath $pathToLogFile -Append;

        writeLog -text "Копирование папки Users успешно завершено" -pathToLogFile $pathToLogFile;
    } catch {
        writeLog -text "Что-то пошло не так при копировании папки Users. Проверьте результат." -pathToLogFile $pathToLogFile;
    }
};

try {
    #Записываем имя компьютера в лог
    writeLog -text "Имя компьютера: $(gc env:computername)" -pathToLogFile $pathToLogFile

    #Копируем стартовое меню (список программ)
    #copyStartMenu -pathToLogFile $pathToLogFile -from $from -destinationFolderPath $destinationFolderPath;
    
    copyObject -copiedObjectName "СТАРТОВОЕ МЕНЮ" -pathToLogFile $pathToLogFile -exclude @("desktop.ini", "Immersive Control Panel.lnk") -from "${from}ProgramData\Microsoft\Windows\Start Menu\Programs\" -to "$destinationFolderPath\StartMenu\";

    #TODO: ПОПРАВИТЬ ФИЛЬТРАЦИЮ (EXCLUDE) ПАПОК В ФУНКЦИИ COPYUSERS, как функция начнет корректно, попробовать использовать copyObject
    copyUsers -pathToLogFile $pathToLogFile -from $from -destinationFolderPath $destinationFolderPath;


} catch {
    Write-Host "В процессе выполнения скрипта произошла ошибка, попробуйте запустить скрипт заново или выполните перенос вручную.";
}

pause;

#TODO:
#
#***Логика скрипта: рекурсивно копироваться все кроме файлов и папок из массива исключений
#
#ПАПКИ:
#AppData*
#Application Data
#Contacts
#Cookies
#IntelGraphicsProfiles
#Local Settings
#LtcJobs
#NetHood
#PrintHood
#Recent
#SendTo
#Searches
#главное меню
#Мои документы(*?)
#Music
#Saved Games
#Links
#Шаблоны
#
#Также не переносить следующие папки пользователей:
#
#All Users, Default, Default User, Все пользователи, LocAdmin; все что заканчивается на *_wa или *_adm
#
#Файлы:
#*Файлы, начинающиеся с ntuser* (без учета регистра)
#*???Все временные файлы?: *.tmp, *.temp, нач. с ~,  .bak, *.ini
#
#
#TODO: *также сделать скрипт для копирования уже на новом диске данных из temp\users\user в C:\Users\user
#
#
