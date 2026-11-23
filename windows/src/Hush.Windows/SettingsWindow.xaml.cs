using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using Button = System.Windows.Controls.Button;
using RadioButton = System.Windows.Controls.RadioButton;
using System.Windows.Input;
using Hush.Core;
using Hush.Windows.Services;
using Hush.Windows.ViewModels;

namespace Hush.Windows;

public partial class SettingsWindow : Window
{
    private readonly AppController _controller;
    private readonly SettingsViewModel _viewModel;
    private bool _allowClose;

    public SettingsWindow(AppController controller)
    {
        _controller = controller;
        _viewModel = controller.SettingsVm;

        InitializeComponent();
        DataContext = _viewModel;
        ShowPage("General");
    }

    public void ShowSettings()
    {
        if (!IsVisible) Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    public void AllowClose() => _allowClose = true;

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        if (_allowClose) return;
        e.Cancel = true;
        Hide();
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Hide();

    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left)
        {
            try { DragMove(); } catch { }
        }
    }

    private void Nav_Checked(object sender, RoutedEventArgs e)
    {
        if (GeneralPage == null) return;
        if (sender is RadioButton { Tag: string page })
            ShowPage(page);
    }

    private void ShowPage(string page)
    {
        if (GeneralPage == null) return;

        GeneralPage.Visibility = page == "General" ? Visibility.Visible : Visibility.Collapsed;
        ModelPage.Visibility = page == "Model" ? Visibility.Visible : Visibility.Collapsed;
        WordsPage.Visibility = page == "Words" ? Visibility.Visible : Visibility.Collapsed;
        HistoryPage.Visibility = page == "History" ? Visibility.Visible : Visibility.Collapsed;
        AboutPage.Visibility = page == "About" ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OpenMic_Click(object sender, RoutedEventArgs e) => _viewModel.OpenMicSettings();

    private void GoModel_Click(object sender, RoutedEventArgs e)
    {
        NavModel.IsChecked = true;
        ShowPage("Model");
    }

    private void RecordHotkey_Click(object sender, RoutedEventArgs e)
    {
        if (_viewModel.IsCapturing)
            _viewModel.CancelHotkeyCapture();
        else
            _viewModel.BeginHotkeyCapture();
    }

    private void HotkeyPreset_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: HotkeyBinding binding })
            _viewModel.UseHotkeyPreset(binding);
    }

    private async void ModelAction_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: ModelRowViewModel row })
            await _viewModel.ActivateModelAsync(row);
    }

    private void AddWord_Click(object sender, RoutedEventArgs e) => _viewModel.AddDictionaryEntry();

    private void RemoveWord_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: DictionaryEntry entry })
            _viewModel.RemoveDictionaryEntry(entry);
    }

    private void WordTextChanged(object sender, TextChangedEventArgs e) => _viewModel.SaveWords();

    private void AddSnippet_Click(object sender, RoutedEventArgs e) => _viewModel.AddSnippet();

    private void RemoveSnippet_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: Snippet snippet })
            _viewModel.RemoveSnippet(snippet);
    }

    private void CopyHistory_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: HistoryEntry entry })
            _viewModel.CopyHistory(entry);
    }

    private void DeleteHistory_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: HistoryEntry entry })
            _viewModel.DeleteHistory(entry);
    }

    private void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        var result = System.Windows.MessageBox.Show(
            Loc.Instance["ClearHistoryMessage"],
            Loc.Instance["ClearHistoryTitle"],
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
            _viewModel.ClearHistory();
    }

    private void OpenGitHub_Click(object sender, RoutedEventArgs e) =>
        _viewModel.OpenUrl(AppInfo.Repository);
}
