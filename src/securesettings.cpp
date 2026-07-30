#include "securesettings.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QSysInfo>
#include <QRandomGenerator>

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincrypt.h>
#endif

// ─────────────────────────────────────────────────────
// Key derivation (machine-specific, matches Unity scheme)
// ─────────────────────────────────────────────────────
QByteArray SecureSettings::deriveKey()
{
    const QString fingerprint = QStringLiteral("%1|%2|%3|%4")
        .arg(QCoreApplication::organizationName(),
             QCoreApplication::applicationName(),
             QSysInfo::machineUniqueId().isEmpty()
                 ? QSysInfo::machineHostName()
                 : QString::fromUtf8(QSysInfo::machineUniqueId()),
             qEnvironmentVariable("USERNAME", qEnvironmentVariable("USER", "default")));

    return QCryptographicHash::hash(fingerprint.toUtf8(), QCryptographicHash::Sha256);
}

// ─────────────────────────────────────────────────────
// XOR-based obfuscation fallback (cross-platform)
// NOTE: This is NOT real AES. On Windows, DPAPI is used instead.
// This fallback provides only basic obfuscation for non-Windows platforms.
// ─────────────────────────────────────────────────────
QByteArray SecureSettings::encryptAesCbc(const QString &plainText)
{
    const QByteArray key = deriveKey();
    const QByteArray plain = plainText.toUtf8();

    // Generate 16-byte IV
    QByteArray iv(16, 0);
    for (int i = 0; i < 16; ++i)
        iv[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));

    // XOR encrypt with key+IV rotation
    QByteArray cipher(plain.size(), 0);
    for (int i = 0; i < plain.size(); ++i) {
        cipher[i] = static_cast<char>(
            plain.at(i) ^ key.at(i % key.size()) ^ iv.at(i % iv.size()));
    }

    // Output: IV + cipher
    QByteArray output;
    output.reserve(iv.size() + cipher.size());
    output.append(iv);
    output.append(cipher);
    return output;
}

QString SecureSettings::decryptAesCbc(const QByteArray &payload)
{
    if (payload.size() <= 16)
        return {};

    const QByteArray key = deriveKey();
    const QByteArray iv = payload.left(16);
    const QByteArray cipher = payload.mid(16);

    QByteArray plain(cipher.size(), 0);
    for (int i = 0; i < cipher.size(); ++i) {
        plain[i] = static_cast<char>(
            cipher.at(i) ^ key.at(i % key.size()) ^ iv.at(i % iv.size()));
    }

    return QString::fromUtf8(plain);
}

// ─────────────────────────────────────────────────────
// Windows DPAPI
// ─────────────────────────────────────────────────────
#ifdef Q_OS_WIN
QByteArray SecureSettings::encryptDpapi(const QByteArray &data)
{
    DATA_BLOB input;
    input.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(data.data()));
    input.cbData = static_cast<DWORD>(data.size());

    DATA_BLOB output;
    if (!CryptProtectData(&input, nullptr, nullptr, nullptr, nullptr, 0, &output))
        return {};

    QByteArray result(reinterpret_cast<const char *>(output.pbData),
                      static_cast<int>(output.cbData));
    LocalFree(output.pbData);
    return result;
}

QByteArray SecureSettings::decryptDpapi(const QByteArray &data)
{
    DATA_BLOB input;
    input.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(data.data()));
    input.cbData = static_cast<DWORD>(data.size());

    DATA_BLOB output;
    if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, 0, &output))
        return {};

    QByteArray result(reinterpret_cast<const char *>(output.pbData),
                      static_cast<int>(output.cbData));
    LocalFree(output.pbData);
    return result;
}
#endif

// ─────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────
void SecureSettings::setProtectedString(QSettings &settings, const QString &key,
                                        const QString &value)
{
    if (value.isEmpty()) {
        settings.remove(key);
        return;
    }

    QByteArray encrypted;

#ifdef Q_OS_WIN
    encrypted = encryptDpapi(value.toUtf8());
    if (!encrypted.isEmpty()) {
        settings.setValue(key, QString::fromUtf8(kEncPrefix) + encrypted.toBase64());
        return;
    }
#endif

    // Fallback
    encrypted = encryptAesCbc(value);
    settings.setValue(key, QString::fromUtf8(kEncPrefix) + encrypted.toBase64());
}

QString SecureSettings::getProtectedString(QSettings &settings, const QString &key,
                                           const QString &defaultValue)
{
    const QString raw = settings.value(key, "").toString();
    if (raw.isEmpty())
        return defaultValue;

    // Not encrypted — plaintext (legacy migration)
    if (!raw.startsWith(QLatin1String(kEncPrefix)))
        return raw;

    const QByteArray payload = QByteArray::fromBase64(
        raw.mid(static_cast<int>(strlen(kEncPrefix))).toUtf8());

#ifdef Q_OS_WIN
    {
        const QByteArray decrypted = decryptDpapi(payload);
        if (!decrypted.isEmpty())
            return QString::fromUtf8(decrypted);
    }
#endif

    // Fallback decryption
    const QString result = decryptAesCbc(payload);
    return result.isEmpty() ? defaultValue : result;
}

QString SecureSettings::maskApiKey(const QString &key)
{
    if (key.length() <= 8)
        return QStringLiteral("***");
    return key.left(4) + QStringLiteral("...") + key.right(4);
}
