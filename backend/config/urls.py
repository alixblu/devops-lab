"""Root URLconf — mounts the books API under /api/"""
from django.urls import include, path
from django.http import JsonResponse

def health_check(request):
    return JsonResponse({"status": "UP"})

urlpatterns = [
    path("api/", include("books.urls")),
    path("health/", health_check),

]
