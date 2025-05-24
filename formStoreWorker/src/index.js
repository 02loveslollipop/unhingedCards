/**
 * Unhinged Cards Form Worker - JavaScript Version
 * Handles form submissions for card contributions and stores them in D1 database
 */

// Validation function for form data
function validateFormData(data) {
	const errors = [];
	
	// Required field validation
	if (!data.tipo_carta) {
		errors.push("tipo_carta is required");
	} else if (!['negra', 'blanca', 'ambas'].includes(data.tipo_carta)) {
		errors.push("tipo_carta must be 'negra', 'blanca', or 'ambas'");
	}
	
	// Content validation based on tipo_carta
	if (data.tipo_carta === 'negra' && !data.carta_negra) {
		errors.push("carta_negra is required when tipo_carta is 'negra'");
	}
	
	if (data.tipo_carta === 'blanca' && !data.carta_blanca) {
		errors.push("carta_blanca is required when tipo_carta is 'blanca'");
	}
	
	if (data.tipo_carta === 'ambas') {
		if (!data.carta_negra && !data.carta_blanca) {
			errors.push("At least one of carta_negra or carta_blanca is required when tipo_carta is 'ambas'");
		}
	}
	
	// Length validations
	if (data.carta_negra && data.carta_negra.length > 500) {
		errors.push("carta_negra must be 500 characters or less");
	}
	
	if (data.carta_blanca && data.carta_blanca.length > 200) {
		errors.push("carta_blanca must be 200 characters or less");
	}
	
	if (data.contexto && data.contexto.length > 1000) {
		errors.push("contexto must be 1000 characters or less");
	}
	
	return errors;
}

// Handle form submission
async function handleFormSubmission(request, env) {
	try {
		// Parse form data
		let formData;
		const contentType = request.headers.get('content-type') || '';
		
		if (contentType.includes('application/json')) {
			formData = await request.json();
		} else if (contentType.includes('application/x-www-form-urlencoded')) {
			// Handle form-encoded data
			const body = await request.text();
			formData = {};
			const pairs = body.split('&');
			for (const pair of pairs) {
				if (pair.includes('=')) {
					const [key, value] = pair.split('=', 2);
					formData[decodeURIComponent(key)] = decodeURIComponent(value.replace(/\+/g, ' '));
				}
			}
		} else {
			return createErrorResponse("Unsupported content type", 400);
		}
		
		// Validate form data
		const validationErrors = validateFormData(formData);
		if (validationErrors.length > 0) {
			return createErrorResponse(validationErrors, 400, "validation");
		}
		
		// Get client information
		const ipAddress = request.headers.get('CF-Connecting-IP') || 
						 request.headers.get('X-Forwarded-For') || 
						 'unknown';
		const userAgent = request.headers.get('User-Agent') || 'unknown';
		
		// Insert into database
		const query = `
			INSERT INTO form (tipo_carta, carta_negra, carta_blanca, contexto, ip_address, user_agent)
			VALUES (?, ?, ?, ?, ?, ?)
		`;
		
		const stmt = env.DB.prepare(query).bind(
			formData.tipo_carta,
			formData.carta_negra || null,
			formData.carta_blanca || null,
			formData.contexto || null,
			ipAddress,
			userAgent
		);
		
		const result = await stmt.run();
		
		return createSuccessResponse({
			success: true,
			message: "¡Gracias parcero! Tu contribución ha sido recibida.",
			id: result.meta.last_row_id || null
		});
		
	} catch (error) {
		console.error('Error in handleFormSubmission:', error);
		return createErrorResponse(`Internal server error: ${error.message}`, 500);
	}
}

// Handle CORS preflight requests
function handleOptions() {
	return new Response(null, {
		status: 200,
		headers: getCorsHeaders()
	});
}

// Create success response with CORS headers
function createSuccessResponse(data) {
	return new Response(JSON.stringify(data), {
		status: 200,
		headers: {
			'Content-Type': 'application/json',
			...getCorsHeaders()
		}
	});
}

// Create error response with CORS headers
function createErrorResponse(error, status = 500, type = "error") {
	const errorData = {
		success: false
	};
	
	if (type === "validation") {
		errorData.errors = Array.isArray(error) ? error : [error];
	} else {
		errorData.error = typeof error === 'string' ? error : error.message || 'Unknown error';
	}
	
	return new Response(JSON.stringify(errorData), {
		status: status,
		headers: {
			'Content-Type': 'application/json',
			...getCorsHeaders()
		}
	});
}

// Get CORS headers
function getCorsHeaders() {
	return {
		'Access-Control-Allow-Origin': '*',
		'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type',
		'Access-Control-Max-Age': '86400'
	};
}

// Main fetch handler
export default {
	async fetch(request, env, ctx) {
		try {
			const url = new URL(request.url);
			
			// Handle CORS preflight
			if (request.method === 'OPTIONS') {
				return handleOptions();
			}
			
			// Handle form submissions
			if (request.method === 'POST') {
				return await handleFormSubmission(request, env);
			}
			
			// Handle GET requests (health check)
			if (request.method === 'GET') {
				return createSuccessResponse({
					service: "Unhinged Cards Form Worker",
					status: "healthy",
					timestamp: new Date().toISOString(),
					endpoints: {
						"POST /": "Submit form data",
						"GET /": "Health check",
						"OPTIONS /": "CORS preflight"
					}
				});
			}
			
			// Method not allowed
			return createErrorResponse("Method not allowed", 405);
			
		} catch (error) {
			console.error('Error in main fetch handler:', error);
			return createErrorResponse(`Unexpected error: ${error.message}`, 500);
		}
	}
};
