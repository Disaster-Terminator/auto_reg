from core.browser_environment import should_launch_headless


def test_windows_without_x_display_keeps_headed_mode(monkeypatch):
    monkeypatch.setattr("sys.platform", "win32")
    monkeypatch.delenv("DISPLAY", raising=False)
    monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)

    assert should_launch_headless("headed") is False


def test_linux_without_display_forces_headless(monkeypatch):
    monkeypatch.setattr("sys.platform", "linux")
    monkeypatch.delenv("DISPLAY", raising=False)
    monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)

    assert should_launch_headless("headed") is True


def test_explicit_headless_stays_headless_on_desktop(monkeypatch):
    monkeypatch.setattr("sys.platform", "win32")
    monkeypatch.delenv("DISPLAY", raising=False)
    monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)

    assert should_launch_headless("headless") is True
