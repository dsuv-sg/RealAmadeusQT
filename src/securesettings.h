#pragma once
#include <QObject>
#include <QSettings>
#include <QString>
#include <QByteArray>

/// SecureSettings - Encrypted storage for sensitive data (API keys, tokens).
/// On Windows: uses DPAPI (CryptProtectData/CryptUnprotectData).
/// Fallback: XOR obfuscation with machine-specific key derivation (NOT real AES).
/// Compatible with Unity SecurePrefs (same "enc:v1:" prefix scheme).
class SecureSettings
{
public:
    /// Store a string securely. Empty value deletes the key.
    static void setProtectedString(QSettings &settings, const QString &key, const QString &value);

    /// Retrieve a securely stored string. Transparently decrypts "enc:v1:" prefixed values
    /// and returns plaintext values as-is (auto-migration).
    static QString getProtectedString(QSettings &settings, const QString &key,
                                      const QString &defaultValue = {});

    /// Mask an API key for safe logging (e.g. "sk-abc...xyz")
    static QString maskApiKey(const QString &key);

private:
    static constexpr const char *kEncPrefix = "enc:v1:";

    static QByteArray deriveKey();
    static QByteArray encryptAesCbc(const QString &plainText);
    static QString decryptAesCbc(const QByteArray &payload);

#ifdef Q_OS_WIN
    static QByteArray encryptDpapi(const QByteArray &data);
    static QByteArray decryptDpapi(const QByteArray &data);
#endif
};
