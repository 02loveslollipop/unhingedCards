# Unhinged Cards Form Worker

A Cloudflare Worker written in Python to handle form submissions for the Unhinged Cards project, storing card contributions in a D1 database.

## Features

- ✅ Form validation with business rules
- ✅ D1 database integration for data persistence
- ✅ CORS support for frontend integration
- ✅ Input sanitization and length limits
- ✅ IP address and user agent tracking
- ✅ Comprehensive error handling

## Database Schema

The worker uses a D1 database with the following table structure:

```sql
CREATE TABLE form (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_carta TEXT NOT NULL CHECK (tipo_carta IN ('negra', 'blanca', 'ambas')),
    carta_negra TEXT,
    carta_blanca TEXT,
    contexto TEXT,
    ip_address TEXT,
    user_agent TEXT,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Setup Instructions

### 1. Database Setup

First, create your D1 database and apply the schema:

```bash
# Create the database (if not already created)
npx wrangler d1 create unhinged-cards-db

# Apply the schema
npx wrangler d1 execute unhinged-cards-db --file=database_schema.sql
```

### 2. Update Configuration

1. Update the `database_id` in `wrangler.jsonc` with your actual D1 database ID
2. Update the worker URL in the HTML form (`YOUR_WORKER_URL_HERE`)

### 3. Deploy the Worker

```bash
# Deploy to Cloudflare
npx wrangler deploy

# Or deploy with a custom name
npx wrangler deploy --name unhinged-cards-form-worker
```

## API Endpoints

### POST /
Submit a new card contribution.

**Request Body:**
```json
{
    "tipo_carta": "negra|blanca|ambas",
    "carta_negra": "Optional black card text",
    "carta_blanca": "Optional white card text", 
    "contexto": "Optional context explanation"
}
```

**Response:**
```json
{
    "success": true,
    "message": "¡Gracias parcero! Tu contribución ha sido recibida.",
    "id": 123
}
```

### GET /
Health check endpoint.

**Response:**
```json
{
    "service": "Unhinged Cards Form Worker",
    "status": "healthy",
    "endpoints": {
        "POST /": "Submit form data"
    }
}
```

### OPTIONS /
CORS preflight support.

## Validation Rules

- `tipo_carta` is required and must be one of: 'negra', 'blanca', 'ambas'
- If `tipo_carta` is 'negra', `carta_negra` is required
- If `tipo_carta` is 'blanca', `carta_blanca` is required  
- If `tipo_carta` is 'ambas', at least one of `carta_negra` or `carta_blanca` is required
- `carta_negra` max length: 500 characters
- `carta_blanca` max length: 200 characters
- `contexto` max length: 1000 characters

## Database Queries

### View all contributions
```sql
SELECT * FROM card_contributions ORDER BY submitted_at DESC;
```

### Get statistics
```sql
SELECT * FROM contribution_stats;
```

### Count submissions by type
```sql
SELECT tipo_carta, COUNT(*) as count 
FROM form 
GROUP BY tipo_carta;
```

### Recent submissions (last 24 hours)
```sql
SELECT * FROM form 
WHERE submitted_at >= datetime('now', '-1 day') 
ORDER BY submitted_at DESC;
```

## Development

### Local Testing
```bash
# Install dependencies
pip install -r requirements.txt

# Run locally (if supported)
npx wrangler dev
```

### View Logs
```bash
npx wrangler tail
```

## Security Considerations

- Input validation and sanitization
- Rate limiting (consider implementing)
- IP tracking for spam prevention
- CORS properly configured
- No sensitive data stored in logs

## License

This project follows the same Creative Commons BY-NC-SA 2.0 License as the original Cards Against Humanity game.
