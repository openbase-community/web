import importlib.metadata

_package_apps_cache = None


def get_package_apps():
    """Retrieve all Django apps from registered app packages."""
    global _package_apps_cache

    if _package_apps_cache is not None:
        return _package_apps_cache

    apps = []
    entry_points = importlib.metadata.entry_points()

    for entry_point in entry_points.select(group="web.app_packages"):
        app_list_func = entry_point.load()
        if callable(app_list_func):
            apps.extend(app_list_func())

    _package_apps_cache = apps
    return apps
