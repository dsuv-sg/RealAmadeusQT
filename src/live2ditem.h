#pragma once

#include <QQuickFramebufferObject>

class Live2DItem : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(QString modelPath READ modelPath WRITE setModelPath NOTIFY modelPathChanged)
    Q_PROPERTY(QString emotion READ emotion WRITE setEmotion NOTIFY emotionChanged)
    Q_PROPERTY(float lipSyncValue READ lipSyncValue WRITE setLipSyncValue NOTIFY lipSyncValueChanged)

public:
    explicit Live2DItem(QQuickItem* parent = nullptr);

    Renderer* createRenderer() const override;

    QString modelPath() const;
    void setModelPath(const QString& value);

    QString emotion() const;
    void setEmotion(const QString& value);

    float lipSyncValue() const;
    void setLipSyncValue(float value);

signals:
    void modelPathChanged();
    void emotionChanged();
    void lipSyncValueChanged();

protected:
    // Override to support lazy initialization when item becomes visible
    void itemChange(ItemChange change, const ItemChangeData& value) override;

private:
    QString m_modelPath;
    QString m_emotion;
    float m_lipSyncValue;
    bool m_lazyInitialized = false;  // Track if model has been loaded
    
    void TryLazyInitialize();
};
