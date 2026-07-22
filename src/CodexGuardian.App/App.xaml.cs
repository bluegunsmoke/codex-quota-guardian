using System.Configuration;
using System.Data;
using System.Windows;
using System.Drawing;
using Forms = System.Windows.Forms;

namespace CodexGuardian.App;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : System.Windows.Application, IDisposable
{
    private Forms.NotifyIcon? _trayIcon;
    private DashboardWindow? _dashboardWindow;
    private QuotaNotificationWindow? _notificationWindow;
    private Mutex? _singleInstanceMutex;
    private Icon? _applicationIcon;
    private Forms.ContextMenuStrip? _trayMenu;
    private WindowsNotificationService? _windowsNotifications;

    public GuardianSettingsStore SettingsStore { get; } = new();
    public GuardianSettings Settings { get; private set; } = new();

    public bool IsShuttingDown { get; private set; }
    public bool IsMainWindowHiddenByUser { get; private set; }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        _singleInstanceMutex = new Mutex(initiallyOwned: true, "Local\\CodexGuardian.App", out var isFirstInstance);
        if (!isFirstInstance)
        {
            Shutdown();
            return;
        }
        ShutdownMode = ShutdownMode.OnExplicitShutdown;
        Settings = SettingsStore.Load();
        Localization.Apply(Settings.LanguageCode);

        MainWindow = new MainWindow();
        MainWindow.Show();

        _trayMenu = CreateTrayMenu();

        _applicationIcon = string.IsNullOrWhiteSpace(Environment.ProcessPath)
            ? null
            : Icon.ExtractAssociatedIcon(Environment.ProcessPath);
        _trayIcon = new Forms.NotifyIcon
        {
            Icon = _applicationIcon ?? SystemIcons.Information,
            Text = Localization.Text("TrayTooltip"),
            Visible = true,
            ContextMenuStrip = _trayMenu,
        };
        _trayIcon.DoubleClick += (_, _) => ShowMainWindow();
        _windowsNotifications = new WindowsNotificationService(
            ShowDashboard,
            resetAt => (MainWindow as CodexGuardian.App.MainWindow)?.SilenceUntil(resetAt));
        _windowsNotifications.Register();
    }

    public void ShowMainWindow()
    {
        if (MainWindow is null) return;
        IsMainWindowHiddenByUser = false;
        MainWindow.Show();
        if (MainWindow.WindowState == WindowState.Minimized)
            MainWindow.WindowState = WindowState.Normal;
        MainWindow.Activate();
    }

    public void HideMainWindow()
    {
        IsMainWindowHiddenByUser = true;
        MainWindow?.Hide();
    }

    public void ToggleMainWindowVisibility()
    {
        if (MainWindow?.IsVisible == true) HideMainWindow();
        else ShowMainWindow();
    }

    public void RequestExit()
    {
        IsShuttingDown = true;
        MainWindow?.Close();
        Shutdown();
    }

    public void ShowSettings()
    {
        if (MainWindow is not MainWindow owner) return;
        var dialog = new SettingsWindow(SettingsStore, Settings, owner.PreviewAppearance) { Owner = owner };
        if (dialog.ShowDialog() == true && dialog.SavedSettings is { } saved)
        {
            Settings = saved;
            Localization.Apply(saved.LanguageCode);
            owner.ApplySettings(saved);
            _dashboardWindow?.ApplyLanguage();
            _notificationWindow?.Close();
            RefreshTrayLocalization();
        }
    }

    public void ShowDashboard()
    {
        if (_dashboardWindow is null)
        {
            _dashboardWindow = new DashboardWindow { Owner = MainWindow };
            _dashboardWindow.Closed += (_, _) => _dashboardWindow = null;
        }
        _dashboardWindow.Show();
        _dashboardWindow.Activate();
    }

    public bool ShowQuotaNotification(string message, DateTimeOffset resetAt)
    {
        if (_windowsNotifications?.TryShow(message, resetAt) == true) return true;
        _notificationWindow?.Close();
        _notificationWindow = new QuotaNotificationWindow(
            message,
            ShowDashboard,
            () => (this.MainWindow as CodexGuardian.App.MainWindow)?.SilenceUntil(resetAt));
        _notificationWindow.Closed += (_, _) => _notificationWindow = null;
        _notificationWindow.Show();
        return false;
    }

    private Forms.ContextMenuStrip CreateTrayMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(Localization.Text("TrayShow"), null, (_, _) => ToggleMainWindowVisibility());
        menu.Items.Add(Localization.Text("TrayTimeline"), null, (_, _) => ShowDashboard());
        menu.Items.Add(Localization.Text("TraySettings"), null, (_, _) => ShowSettings());
        menu.Items.Add(Localization.Text("TrayExit"), null, (_, _) => RequestExit());
        menu.Opening += (_, _) =>
            menu.Items[0].Text = Localization.Text(MainWindow?.IsVisible == true ? "TrayHide" : "TrayShow");
        return menu;
    }

    private void RefreshTrayLocalization()
    {
        var previous = _trayMenu;
        _trayMenu = CreateTrayMenu();
        if (_trayIcon is not null)
        {
            _trayIcon.Text = Localization.Text("TrayTooltip");
            _trayIcon.ContextMenuStrip = _trayMenu;
        }
        previous?.Dispose();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Dispose();
        base.OnExit(e);
    }

    public void Dispose()
    {
        if (_trayIcon is not null)
        {
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
            _trayIcon = null;
        }
        _notificationWindow?.Close();
        _notificationWindow = null;
        _windowsNotifications?.Dispose();
        _windowsNotifications = null;
        _applicationIcon?.Dispose();
        _applicationIcon = null;
        _trayMenu?.Dispose();
        _trayMenu = null;
        _singleInstanceMutex?.Dispose();
        _singleInstanceMutex = null;
        GC.SuppressFinalize(this);
    }
}

