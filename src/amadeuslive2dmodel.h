#pragma once

#include <QString>
#include <QStringList>

class AmadeusLive2DModel {
public:
    enum class RenderBackend {
        OpenGL,    // OpenGL/OpenGL ES (fallback for all platforms)
        DirectX11, // Windows only
        Vulkan,    // Windows, Linux
        Metal      // iOS only
    };

    AmadeusLive2DModel();
    ~AmadeusLive2DModel();

    // Lazy load: should be called after window is visible, not at startup
    bool EnsureLoaded(const QString& modelDirectory);
    
    // Get current renderer backend being used
    RenderBackend GetCurrentBackend() const;
    QString GetBackendName() const;
    
    // Get list of available backends for this OS (in preferred order)
    static QStringList GetAvailableBackends();
    
    void SetEmotionTag(const QString& emotionTag);
    void SetLipSyncValue(float value);
    void SetEyeTracking(float eyeX, float eyeY);
    void SetLightweightMode(bool enabled);
    void Update(float deltaSeconds);
    void Draw(int width, int height);

private:
    class InnerModel;
    InnerModel* m_inner;
    RenderBackend m_currentBackend;
    
    // Attempt to initialize with specific backend; return false to try fallback
    bool TryInitializeWithBackend(const QString& modelDirectory, RenderBackend backend);
};
