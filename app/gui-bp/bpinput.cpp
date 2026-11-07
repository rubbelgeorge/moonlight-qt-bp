#include "bpinput.h"

#include <QCoreApplication>

#include "settings/mappingmanager.h"
#include "settings/streamingpreferences.h"

// Polling interval while the window is focused (~60 Hz for smooth repeat)
#define POLL_INTERVAL_MS 16

// Hold-to-repeat timing: initial delay, then repeat interval that
// accelerates down to a minimum the longer the direction is held.
#define REPEAT_INITIAL_DELAY_MS 380
#define REPEAT_START_INTERVAL_MS 140
#define REPEAT_MIN_INTERVAL_MS 55
#define REPEAT_ACCEL_AFTER_MS 1200

// Analog thresholds with hysteresis so the stick doesn't flicker
#define STICK_PRESS_THRESHOLD 20000
#define STICK_RELEASE_THRESHOLD 12000
#define TRIGGER_PRESS_THRESHOLD 20000
#define TRIGGER_RELEASE_THRESHOLD 10000

BpInput::BpInput(StreamingPreferences* prefs, QObject* parent)
    : QObject(parent),
      m_Prefs(prefs),
      m_LastUsedGamepad(nullptr),
      m_Enabled(false),
      m_HasFocus(false),
      m_FirstPoll(false),
      m_UsingGamepad(false),
      m_HeldDir(None),
      m_HeldSource(SrcNone),
      m_HoldStartTime(0),
      m_NextRepeatTime(0),
      m_StickDir(None),
      m_LeftTriggerDown(false),
      m_RightTriggerDown(false)
{
    m_PollingTimer = new QTimer(this);
    m_PollingTimer->setTimerType(Qt::PreciseTimer);
    connect(m_PollingTimer, &QTimer::timeout, this, &BpInput::onPollingTimerFired);
}

BpInput::~BpInput()
{
    disable();
}

void BpInput::enable()
{
    if (m_Enabled) {
        return;
    }

    // Same lifetime rules as SdlGamepadKeyNavigation: the streaming Session
    // must be able to (re)initialize the gamecontroller subsystem itself.
    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "BpInput: SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) failed: %s",
                     SDL_GetError());
        return;
    }

    MappingManager mappingManager;
    mappingManager.applyMappings();

    // We open the attached gamepads ourselves, so drop the add events
    // SDL generates on subsystem init.
    SDL_JoystickUpdate();
    SDL_FlushEvent(SDL_CONTROLLERDEVICEADDED);

    int numJoysticks = SDL_NumJoysticks();
    for (int i = 0; i < numJoysticks; i++) {
        if (SDL_IsGameController(i)) {
            openGamepad(i);
        }
    }

    m_Enabled = true;
    m_HeldDir = None;
    m_HeldSource = SrcNone;
    m_StickDir = None;
    m_LeftTriggerDown = m_RightTriggerDown = false;

    emit gamepadsChanged();
    if (!m_Gamepads.isEmpty()) {
        setUsingGamepad(true);
    }

    updateTimerState();
}

void BpInput::disable()
{
    if (!m_Enabled) {
        return;
    }

    m_Enabled = false;
    updateTimerState();

    while (!m_Gamepads.isEmpty()) {
        SDL_GameControllerClose(m_Gamepads.takeFirst());
    }
    m_LastUsedGamepad = nullptr;

    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
}

void BpInput::notifyWindowFocus(bool hasFocus)
{
    m_HasFocus = hasFocus;
    updateTimerState();
}

void BpInput::updateTimerState()
{
    bool shouldRun = m_Enabled && m_HasFocus;

    if (m_PollingTimer->isActive() && !shouldRun) {
        m_PollingTimer->stop();
        m_HeldDir = None;
        m_HeldSource = SrcNone;
    }
    else if (!m_PollingTimer->isActive() && shouldRun) {
        // Discard stale input (e.g. the quit combo from a stream) on first poll
        m_FirstPoll = true;
        m_PollingTimer->start(POLL_INTERVAL_MS);
    }
}

void BpInput::openGamepad(int deviceIndex)
{
    SDL_GameController* gc = SDL_GameControllerOpen(deviceIndex);
    if (gc == nullptr) {
        return;
    }

    // SDL_CONTROLLERDEVICEADDED may be reported twice for the same device
    if (m_Gamepads.contains(gc)) {
        SDL_GameControllerClose(gc);
        return;
    }

    m_Gamepads.append(gc);
}

void BpInput::closeGamepad(SDL_JoystickID instanceId)
{
    for (int i = 0; i < m_Gamepads.size(); i++) {
        SDL_GameController* gc = m_Gamepads[i];
        if (SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(gc)) == instanceId) {
            if (gc == m_LastUsedGamepad) {
                m_LastUsedGamepad = nullptr;
            }
            SDL_GameControllerClose(gc);
            m_Gamepads.removeAt(i);
            return;
        }
    }
}

BpInput::Action BpInput::mapButton(int button) const
{
    bool swap = m_Prefs != nullptr && m_Prefs->swapFaceButtons;

    switch (button) {
    case SDL_CONTROLLER_BUTTON_A:
        return swap ? Back : Accept;
    case SDL_CONTROLLER_BUTTON_B:
        return swap ? Accept : Back;
    case SDL_CONTROLLER_BUTTON_X:
        return swap ? Secondary : Option;
    case SDL_CONTROLLER_BUTTON_Y:
        return swap ? Option : Secondary;
    case SDL_CONTROLLER_BUTTON_START:
        return Menu;
    case SDL_CONTROLLER_BUTTON_BACK:
        return View;
    case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
        return PrevTab;
    case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
        return NextTab;
    case SDL_CONTROLLER_BUTTON_DPAD_UP:
        return Up;
    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
        return Down;
    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        return Left;
    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        return Right;
    default:
        return None;
    }
}

void BpInput::onPollingTimerFired()
{
    SDL_Event event;

    // Update joystick state without pumping other events (see SdlGamepadKeyNavigation)
    SDL_JoystickUpdate();

    if (m_FirstPoll) {
        SDL_FlushEvent(SDL_CONTROLLERBUTTONDOWN);
        SDL_FlushEvent(SDL_CONTROLLERBUTTONUP);
        m_FirstPoll = false;
    }

    while (SDL_PeepEvents(&event, 1, SDL_GETEVENT, SDL_FIRSTEVENT, SDL_LASTEVENT) == 1) {
        switch (event.type) {
        case SDL_QUIT:
            QCoreApplication::instance()->quit();
            break;

        case SDL_CONTROLLERBUTTONDOWN:
        {
            SDL_GameController* gc = SDL_GameControllerFromInstanceID(event.cbutton.which);
            if (gc != m_LastUsedGamepad) {
                // Button glyphs may need to change (e.g. Xbox -> PlayStation)
                m_LastUsedGamepad = gc;
                emit gamepadsChanged();
            }
            setUsingGamepad(true);

            Action a = mapButton(event.cbutton.button);
            if (a >= Up && a <= Right) {
                startHold(a, SrcDpad);
            }
            else if (a != None) {
                emitAction(a, false);
            }
            break;
        }

        case SDL_CONTROLLERBUTTONUP:
        {
            Action a = mapButton(event.cbutton.button);
            if (a >= Up && a <= Right && a == m_HeldDir) {
                stopHold(SrcDpad);
            }
            break;
        }

        case SDL_CONTROLLERDEVICEADDED:
            openGamepad(event.cdevice.which);
            emit gamepadsChanged();
            break;

        case SDL_CONTROLLERDEVICEREMOVED:
            closeGamepad(event.cdevice.which);
            emit gamepadsChanged();
            break;

        default:
            break;
        }
    }

    // Left stick acts like the d-pad
    Action stickDir = stickDirection();
    if (stickDir != m_StickDir) {
        m_StickDir = stickDir;
        if (stickDir != None) {
            setUsingGamepad(true);
            startHold(stickDir, SrcStick);
        }
        else {
            stopHold(SrcStick);
        }
    }

    pollTriggers();

    // Hold-to-repeat with acceleration
    if (m_HeldDir != None) {
        Uint32 now = SDL_GetTicks();
        if (SDL_TICKS_PASSED(now, m_NextRepeatTime)) {
            emitAction(m_HeldDir, true);

            Uint32 heldFor = now - m_HoldStartTime;
            int interval = REPEAT_START_INTERVAL_MS;
            if (heldFor > REPEAT_ACCEL_AFTER_MS) {
                // Linearly ramp down to the minimum over one more second
                int extra = qMin<int>(heldFor - REPEAT_ACCEL_AFTER_MS, 1000);
                interval -= (REPEAT_START_INTERVAL_MS - REPEAT_MIN_INTERVAL_MS) * extra / 1000;
            }
            m_NextRepeatTime = now + interval;
        }
    }
}

BpInput::Action BpInput::stickDirection()
{
    // Use the gamepad with the strongest deflection
    int bestX = 0, bestY = 0;
    for (auto gc : std::as_const(m_Gamepads)) {
        int x = SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_LEFTX);
        int y = SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_LEFTY);
        if (qAbs(x) + qAbs(y) > qAbs(bestX) + qAbs(bestY)) {
            bestX = x;
            bestY = y;
            if (qAbs(x) > STICK_RELEASE_THRESHOLD || qAbs(y) > STICK_RELEASE_THRESHOLD) {
                m_LastUsedGamepad = gc;
            }
        }
    }

    // Keep the current direction until the stick falls below the release threshold
    if (m_StickDir != None) {
        int along = 0;
        switch (m_StickDir) {
        case Up: along = -bestY; break;
        case Down: along = bestY; break;
        case Left: along = -bestX; break;
        case Right: along = bestX; break;
        default: break;
        }
        if (along > STICK_RELEASE_THRESHOLD) {
            return m_StickDir;
        }
    }

    if (qMax(qAbs(bestX), qAbs(bestY)) < STICK_PRESS_THRESHOLD) {
        return None;
    }

    // Dominant axis wins
    if (qAbs(bestX) > qAbs(bestY)) {
        return bestX < 0 ? Left : Right;
    }
    else {
        return bestY < 0 ? Up : Down;
    }
}

void BpInput::pollTriggers()
{
    int maxLeft = 0, maxRight = 0;
    for (auto gc : std::as_const(m_Gamepads)) {
        maxLeft = qMax<int>(maxLeft, SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_TRIGGERLEFT));
        maxRight = qMax<int>(maxRight, SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_TRIGGERRIGHT));
    }

    if (!m_LeftTriggerDown && maxLeft > TRIGGER_PRESS_THRESHOLD) {
        m_LeftTriggerDown = true;
        setUsingGamepad(true);
        emitAction(PageUp, false);
    }
    else if (m_LeftTriggerDown && maxLeft < TRIGGER_RELEASE_THRESHOLD) {
        m_LeftTriggerDown = false;
    }

    if (!m_RightTriggerDown && maxRight > TRIGGER_PRESS_THRESHOLD) {
        m_RightTriggerDown = true;
        setUsingGamepad(true);
        emitAction(PageDown, false);
    }
    else if (m_RightTriggerDown && maxRight < TRIGGER_RELEASE_THRESHOLD) {
        m_RightTriggerDown = false;
    }
}

void BpInput::startHold(Action dir, DirSource source)
{
    m_HeldDir = dir;
    m_HeldSource = source;
    m_HoldStartTime = SDL_GetTicks();
    m_NextRepeatTime = m_HoldStartTime + REPEAT_INITIAL_DELAY_MS;
    emitAction(dir, false);
}

void BpInput::stopHold(DirSource source)
{
    if (m_HeldSource == source) {
        m_HeldDir = None;
        m_HeldSource = SrcNone;
    }
}

void BpInput::emitAction(Action a, bool isRepeat)
{
    emit action(a, isRepeat);
}

void BpInput::setUsingGamepad(bool usingGamepad)
{
    if (m_UsingGamepad != usingGamepad) {
        m_UsingGamepad = usingGamepad;
        emit usingGamepadChanged();
    }
}

void BpInput::notifyKeyboardUsed()
{
    setUsingGamepad(false);
}

void BpInput::rumbleTick()
{
#if SDL_VERSION_ATLEAST(2, 0, 9)
    SDL_GameController* gc = m_LastUsedGamepad;
    if (gc == nullptr && !m_Gamepads.isEmpty()) {
        gc = m_Gamepads.first();
    }
    if (gc != nullptr && m_Enabled) {
        SDL_GameControllerRumble(gc, 0x1800, 0x2800, 18);
    }
#endif
}

int BpInput::actionForKey(int key) const
{
    switch (key) {
    case Qt::Key_Up:
        return Up;
    case Qt::Key_Down:
        return Down;
    case Qt::Key_Left:
        return Left;
    case Qt::Key_Right:
        return Right;
    case Qt::Key_Return:
    case Qt::Key_Enter:
    case Qt::Key_Space:
    case Qt::Key_Select:
        return Accept;
    case Qt::Key_Escape:
    case Qt::Key_Backspace:
    case Qt::Key_Back:
        return Back;
    case Qt::Key_X:
        return Option;
    case Qt::Key_Y:
        return Secondary;
    case Qt::Key_Menu:
    case Qt::Key_F1:
    case Qt::Key_M:
        return Menu;
    case Qt::Key_V:
        return View;
    case Qt::Key_Q:
        return PrevTab;
    case Qt::Key_E:
        return NextTab;
    case Qt::Key_PageUp:
        return PageUp;
    case Qt::Key_PageDown:
        return PageDown;
    default:
        return None;
    }
}

int BpInput::gamepadCount() const
{
    return m_Gamepads.size();
}

QString BpInput::controllerFamily() const
{
    SDL_GameController* gc = m_LastUsedGamepad;
    if (gc == nullptr && !m_Gamepads.isEmpty()) {
        gc = m_Gamepads.first();
    }
    if (gc == nullptr) {
        return QStringLiteral("keyboard");
    }

#if SDL_VERSION_ATLEAST(2, 0, 12)
    switch (SDL_GameControllerGetType(gc)) {
    case SDL_CONTROLLER_TYPE_PS3:
    case SDL_CONTROLLER_TYPE_PS4:
#if SDL_VERSION_ATLEAST(2, 0, 14)
    case SDL_CONTROLLER_TYPE_PS5:
#endif
        return QStringLiteral("playstation");
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_PRO:
#if SDL_VERSION_ATLEAST(2, 24, 0)
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
#endif
        return QStringLiteral("nintendo");
    default:
        return QStringLiteral("xbox");
    }
#else
    return QStringLiteral("xbox");
#endif
}

bool BpInput::usingGamepad() const
{
    return m_UsingGamepad;
}
