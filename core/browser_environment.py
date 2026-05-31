"""Browser launch environment helpers."""

import os
import sys


def has_graphical_display() -> bool:
    if sys.platform.startswith("win") or sys.platform == "darwin":
        return True
    return bool(os.getenv("DISPLAY") or os.getenv("WAYLAND_DISPLAY"))


def should_launch_headless(executor_type: str, requested_headless: bool = False) -> bool:
    if requested_headless or executor_type == "headless":
        return True
    return not has_graphical_display()
