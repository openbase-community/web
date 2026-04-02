from __future__ import annotations

import importlib.metadata

_installed_apps_cache = None


def get_installed_apps():
    """Retrieve Django installed apps from registered entry points."""
    global _installed_apps_cache

    if _installed_apps_cache is not None:
        return _installed_apps_cache

    apps = []
    entry_points = importlib.metadata.entry_points()

    for entry_point in entry_points.select(group="api_core.installed_apps"):
        app_list_func = entry_point.load()
        if callable(app_list_func):
            apps.extend(app_list_func())

    _installed_apps_cache = apps
    return apps


def merge_settings_from_module(mod, target_globals):
    names = getattr(mod, "__all__", None) or dir(mod)
    for name in names:
        # copy only public, UPPERCASE names (typical Django convention)
        if not name.startswith("_") and name.isupper():
            target_globals[name] = getattr(mod, name)


def load_all_package_settings(target_globals):
    """Load settings from registered settings entry points."""
    entry_points = importlib.metadata.entry_points()
    for entry_point in entry_points.select(group="api_core.settings"):
        mod = entry_point.load()
        merge_settings_from_module(mod, target_globals)
