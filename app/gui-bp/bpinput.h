#pragma once

#include <QObject>
#include <QTimer>
#include <QList>

#include "SDL_compat.h"

class StreamingPreferences;

// Gamepad input for the Big Picture UI.
//
// Unlike SdlGamepadKeyNavigation (used by the desktop UI), this does not
// synthesize keyboard events. It translates controller input into semantic
// actions (navigate, accept, back, tab switching, ...) with console-style
// hold-to-repeat. Keyboard input is mapped onto the same actions via
// actionForKey(), so the QML side has exactly one input path.
//
// Only SDL and Qt are used here so this builds on every platform
// (Windows first, Steam Deck/Linux later).
class BpInput : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int gamepadCount READ gamepadCount NOTIFY gamepadsChanged)
    Q_PROPERTY(QString controllerFamily READ controllerFamily NOTIFY gamepadsChanged)
    Q_PROPERTY(bool usingGamepad READ usingGamepad NOTIFY usingGamepadChanged)

public:
    enum Action {
        None = 0,
        Up,
        Down,
        Left,
        Right,
        Accept,     // A / Cross
        Back,       // B / Circle
        Option,     // X / Square
        Secondary,  // Y / Triangle
        Menu,       // Start / Options
        View,       // Back / Select / Share
        PrevTab,    // LB / L1
        NextTab,    // RB / R1
        PageUp,     // LT / L2
        PageDown,   // RT / R2
    };
    Q_ENUM(Action)

    explicit BpInput(StreamingPreferences* prefs, QObject* parent = nullptr);
    ~BpInput() override;

    // Must be disabled while a streaming Session owns the SDL gamepad subsystem
    Q_INVOKABLE void enable();
    Q_INVOKABLE void disable();

    Q_INVOKABLE void notifyWindowFocus(bool hasFocus);

    // Maps a Qt key (from a QML KeyEvent) to an Action, or None
    Q_INVOKABLE int actionForKey(int key) const;

    // Called by QML when a keyboard action was dispatched
    Q_INVOKABLE void notifyKeyboardUsed();

    // Short haptic tick on the gamepad that was used last
    Q_INVOKABLE void rumbleTick();

    int gamepadCount() const;
    QString controllerFamily() const;
    bool usingGamepad() const;

signals:
    void action(int action, bool isRepeat);
    void gamepadsChanged();
    void usingGamepadChanged();

private slots:
    void onPollingTimerFired();

private:
    enum DirSource { SrcNone, SrcDpad, SrcStick };

    void updateTimerState();
    void openGamepad(int deviceIndex);
    void closeGamepad(SDL_JoystickID instanceId);
    void setUsingGamepad(bool usingGamepad);
    void emitAction(Action action, bool isRepeat);
    void startHold(Action dir, DirSource source);
    void stopHold(DirSource source);
    Action stickDirection();
    void pollTriggers();
    Action mapButton(int button) const;

    StreamingPreferences* m_Prefs;
    QTimer* m_PollingTimer;
    QList<SDL_GameController*> m_Gamepads;
    SDL_GameController* m_LastUsedGamepad;
    bool m_Enabled;
    bool m_HasFocus;
    bool m_FirstPoll;
    bool m_UsingGamepad;

    // Hold-to-repeat state for directional input
    Action m_HeldDir;
    DirSource m_HeldSource;
    Uint32 m_HoldStartTime;
    Uint32 m_NextRepeatTime;

    // Stick and trigger edge detection
    Action m_StickDir;
    bool m_LeftTriggerDown;
    bool m_RightTriggerDown;
};
