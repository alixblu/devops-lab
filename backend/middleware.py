"""Simple CORS middleware — no third-party package required."""


class SimpleCorsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        response["Access-Control-Allow-Origin"] = "*"
        response["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type"
        if request.method == "OPTIONS":
            response.status_code = 204
        return response


class NoCacheApiMiddleware:
    """Disable caching for API endpoints to prevent 304 responses."""
    
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        
        # Apply no-cache headers to API endpoints
        if request.path.startswith("/api/"):
            response["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response["Pragma"] = "no-cache"
            response["Expires"] = "0"
            # Remove ETag to prevent 304 responses
            response.pop("ETag", None)
        
        return response
