using System.Windows;
using Clipboard = System.Windows.Clipboard;

using System.Runtime.InteropServices;

namespace Hush.Windows.Services;

/// <summary>
/// Puts the result on the clipboard and sends Ctrl+V. The previous text
/// clipboard is restored when possible; other clipboard formats are left alone.
/// </summary>
public static class TextInserter
{
    public static async Task<bool> InsertAsync(string text, bool autoPaste)
    {
        var value = text.Trim();
        if (value.Length == 0) return false;

        string? previous = null;
        try
        {
            if (Clipboard.ContainsText()) previous = Clipboard.GetText();
            Clipboard.SetText(value);
        }
        catch
        {
            return false;
        }

        if (!autoPaste) return false;

        try
        {
            await Task.Delay(60);
            if (!SendPaste()) return false;

            await Task.Delay(600);
            if (previous != null && Clipboard.ContainsText() && Clipboard.GetText() == value)
                Clipboard.SetText(previous);

            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool SendPaste()
    {
        const ushort vkControl = 0x11;
        const ushort vkV = 0x56;
        const uint keyUp = 0x0002;

        var inputs = new INPUT[4];

        inputs[0].type = 1;
        inputs[0].u.ki = new KEYBDINPUT { wVk = vkControl };
        inputs[1].type = 1;
        inputs[1].u.ki = new KEYBDINPUT { wVk = vkV };
        inputs[2].type = 1;
        inputs[2].u.ki = new KEYBDINPUT { wVk = vkV, dwFlags = keyUp };
        inputs[3].type = 1;
        inputs[3].u.ki = new KEYBDINPUT { wVk = vkControl, dwFlags = keyUp };

        var sent = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
        return sent == inputs.Length;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
}
