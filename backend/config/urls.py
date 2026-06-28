"""Root URLconf — mounts the books API under /api/"""
from django.urls import include, path

urlpatterns = [
    path("api/", include("books.urls")),
]
