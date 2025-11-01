"""Core project package for playground backend.

Prefer native mysqlclient if installed. If not available, and PyMySQL is
installed, register it as MySQLdb so Django's MySQL backend can operate
without compiling native extensions. This is helpful for local dev/CI.
"""
# Ensure the app is imported when Django starts, so shared_task can be used.
# **ASSUME you previously initialized firebase_config here or elsewhere**
from . import firebase_config # Assuming this is where you initialized Firebase
from .celery import app as celery_app 

__all__ = ('celery_app',)

try:  # pragma: no cover - environment-dependent
    import MySQLdb  # type: ignore  # noqa: F401
except Exception:
    try:
        import pymysql

        pymysql.install_as_MySQLdb()
    except Exception:
        # Neither mysqlclient nor PyMySQL available; Django will raise only
        # when a MySQL connection is attempted.
        pass
