from django.utils.deprecation import MiddlewareMixin

class ForceJSONCharsetMiddleware(MiddlewareMixin):
    """Middleware to ensure JSON responses include charset=utf-8 in Content-Type."""
    def process_response(self, request, response):
        content_type = response.get('Content-Type', '')
        if content_type.startswith('application/json') and 'charset' not in content_type.lower():
            response['Content-Type'] = f"{content_type}; charset=utf-8"
        return response
