using System.Text;

namespace Hush.Core;

public sealed record HotkeyBinding
{
    public int VirtualKey { get; init; }
    public HotkeyModifiers Modifiers { get; init; } = HotkeyModifiers.None;
    public HotkeyMode Mode { get; init; } = HotkeyMode.Hold;
    public string KeyLabel { get; init; } = "";

    public bool IsValid => VirtualKey != 0;

    public string Display(AppLanguage language)
    {
        if (VirtualKey is 0xA5)
            return L10n.T(language, "Right Alt", "Правый Alt");
        if (VirtualKey is 0xA3)
            return L10n.T(language, "Right Ctrl", "Правый Ctrl");
        if (VirtualKey is 0xA2)
            return L10n.T(language, "Left Ctrl", "Левый Ctrl");
        if (VirtualKey is 0xA1)
            return L10n.T(language, "Right Shift", "Правый Shift");
        if (VirtualKey is 0xA0)
            return L10n.T(language, "Left Shift", "Левый Shift");
        if (VirtualKey is 0x5C)
            return L10n.T(language, "Right Win", "Правый Win");
        if (VirtualKey is 0x5B)
            return L10n.T(language, "Left Win", "Левый Win");

        var builder = new StringBuilder();
        if (Modifiers.HasFlag(HotkeyModifiers.Control)) builder.Append("Ctrl+");
        if (Modifiers.HasFlag(HotkeyModifiers.Alt)) builder.Append("Alt+");
        if (Modifiers.HasFlag(HotkeyModifiers.Shift)) builder.Append("Shift+");
        if (Modifiers.HasFlag(HotkeyModifiers.Win)) builder.Append("Win+");

        builder.Append(string.IsNullOrWhiteSpace(KeyLabel) ? KeyName(VirtualKey) : KeyLabel);
        return builder.ToString();
    }

    public bool Matches(int virtualKey, HotkeyModifiers modifiers) =>
        VirtualKey == virtualKey && Modifiers == modifiers;

    public static HotkeyBinding Default => RightAltHold;

    public static HotkeyBinding RightAltHold => new()
    {
        VirtualKey = 0xA5,
        Modifiers = HotkeyModifiers.None,
        Mode = HotkeyMode.Hold,
        KeyLabel = "Right Alt"
    };

    public static HotkeyBinding CtrlAltSpace => new()
    {
        VirtualKey = 0x20,
        Modifiers = HotkeyModifiers.Control | HotkeyModifiers.Alt,
        Mode = HotkeyMode.Toggle,
        KeyLabel = "Space"
    };

    public static HotkeyBinding F8Hold => new()
    {
        VirtualKey = 0x77,
        Modifiers = HotkeyModifiers.None,
        Mode = HotkeyMode.Hold,
        KeyLabel = "F8"
    };

    public static HotkeyBinding F9Toggle => new()
    {
        VirtualKey = 0x78,
        Modifiers = HotkeyModifiers.None,
        Mode = HotkeyMode.Toggle,
        KeyLabel = "F9"
    };

    public static IReadOnlyList<HotkeyBinding> Presets { get; } =
        [RightAltHold, CtrlAltSpace, F8Hold, F9Toggle];

    public static string KeyName(int virtualKey) => virtualKey switch
    {
        >= 0x41 and <= 0x5A => ((char)virtualKey).ToString(),
        >= 0x30 and <= 0x39 => ((char)virtualKey).ToString(),
        >= 0x70 and <= 0x87 => $"F{virtualKey - 0x6F}",
        0x08 => "Backspace",
        0x09 => "Tab",
        0x0D => "Enter",
        0x1B => "Esc",
        0x20 => "Space",
        0x21 => "Page Up",
        0x22 => "Page Down",
        0x23 => "End",
        0x24 => "Home",
        0x25 => "Left",
        0x26 => "Up",
        0x27 => "Right",
        0x28 => "Down",
        0x2D => "Insert",
        0x2E => "Delete",
        0xBA => ";",
        0xBB => "=",
        0xBC => ",",
        0xBD => "-",
        0xBE => ".",
        0xBF => "/",
        0xC0 => "`",
        0xDB => "[",
        0xDC => "\\",
        0xDD => "]",
        0xDE => "'",
        _ => $"VK 0x{virtualKey:X2}"
    };
}
