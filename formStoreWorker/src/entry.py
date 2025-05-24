from js import Response
import json
import traceback
from urllib.parse import unquote_plus

def validate_form_data(data):
    """Validate form data according to business rules"""
    errors = []
    
    # Required field validation
    if not data.get('tipo_carta'):
        errors.append("tipo_carta is required")
    elif data['tipo_carta'] not in ['negra', 'blanca', 'ambas']:
        errors.append("tipo_carta must be 'negra', 'blanca', or 'ambas'")
    
    # Content validation based on tipo_carta
    if data.get('tipo_carta') == 'negra' and not data.get('carta_negra'):
        errors.append("carta_negra is required when tipo_carta is 'negra'")
    
    if data.get('tipo_carta') == 'blanca' and not data.get('carta_blanca'):
        errors.append("carta_blanca is required when tipo_carta is 'blanca'")
    
    if data.get('tipo_carta') == 'ambas':
        if not data.get('carta_negra') and not data.get('carta_blanca'):
            errors.append("At least one of carta_negra or carta_blanca is required when tipo_carta is 'ambas'")
    
    # Length validations
    if data.get('carta_negra') and len(data['carta_negra']) > 500:
        errors.append("carta_negra must be 500 characters or less")
    
    if data.get('carta_blanca') and len(data['carta_blanca']) > 200:
        errors.append("carta_blanca must be 200 characters or less")
    
    if data.get('contexto') and len(data['contexto']) > 1000:
        errors.append("contexto must be 1000 characters or less")
    
    return errors

async def handle_form_submission(request, env):
    """Handle form submission and store in D1 database"""
    try:
        # Parse form data
        content_type = request.headers.get('content-type', '')
        if 'application/json' in content_type:
            form_data = await request.json()
        else:
            # Handle form-encoded data
            body = await request.text()
            form_data = {}
            if body:
                for pair in body.split('&'):
                    if '=' in pair:
                        key, value = pair.split('=', 1)
                        # URL decode
                        key = unquote_plus(key)
                        value = unquote_plus(value)
                        form_data[key] = value
        
        # Validate form data
        validation_errors = validate_form_data(form_data)
        if validation_errors:
            return Response.new(
                json.dumps({
                    "success": False,
                    "errors": validation_errors
                }),
                {
                    "status": 400,
                    "headers": {"Content-Type": "application/json"}
                }
            )
        
        # Get client information
        ip_address = request.headers.get('CF-Connecting-IP') or request.headers.get('X-Forwarded-For') or 'unknown'
        user_agent = request.headers.get('User-Agent') or 'unknown'
        
        # Insert into database
        query = """
            INSERT INTO form (tipo_carta, carta_negra, carta_blanca, contexto, ip_address, user_agent)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        result = await env.DB.prepare(query).bind(
            form_data.get('tipo_carta'),
            form_data.get('carta_negra') or None,
            form_data.get('carta_blanca') or None,
            form_data.get('contexto') or None,
            ip_address,
            user_agent
        ).run()
        
        return Response.new(
            json.dumps({
                "success": True,
                "message": "¡Gracias parcero! Tu contribución ha sido recibida.",
                "id": result.meta.last_row_id if hasattr(result, 'meta') and hasattr(result.meta, 'last_row_id') else None
            }),
            {
                "status": 200,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type"
                }
            }
        )
        
    except Exception as e:
        return Response.new(
            json.dumps({
                "success": False,
                "error": "Internal server error",
                "details": str(e)
            }),
            {
                "status": 500,
                "headers": {"Content-Type": "application/json"}
            }
        )

def handle_options():
    """Handle CORS preflight requests"""
    return Response.new(
        "",
        {
            "status": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Max-Age": "86400"
            }
        }
    )

async def on_fetch(request, env):async def on_fetch(request, env):
    try:
        # Handle CORS preflight
        if request.method == "OPTIONS":
            return handle_options()
        
        # Handle form submissions
        if request.method == "POST":
            return await handle_form_submission(request, env)
        
        # Handle GET requests (health check or info)
        if request.method == "GET":
            return Response.new(
                json.dumps({
                    "service": "Unhinged Cards Form Worker",
                    "status": "healthy",
                    "endpoints": {
                        "POST /": "Submit form data"
                    }
                }),
                {
                    "status": 200,
                    "headers": {"Content-Type": "application/json"}
                }
            )
        
        # Method not allowed
        return Response.new(
            json.dumps({"error": "Method not allowed"}),
            {
                "status": 405,
                "headers": {"Content-Type": "application/json"}
            }
        )
        
    except Exception as e:
        return Response.new(
            json.dumps({
                "success": False,
                "error_type": "python",
                "error": str(e),
                "traceback": traceback.format_exc()
            }),
            {
                "status": 500,
                "headers": {"Content-Type": "application/json"}
            }
        )