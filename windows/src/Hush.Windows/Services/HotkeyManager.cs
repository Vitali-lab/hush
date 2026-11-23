using System.Windows;
using Application = System.Windows.Application;

using System.Runtime.InteropServices;
using Hush.Core;

namespace Hush.Windows.Services;

public sealed class HotkeyManager : IDisposable
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;
    private const uint WM_QUIT = 0x0012;
    private const uint LLKHF_INJECTED = 0x10;

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private readonly object _sync = new();
    private readonly HashSet<int> _down = [];
    private HotkeyBinding _binding = HotkeyBinding.Default;
    private LowLevelKeyboardProc? _proc;
    private IntPtr _hook;
    private Thread? _thread;
    private uint _threadId;
    private bool _capture;
    private HotkeyMode _captureMode;
    private System.Threading.Timer? _captureTimer;
    private bool _holdActive;

    public event Action? Pressed;
    public event Action? Released;
    public event Action? ToggleRequested;
    public event Action? CancelRequested;
    public event Action<HotkeyBinding>? Captured;
    public event Action? CaptureCancelled;
    public event Action<string>? HookFailed;

    public HotkeyBinding Binding
    {
        get { lock (_sync) return _binding; }
        set
        {
            lock (_sync)
            {
                _binding = value;
                _captureMode = value.Mode;
                _holdActive = false;
            }
        }
    }

    public void Start()
    {
        if (_thread != null) return;

        _proc = HookCallback;
        _thread = new Thread(HookThread)
        {
            IsBackground = true,
            Name = "HushHotkeyHook"
        };
        _thread.Start();
    }

    public void BeginCapture(HotkeyMode mode)
    {
        lock (_sync)
        {
            _capture = true;
            _captureMode = mode;
            _captureTimer?.Dispose();
            _captureTimer = null;
        }
    }

    public void CancelCapture()
    {
        lock (_sync)
        {
            _capture = false;
            _captureTimer?.Dispose();
            _captureTimer = null;
        }
    }

    private void HookThread()
    {
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc!, GetModuleHandle(null), 0);
        if (_hook == IntPtr.Zero)
        {
            var error = Marshal.GetLastWin32Error();
            Dispatch(() => HookFailed?.Invoke($"Keyboard hook failed ({error}). Try restarting Hush."));
            return;
        }

        _threadId = GetCurrentThreadId();

        while (GetMessage(out var message, IntPtr.Zero, 0, 0) > 0)
        {
            TranslateMessage(ref message);
            DispatchMessage(ref message);
        }

        UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
            var message = wParam.ToInt32();
            var down = message is WM_KEYDOWN or WM_SYSKEYDOWN;
            var up = message is WM_KEYUP or WM_SYSKEYUP;

            if ((data.flags & LLKHF_INJECTED) == 0)
                HandleKey((int)data.vkCode, down, up);
        }

        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    private void HandleKey(int virtualKey, bool down, bool up)
    {
        if (up)
        {
            lock (_sync)
            {
                if (_holdActive && virtualKey == _binding.VirtualKey && _binding.Mode == HotkeyMode.Hold)
                {
                    _holdActive = false;
                    Dispatch(() => Released?.Invoke());
                }

                _down.Remove(virtualKey);
            }
            return;
        }

        if (!down) return;

        lock (_sync)
        {
            if (_down.Contains(virtualKey)) return;

            if (_capture)
            {
                HandleCaptureLocked(virtualKey);
                _down.Add(virtualKey);
                return;
            }

            if (virtualKey == 0x1B)
            {
                Dispatch(() => CancelRequested?.Invoke());
                _down.Add(virtualKey);
                return;
            }

            var modifiers = CurrentModifiersLocked();
            if (virtualKey == _binding.VirtualKey && modifiers == _binding.Modifiers)
            {
                if (_binding.Mode == HotkeyMode.Hold)
                {
                    _holdActive = true;
                    Dispatch(() => Pressed?.Invoke());
                }
                else
                    Dispatch(() => ToggleRequested?.Invoke());
            }

            _down.Add(virtualKey);
        }
    }

    private void HandleCaptureLocked(int virtualKey)
    {
        if (virtualKey == 0x1B)
        {
            _capture = false;
            _captureTimer?.Dispose();
            _captureTimer = null;
            Dispatch(() => CaptureCancelled?.Invoke());
            return;
        }

        if (IsModifierKey(virtualKey))
        {
            _captureTimer?.Dispose();
            _captureTimer = new System.Threading.Timer(_ => FinishModifierCapture(virtualKey, _captureMode), null, 350, Timeout.Infinite);
            return;
        }

        _captureTimer?.Dispose();
        _captureTimer = null;
        _capture = false;

        var modifiers = CurrentModifiersLocked();
        var binding = new HotkeyBinding
        {
            VirtualKey = virtualKey,
            Modifiers = modifiers,
            Mode = _captureMode,
            KeyLabel = HotkeyBinding.KeyName(virtualKey)
        };

        Dispatch(() => Captured?.Invoke(binding));
    }

    private void FinishModifierCapture(int virtualKey, HotkeyMode mode)
    {
        lock (_sync)
        {
            if (!_capture) return;
            _capture = false;
            _captureTimer?.Dispose();
            _captureTimer = null;

            var binding = new HotkeyBinding
            {
                VirtualKey = virtualKey,
                Modifiers = HotkeyModifiers.None,
                Mode = mode,
                KeyLabel = HotkeyBinding.KeyName(virtualKey)
            };

            Dispatch(() => Captured?.Invoke(binding));
        }
    }

    private HotkeyModifiers CurrentModifiersLocked()
    {
        var modifiers = HotkeyModifiers.None;

        if (_down.Contains(0xA2) || _down.Contains(0xA3)) modifiers |= HotkeyModifiers.Control;
        if (_down.Contains(0xA4) || _down.Contains(0xA5)) modifiers |= HotkeyModifiers.Alt;
        if (_down.Contains(0xA0) || _down.Contains(0xA1)) modifiers |= HotkeyModifiers.Shift;
        if (_down.Contains(0x5B) || _down.Contains(0x5C)) modifiers |= HotkeyModifiers.Win;

        return modifiers;
    }

    private static bool IsModifierKey(int virtualKey) => virtualKey is
        0xA0 or 0xA1 or 0xA2 or 0xA3 or 0xA4 or 0xA5 or 0x5B or 0x5C;

    private static void Dispatch(Action action)
    {
        var app = Application.Current;
        if (app == null)
        {
            action();
            return;
        }

        try
        {
            if (app.Dispatcher.CheckAccess())
                action();
            else
                app.Dispatcher.BeginInvoke(action);
        }
        catch
        {
            // The app can be shutting down while the hook is still alive.
        }
    }

    public void Dispose()
    {
        lock (_sync)
        {
            _capture = false;
            _captureTimer?.Dispose();
            _captureTimer = null;
        }

        if (_hook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_hook);
            _hook = IntPtr.Zero;
        }

        if (_threadId != 0)
            PostThreadMessage(_threadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero);

        _thread = null;
        _threadId = 0;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public int x;
        public int y;
        public uint lPrivate;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? lpModuleName);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref MSG lpMsg);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref MSG lpMsg);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PostThreadMessage(uint idThread, uint msg, IntPtr wParam, IntPtr lParam);
}
