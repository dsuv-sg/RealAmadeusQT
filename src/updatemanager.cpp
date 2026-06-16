#include "updatemanager.h"
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVersionNumber>
#include <QDesktopServices>
#include <QUrl>
#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QFileInfo>

UpdateManager::UpdateManager(QObject *parent)
    : QObject(parent)
{
    m_currentVersion = QCoreApplication::applicationVersion();
    if (m_currentVersion.isEmpty()) {
        m_currentVersion = QStringLiteral("0.1.0"); // Fallback if not set
    }
}

QString UpdateManager::cleanVersion(QString version)
{
    int firstDigitIdx = -1;
    for (int i = 0; i < version.length(); ++i) {
        if (version[i].isDigit()) {
            firstDigitIdx = i;
            break;
        }
    }
    if (firstDigitIdx != -1) {
        version = version.mid(firstDigitIdx);
    }
    return version.trimmed();
}

bool UpdateManager::compareVersions(const QString &current, const QString &latest)
{
    QVersionNumber currVer = QVersionNumber::fromString(cleanVersion(current));
    QVersionNumber lateVer = QVersionNumber::fromString(cleanVersion(latest));
    return currVer < lateVer;
}

void UpdateManager::checkForUpdate()
{
    if (m_isChecking) return;

    m_isChecking = true;
    emit isCheckingChanged();

    QUrl url("https://api.github.com/repos/dsuv-sg/RealAmadeusQT/releases/latest");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "RealAmadeusPC-Updater");

    QNetworkReply *reply = m_networkManager.get(request);
    connect(reply, &QNetworkReply::finished, this, &UpdateManager::onReplyFinished);
}

void UpdateManager::onReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;

    reply->deleteLater();
    m_isChecking = false;
    emit isCheckingChanged();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "Update check failed:" << reply->errorString();
        emit updateCheckFinished(false, false);
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "Invalid JSON response from GitHub API";
        emit updateCheckFinished(false, false);
        return;
    }

    QJsonObject obj = doc.object();
    QString tagName = obj.value("tag_name").toString();
    QString htmlUrl = obj.value("html_url").toString();

    if (tagName.isEmpty()) {
        qWarning() << "No tag_name found in GitHub release";
        emit updateCheckFinished(false, false);
        return;
    }

    m_latestVersion = cleanVersion(tagName);
    if (!m_latestVersion.startsWith('v', Qt::CaseInsensitive)) {
        m_latestVersion = QStringLiteral("V") + m_latestVersion;
    }
    m_updateUrl = htmlUrl; // Default fallback
    m_assetSize = 0;

    QJsonArray assets = obj.value("assets").toArray();
    for (const QJsonValue &val : assets) {
        QJsonObject assetObj = val.toObject();
        QString name = assetObj.value("name").toString();
        if (name.endsWith(QStringLiteral(".zip"), Qt::CaseInsensitive)) {
            QString downloadUrl = assetObj.value("browser_download_url").toString();
            if (!downloadUrl.isEmpty()) {
                m_updateUrl = downloadUrl;
                m_assetSize = assetObj.value("size").toVariant().toLongLong();
                break;
            }
        }
    }

    m_hasUpdate = compareVersions(m_currentVersion, m_latestVersion);

    emit versionChanged();
    emit hasUpdateChanged();
    emit updateCheckFinished(true, m_hasUpdate);
}

void UpdateManager::startUpdate(int langIndex)
{
    if (m_updateUrl.isEmpty()) {
        qWarning() << "Update URL is empty";
        return;
    }

    // If we didn't find a zip asset URL, fall back to opening the HTML release page
    if (!m_updateUrl.endsWith(QStringLiteral(".zip"), Qt::CaseInsensitive) && !m_updateUrl.contains(QStringLiteral("/releases/download/"))) {
        QDesktopServices::openUrl(QUrl(m_updateUrl));
        return;
    }

    QString appDir = QCoreApplication::applicationDirPath();
    QString scriptPath = appDir + QStringLiteral("/updater.ps1");

    // Write updater.ps1 script
    QFile file(scriptPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out.setGenerateByteOrderMark(true); // Add BOM to prevent Japanese character corruption in Windows PowerShell
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        out.setEncoding(QStringConverter::Utf8);
#else
        out.setCodec("UTF-8");
#endif
        out << getUpdaterScriptContent();
        file.close();
    } else {
        qWarning() << "Failed to create updater script file";
        QDesktopServices::openUrl(QUrl(m_updateUrl));
        return;
    }

    QString exeName = QFileInfo(QCoreApplication::applicationFilePath()).fileName();
    qint64 pid = QCoreApplication::applicationPid();

    QStringList arguments;
    arguments << QStringLiteral("-ExecutionPolicy") << QStringLiteral("Bypass")
              << QStringLiteral("-File") << scriptPath
              << QStringLiteral("-ParentPid") << QString::number(pid)
              << QStringLiteral("-DownloadUrl") << m_updateUrl
              << QStringLiteral("-AssetSize") << QString::number(m_assetSize)
              << QStringLiteral("-AppDir") << appDir
              << QStringLiteral("-ExeName") << exeName
              << QStringLiteral("-LangIndex") << QString::number(langIndex);

    bool started = QProcess::startDetached(QStringLiteral("powershell.exe"), arguments);
    if (started) {
        QCoreApplication::quit();
    } else {
        qWarning() << "Failed to launch updater process";
        QDesktopServices::openUrl(QUrl(m_updateUrl));
    }
}

QString UpdateManager::getUpdaterScriptContent()
{
    return QStringLiteral(
        "param(\n"
        "    [int]$ParentPid,\n"
        "    [string]$DownloadUrl,\n"
        "    [long]$AssetSize,\n"
        "    [string]$AppDir,\n"
        "    [string]$ExeName,\n"
        "    [int]$LangIndex = 0\n"
        ")\n\n"
        "Add-Type -AssemblyName System.Windows.Forms\n"
        "Add-Type -AssemblyName System.Drawing\n\n"
        "# Dictionary of localized strings\n"
        "$Translations = @{\n"
        "    0 = @{ # ja (Japanese)\n"
        "        Title = \"RealAmadeus アップデーター\"\n"
        "        Preparing = \"準備中...\"\n"
        "        Downloading = \"ファイルをダウンロード中...\"\n"
        "        Extracting = \"ファイルを解凍中...\"\n"
        "        Updating = \"アプリを更新中...\"\n"
        "        Cleaning = \"一時ファイルを削除中...\"\n"
        "        Completed = \"リアルアマデウスの更新が完了しました。`nOKを押すとアプリを再起動します。\"\n"
        "        CompletedTitle = \"更新完了 - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"ディスクの空き容量が不足しています。`n`n必要な空き容量: {0} MB`n現在の空き容量: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"エラー - RealAmadeus Updater\"\n"
        "        DownloadError = \"ダウンロード中にエラーが発生しました。`n`nエラー内容: {0}\"\n"
        "        ExtractError = \"ファイルの解凍中にエラーが発生しました。`n`nエラー内容: {0}\"\n"
        "        UpdateError = \"ファイルの更新中にエラーが発生しました。`n一部のファイルが使用中であるか、書き込み権限がありません。`n`nエラー内容: {0}\"\n"
        "        ErrorTitle = \"エラー - RealAmadeus Updater\"\n"
        "    }\n"
        "    1 = @{ # en (English)\n"
        "        Title = \"RealAmadeus Updater\"\n"
        "        Preparing = \"Preparing...\"\n"
        "        Downloading = \"Downloading file...\"\n"
        "        Extracting = \"Extracting files...\"\n"
        "        Updating = \"Updating app...\"\n"
        "        Cleaning = \"Cleaning temporary files...\"\n"
        "        Completed = \"RealAmadeus has been updated successfully.`nClick OK to restart the application.\"\n"
        "        CompletedTitle = \"Update Complete - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Insufficient disk space.`n`nRequired: {0} MB`nAvailable: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"Error - RealAmadeus Updater\"\n"
        "        DownloadError = \"An error occurred during download.`n`nDetails: {0}\"\n"
        "        ExtractError = \"An error occurred during extraction.`n`nDetails: {0}\"\n"
        "        UpdateError = \"An error occurred during update.`nSome files may be in use or write access is denied.`n`nDetails: {0}\"\n"
        "        ErrorTitle = \"Error - RealAmadeus Updater\"\n"
        "    }\n"
        "    2 = @{ # zh (Chinese)\n"
        "        Title = \"RealAmadeus 更新程序\"\n"
        "        Preparing = \"准备中...\"\n"
        "        Downloading = \"正在下载文件...\"\n"
        "        Extracting = \"正在解压文件...\"\n"
        "        Updating = \"正在更新应用程序...\"\n"
        "        Cleaning = \"正在清理临时文件...\"\n"
        "        Completed = \"RealAmadeus 已成功更新。`n点击 确定 重启应用程序。\"\n"
        "        CompletedTitle = \"更新完成 - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"磁盘空间不足。`n`n需要空间: {0} MB`n可用空间: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"错误 - RealAmadeus Updater\"\n"
        "        DownloadError = \"下载过程中出错。`n`n详情: {0}\"\n"
        "        ExtractError = \"解压过程中出错。`n`n详情: {0}\"\n"
        "        UpdateError = \"更新过程中出错。`n某些文件可能正在使用中或写入权限被拒绝。`n`n详情: {0}\"\n"
        "        ErrorTitle = \"错误 - RealAmadeus Updater\"\n"
        "    }\n"
        "    3 = @{ # ko (Korean)\n"
        "        Title = \"RealAmadeus 업데이트\"\n"
        "        Preparing = \"준비 중...\"\n"
        "        Downloading = \"파일 다운로드 중...\"\n"
        "        Extracting = \"파일 압축 해제 중...\"\n"
        "        Updating = \"앱 업데이트 중...\"\n"
        "        Cleaning = \"임시 파일 삭제 중...\"\n"
        "        Completed = \"RealAmadeus 업데이트가 완료되었습니다.`n확인을 누르면 앱이 재시작됩니다.\"\n"
        "        CompletedTitle = \"업데이트 완료 - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"디스크 공간이 부족합니다.`n`n필요한 공간: {0} MB`n현재 여유 공간: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"오류 - RealAmadeus Updater\"\n"
        "        DownloadError = \"다운로드 중 오류가 발생했습니다.`n`n오류 내용: {0}\"\n"
        "        ExtractError = \"압축 해제 중 오류가 발생했습니다.`n`n오류 내용: {0}\"\n"
        "        UpdateError = \"업데이트 중 오류가 발생했습니다.`n일부 파일이 사용 중이거나 쓰기 권한이 없습니다.`n`n오류 내용: {0}\"\n"
        "        ErrorTitle = \"오류 - RealAmadeus Updater\"\n"
        "    }\n"
        "    4 = @{ # es (Spanish)\n"
        "        Title = \"RealAmadeus Actualizador\"\n"
        "        Preparing = \"Preparando...\"\n"
        "        Downloading = \"Descargando archivo...\"\n"
        "        Extracting = \"Extrayendo archivos...\"\n"
        "        Updating = \"Actualizando aplicación...\"\n"
        "        Cleaning = \"Limpiando archivos temporales...\"\n"
        "        Completed = \"RealAmadeus se ha actualizado correctamente.`nHaga clic en Aceptar para reiniciar la aplicación.\"\n"
        "        CompletedTitle = \"Actualización completada - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Espacio en disco insuficiente.`n`nRequerido: {0} MB`nDisponible: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"Error - RealAmadeus Updater\"\n"
        "        DownloadError = \"Ocurrió un error durante la descarga.`n`nDetalles: {0}\"\n"
        "        ExtractError = \"Ocurrió un error durante la extracción.`n`nDetalles: {0}\"\n"
        "        UpdateError = \"Ocurrió un error durante la actualización.`nEs posible que algunos archivos estén en uso o se haya denegado el acceso de escritura.`n`nDetalles: {0}\"\n"
        "        ErrorTitle = \"Error - RealAmadeus Updater\"\n"
        "    }\n"
        "    5 = @{ # fr (French)\n"
        "        Title = \"Mise à jour RealAmadeus\"\n"
        "        Preparing = \"Préparation...\"\n"
        "        Downloading = \"Téléchargement du fichier...\"\n"
        "        Extracting = \"Extraction des fichiers...\"\n"
        "        Updating = \"Mise à jour de l'application...\"\n"
        "        Cleaning = \"Nettoyage des fichiers temporaires...\"\n"
        "        Completed = \"RealAmadeus a été mis à jour avec succès.`nCliquez sur OK pour redémarrer l'application.\"\n"
        "        CompletedTitle = \"Mise à jour terminée - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Espace disque insuffisant.`n`nRequis: {0} MB`nDisponible: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"Erreur - RealAmadeus Updater\"\n"
        "        DownloadError = \"Une erreur est survenue lors du téléchargement.`n`nDétails: {0}\"\n"
        "        ExtractError = \"Une erreur est survenue lors de l'extraction.`n`nDétails: {0}\"\n"
        "        UpdateError = \"Une erreur est survenue lors de la mise à jour.`nCertains fichiers peuvent être en cours d'utilisation ou l'accès en écriture est refusé.`n`nDétails: {0}\"\n"
        "        ErrorTitle = \"Erreur - RealAmadeus Updater\"\n"
        "    }\n"
        "    6 = @{ # de (German)\n"
        "        Title = \"RealAmadeus Updater\"\n"
        "        Preparing = \"Vorbereitung...\"\n"
        "        Downloading = \"Datei wird heruntergeladen...\"\n"
        "        Extracting = \"Dateien werden entpackt...\"\n"
        "        Updating = \"App wird aktualisiert...\"\n"
        "        Cleaning = \"Temporäre Dateien werden gelöscht...\"\n"
        "        Completed = \"RealAmadeus wurde erfolgreich aktualisiert.`nKlicken Sie auf OK, um die Anwendung neu zu starten.\"\n"
        "        CompletedTitle = \"Update abgeschlossen - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Unzureichender Speicherplatz.`n`nErforderlich: {0} MB`nVerfügbar: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"Fehler - RealAmadeus Updater\"\n"
        "        DownloadError = \"Fehler beim Herunterladen.`n`nDetails: {0}\"\n"
        "        ExtractError = \"Fehler beim Entpacken.`n`nDetails: {0}\"\n"
        "        UpdateError = \"Fehler beim Aktualisieren.`nEinige Dateien werden möglicherweise verwendet oder der Schreibzugriff wurde verweigert.`n`nDetails: {0}\"\n"
        "        ErrorTitle = \"Fehler - RealAmadeus Updater\"\n"
        "    }\n"
        "    7 = @{ # ru (Russian)\n"
        "        Title = \"Обновление RealAmadeus\"\n"
        "        Preparing = \"Подготовка...\"\n"
        "        Downloading = \"Загрузка файла...\"\n"
        "        Extracting = \"Распаковка файлов...\"\n"
        "        Updating = \"Обновление приложения...\"\n"
        "        Cleaning = \"Очистка временных файлов...\"\n"
        "        Completed = \"RealAmadeus успешно обновлен.`nНажмите OK для перезапуска приложения.\"\n"
        "        CompletedTitle = \"Обновление завершено - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Недостаточно места на диске.`n`nТребуется: {0} МБ`nДоступно: {1} МБ\"\n"
        "        DiskSpaceErrorTitle = \"Ошибка - RealAmadeus Updater\"\n"
        "        DownloadError = \"Произошла ошибка при загрузке.`n`nДетали: {0}\"\n"
        "        ExtractError = \"Произошла ошибка при распаковке.`n`nДетали: {0}\"\n"
        "        UpdateError = \"Произошла ошибка при обновлении.`nВозможно, некоторые файлы используются или доступ на запись запрещен.`n`nДетали: {0}\"\n"
        "        ErrorTitle = \"Ошибка - RealAmadeus Updater\"\n"
        "    }\n"
        "    8 = @{ # uk (Ukrainian)\n"
        "        Title = \"Оновлення RealAmadeus\"\n"
        "        Preparing = \"Підготовка...\"\n"
        "        Downloading = \"Завантаження файлу...\"\n"
        "        Extracting = \"Розпакування файлів...\"\n"
        "        Updating = \"Оновлення програми...\"\n"
        "        Cleaning = \"Очищення тимчасових файлів...\"\n"
        "        Completed = \"RealAmadeus успішно оновлено.`nНатисніть OK, щоб перезапустити програму.\"\n"
        "        CompletedTitle = \"Оновлення завершено - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Недостатньо місця на диску.`n`nПотрібно: {0} МБ`nДоступно: {1} МБ\"\n"
        "        DiskSpaceErrorTitle = \"Помилка - RealAmadeus Updater\"\n"
        "        DownloadError = \"Сталася помилка під час завантаження.`n`nДеталі: {0}\"\n"
        "        ExtractError = \"Сталася помилка під час розпакування.`n`nДеталі: {0}\"\n"
        "        UpdateError = \"Сталася помилка під час оновлення.`nМожливо, деякі файли використовуються або доступ на запис заборонено.`n`nДеталі: {0}\"\n"
        "        ErrorTitle = \"Помилка - RealAmadeus Updater\"\n"
        "    }\n"
        "    9 = @{ # pt (Portuguese)\n"
        "        Title = \"RealAmadeus Atualizador\"\n"
        "        Preparing = \"Preparando...\"\n"
        "        Downloading = \"Baixando arquivo...\"\n"
        "        Extracting = \"Extraindo arquivos...\"\n"
        "        Updating = \"Atualizando aplicativo...\"\n"
        "        Cleaning = \"Limpando arquivos temporários...\"\n"
        "        Completed = \"O RealAmadeus foi atualizado com sucesso.`nClique em OK para reiniciar o aplicativo.\"\n"
        "        CompletedTitle = \"Atualização Concluída - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Espaço em disco insuficiente.`n`nNecessário: {0} MB`nDisponível: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"Erro - RealAmadeus Updater\"\n"
        "        DownloadError = \"Ocorreu um erro durante o download.`n`nDetalhes: {0}\"\n"
        "        ExtractError = \"Ocorreu um erro durante a extração.`n`nDetalhes: {0}\"\n"
        "        UpdateError = \"Ocorreu um erro durante a atualização.`nAlguns arquivos podem estar em uso ou o acesso de gravação foi negado.`n`nDetalhes: {0}\"\n"
        "        ErrorTitle = \"Erro - RealAmadeus Updater\"\n"
        "    }\n"
        "    10 = @{ # tr (Turkish)\n"
        "        Title = \"RealAmadeus Güncelleyici\"\n"
        "        Preparing = \"Hazırlanıyor...\"\n"
        "        Downloading = \"Dosya indiriliyor...\"\n"
        "        Extracting = \"Dosyalar ayıklanıyor...\"\n"
        "        Updating = \"Uygulama güncelleniyor...\"\n"
        "        Cleaning = \"Geçici dosyalar temizleniyor...\"\n"
        "        Completed = \"RealAmadeus başarıyla güncellendi.`nUygulamayı yeniden başlatmak için Tamam'a tıklayın.\"\n"
        "        CompletedTitle = \"Güncelleme Tamamlandı - RealAmadeus Updater\"\n"
        "        DiskSpaceError = \"Yetersiz disk alanı.`n`nGerekli: {0} MB`nMevcut: {1} MB\"\n"
        "        DiskSpaceErrorTitle = \"Hata - RealAmadeus Updater\"\n"
        "        DownloadError = \"İndirme sırasında bir hata oluştu.`n`nDetaylar: {0}\"\n"
        "        ExtractError = \"Ayıklama sırasında bir hata oluştu.`n`nDetaylar: {0}\"\n"
        "        UpdateError = \"Güncelleme sırasında bir hata oluştu.`nBazı dosyalar kullanımda olabilir veya yazma erişimi engellendi.`n`nDetaylar: {0}\"\n"
        "        ErrorTitle = \"Hata - RealAmadeus Updater\"\n"
        "    }\n"
        "}\n\n"
        "$Texts = $Translations[$LangIndex]\n"
        "if ($null -eq $Texts) {\n"
        "    $Texts = $Translations[1] # Fallback to English\n"
        "}\n\n"
        "# 1. Wait for parent process to exit\n"
        "if ($ParentPid -gt 0) {\n"
        "    Write-Host \"Waiting for parent process ($ParentPid) to exit...\"\n"
        "    while (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue) {\n"
        "        Start-Sleep -Seconds 1\n"
        "    }\n"
        "}\n\n"
        "# 2. Check disk space\n"
        "$DriveLetter = [System.IO.Path]::GetPathRoot($AppDir)\n"
        "$Drive = Get-PSDrive -Name $DriveLetter[0] -ErrorAction SilentlyContinue\n"
        "if ($null -eq $Drive) {\n"
        "    $Drive = Get-PSDrive -Name \"C\"\n"
        "}\n\n"
        "$RequiredSpace = $AssetSize * 4 + 50MB\n"
        "$FreeSpace = $Drive.Free\n\n"
        "if ($FreeSpace -lt $RequiredSpace) {\n"
        "    $ErrorMsg = $Texts.DiskSpaceError -f [Math]::Round($RequiredSpace / 1MB, 2), [Math]::Round($FreeSpace / 1MB, 2)\n"
        "    [System.Windows.Forms.MessageBox]::Show(\n"
        "        $ErrorMsg,\n"
        "        $Texts.DiskSpaceErrorTitle,\n"
        "        [System.Windows.Forms.MessageBoxButtons]::OK,\n"
        "        [System.Windows.Forms.MessageBoxIcon]::Error\n"
        "    )\n"
        "    exit 1\n"
        "}\n\n"
        "# Configure TLS\n"
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13\n\n"
        "$TempZip = Join-Path $env:TEMP \"RealAmadeusUpdate.zip\"\n"
        "$TempExtractDir = Join-Path $env:TEMP \"RealAmadeusExtract\"\n\n"
        "# Create UI components\n"
        "$Form = New-Object System.Windows.Forms.Form\n"
        "$Form.Text = $Texts.Title\n"
        "$Form.Size = New-Object System.Drawing.Size(400, 160)\n"
        "$Form.StartPosition = \"CenterScreen\"\n"
        "$Form.FormBorderStyle = \"FixedDialog\"\n"
        "$Form.MaximizeBox = $false\n"
        "$Form.MinimizeBox = $false\n\n"
        "$Label = New-Object System.Windows.Forms.Label\n"
        "$Label.Location = New-Object System.Drawing.Point(20, 20)\n"
        "$Label.Size = New-Object System.Drawing.Size(340, 25)\n"
        "$Label.Text = $Texts.Preparing\n"
        "$Label.Font = New-Object System.Drawing.Font(\"MS Gothic\", 10)\n\n"
        "$ProgressBar = New-Object System.Windows.Forms.ProgressBar\n"
        "$ProgressBar.Location = New-Object System.Drawing.Point(20, 55)\n"
        "$ProgressBar.Size = New-Object System.Drawing.Size(340, 25)\n"
        "$ProgressBar.Style = \"Continuous\"\n"
        "$ProgressBar.Minimum = 0\n"
        "$ProgressBar.Maximum = 100\n"
        "$ProgressBar.Value = 0\n\n"
        "$Form.Controls.Add($Label)\n"
        "$Form.Controls.Add($ProgressBar)\n\n"
        "# Create WebClient and register events\n"
        "$WebClient = New-Object System.Net.WebClient\n"
        "$WebClient.Headers.Add(\"User-Agent\", \"RealAmadeusPC-Updater\")\n\n"
        "$global:DownloadCompleted = $false\n"
        "$global:DownloadFailed = $false\n"
        "$global:ErrorMsg = \"\"\n\n"
        "$OnComplete = {\n"
        "    if ($event.SourceEventArgs.Error -ne $null) {\n"
        "        $global:DownloadFailed = $true\n"
        "        $global:ErrorMsg = $event.SourceEventArgs.Error.Message\n"
        "    }\n"
        "    $global:DownloadCompleted = $true\n"
        "}\n\n"
        "Register-ObjectEvent -InputObject $WebClient -EventName DownloadFileCompleted -Action $OnComplete | Out-Null\n\n"
        "# Trigger download on shown\n"
        "$Form.Add_Shown({\n"
        "    $WebClient.DownloadFileAsync((New-Object System.Uri($DownloadUrl)), $TempZip)\n"
        "})\n\n"
        "$Form.Show()\n\n"
        "# Event loop for GUI during download (optimized with size polling instead of progress event overhead)\n"
        "$LastProgress = -1\n"
        "while (-not $global:DownloadCompleted) {\n"
        "    $CurrentSize = 0\n"
        "    if (Test-Path $TempZip) {\n"
        "        $CurrentSize = (Get-Item $TempZip).Length\n"
        "    }\n"
        "    $Progress = 0\n"
        "    if ($AssetSize -gt 0) {\n"
        "        $Progress = [int]($CurrentSize / $AssetSize * 100)\n"
        "    }\n"
        "    if ($Progress -gt 100) { $Progress = 100 }\n"
        "    \n"
        "    if ($Progress -ne $LastProgress) {\n"
        "        $LastProgress = $Progress\n"
        "        $Label.Text = \"$($Texts.Downloading) $Progress%\"\n"
        "        $ProgressBar.Value = $Progress\n"
        "    }\n"
        "    [System.Windows.Forms.Application]::DoEvents()\n"
        "    Start-Sleep -Milliseconds 100\n"
        "}\n\n"
        "# Cleanup WebClient\n"
        "Get-EventSubscriber | Unregister-Event\n"
        "$WebClient.Dispose()\n\n"
        "if ($global:DownloadFailed) {\n"
        "    $ErrorMsg = $Texts.DownloadError -f $global:ErrorMsg\n"
        "    [System.Windows.Forms.MessageBox]::Show(\n"
        "        $ErrorMsg,\n"
        "        $Texts.ErrorTitle,\n"
        "        [System.Windows.Forms.MessageBoxButtons]::OK,\n"
        "        [System.Windows.Forms.MessageBoxIcon]::Error\n"
        "    )\n"
        "    $Form.Close()\n"
        "    exit 1\n"
        "}\n\n"
        "# 4. Extract update (Optimized using .NET ZipFile instead of Expand-Archive)\n"
        "$Label.Text = $Texts.Extracting\n"
        "$ProgressBar.Style = \"Marquee\"\n"
        "[System.Windows.Forms.Application]::DoEvents()\n\n"
        "if (Test-Path $TempExtractDir) {\n"
        "    Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue\n"
        "}\n"
        "New-Item -ItemType Directory -Path $TempExtractDir -Force | Out-Null\n\n"
        "try {\n"
        "    Add-Type -AssemblyName System.IO.Compression.FileSystem\n"
        "    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZip, $TempExtractDir)\n"
        "} catch {\n"
        "    $ErrorMsg = $Texts.ExtractError -f $_\n"
        "    [System.Windows.Forms.MessageBox]::Show(\n"
        "        $ErrorMsg,\n"
        "        $Texts.ErrorTitle,\n"
        "        [System.Windows.Forms.MessageBoxButtons]::OK,\n"
        "        [System.Windows.Forms.MessageBoxIcon]::Error\n"
        "    )\n"
        "    Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue\n"
        "    $Form.Close()\n"
        "    exit 1\n"
        "}\n\n"
        "# 5. Copy and overwrite files\n"
        "$Label.Text = $Texts.Updating\n"
        "[System.Windows.Forms.Application]::DoEvents()\n\n"
        "$SourcePath = $TempExtractDir\n"
        "$SubDirs = Get-ChildItem -Path $TempExtractDir\n"
        "if ($SubDirs.Count -eq 1 -and $SubDirs[0].Attributes -match \"Directory\") {\n"
        "    $SourcePath = $SubDirs[0].FullName\n"
        "}\n\n"
        "try {\n"
        "    Copy-Item -Path \"$SourcePath\\*\" -Destination $AppDir -Recurse -Force\n"
        "} catch {\n"
        "    $ErrorMsg = $Texts.UpdateError -f $_\n"
        "    [System.Windows.Forms.MessageBox]::Show(\n"
        "        $ErrorMsg,\n"
        "        $Texts.ErrorTitle,\n"
        "        [System.Windows.Forms.MessageBoxButtons]::OK,\n"
        "        [System.Windows.Forms.MessageBoxIcon]::Error\n"
        "    )\n"
        "    Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue\n"
        "    Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue\n"
        "    $Form.Close()\n"
        "    exit 1\n"
        "}\n\n"
        "# Cleanup\n"
        "$Label.Text = $Texts.Cleaning\n"
        "[System.Windows.Forms.Application]::DoEvents()\n"
        "Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue\n"
        "Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue\n\n"
        "$Form.Close()\n\n"
        "# 6. Completion Message and Restart\n"
        "[System.Windows.Forms.MessageBox]::Show(\n"
        "    $Texts.Completed,\n"
        "    $Texts.CompletedTitle,\n"
        "    [System.Windows.Forms.MessageBoxButtons]::OK,\n"
        "    [System.Windows.Forms.MessageBoxIcon]::Information\n"
        ")\n\n"
        "Write-Host \"Restarting application...\"\n"
        "$ExePath = Join-Path $AppDir $ExeName\n"
        "if (Test-Path $ExePath) {\n"
        "    Start-Process -FilePath $ExePath\n"
        "} else {\n"
        "    $NewExe = Get-ChildItem -Path $AppDir -Filter \"*.exe\" | Select-Object -First 1\n"
        "    if ($null -ne $NewExe) {\n"
        "        Start-Process -FilePath $NewExe.FullName\n"
        "    }\n"
        "}\n"
    );
}
