"""
Minimal Django settings — no database needed.
"""
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = "django-insecure-dev-only-change-me"
DEBUG = True
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "books",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "middleware.SimpleCorsMiddleware",   # must come before CommonMiddleware
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "config.urls"
TEMPLATES = []
WSGI_APPLICATION = "config.wsgi.application"
DATABASES = {}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
