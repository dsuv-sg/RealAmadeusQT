#pragma once

#include <QQuickFramebufferObject>

class Live2DItem : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(QString modelPath READ modelPath WRITE setModelPath NOTIFY modelPathChanged)
    Q_PROPERTY(QString emotion READ emotion WRITE setEmotion NOTIFY emotionChanged)
    Q_PROPERTY(float lipSyncValue READ lipSyncValue WRITE setLipSyncValue NOTIFY lipSyncValueChanged)
    Q_PROPERTY(float eyeX READ eyeX WRITE setEyeX NOTIFY eyeXChanged)
    Q_PROPERTY(float eyeY READ eyeY WRITE setEyeY NOTIFY eyeYChanged)
    Q_PROPERTY(bool lightweightMode READ lightweightMode WRITE setLightweightMode NOTIFY lightweightModeChanged)
    Q_PROPERTY(QString spokenChar READ spokenChar WRITE setSpokenChar NOTIFY spokenCharChanged)

public:
    explicit Live2DItem(QQuickItem* parent = nullptr);

    Renderer* createRenderer() const override;

    QString modelPath() const;
    void setModelPath(const QString& value);

    QString emotion() const;
    void setEmotion(const QString& value);

    float lipSyncValue() const;
    void setLipSyncValue(float value);

    float eyeX() const;
    void setEyeX(float value);

    float eyeY() const;
    void setEyeY(float value);

    bool lightweightMode() const;
    void setLightweightMode(bool value);

    QString spokenChar() const;
    void setSpokenChar(const QString& value);

signals:
    void modelPathChanged();
    void emotionChanged();
    void lipSyncValueChanged();
    void eyeXChanged();
    void eyeYChanged();
    void lightweightModeChanged();
    void spokenCharChanged();

protected:
    // Override to support lazy initialization when item becomes visible
    void itemChange(ItemChange change, const ItemChangeData& value) override;

private:
    QString m_modelPath;
    QString m_emotion;
    float m_lipSyncValue = 0.0f;
    float m_eyeX = 0.0f;
    float m_eyeY = 0.0f;
    bool m_lightweightMode = false;
    bool m_lazyInitialized = false;  // Track if model has been loaded
    QString m_spokenChar;

    void TryLazyInitialize();
};
