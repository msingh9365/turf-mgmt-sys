class StripAuthForOtpMiddleware:
    """Middleware to remove Authorization header for OTP endpoints.

    Some clients send an expired/invalid Authorization header on every request
    (global interceptor). DRF's JWT authentication raises on invalid tokens
    before view-level settings are considered, causing 401s on public OTP
    endpoints. This middleware transparently removes the header for OTP
    routes so those endpoints are treated as unauthenticated requests.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        try:
            path = request.path or ""
        except Exception:
            path = ""

        # Normalize OTP path prefix; update if your OTP URLs change
        if path.startswith("/api/otp/"):
            # Django stores the incoming Authorization value in HTTP_AUTHORIZATION
            if "HTTP_AUTHORIZATION" in request.META:
                request.META.pop("HTTP_AUTHORIZATION", None)

        return self.get_response(request)
