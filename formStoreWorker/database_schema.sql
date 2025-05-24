-- Database schema for Unhinged Cards form submissions
-- This file contains the SQL commands to create the necessary tables and indexes

-- Create the form table to store card contributions
CREATE TABLE IF NOT EXISTS form (
    id INTEGER PRIMARY KEY,
    tipo_carta TEXT NOT NULL CHECK (tipo_carta IN ('negra', 'blanca', 'ambas')),
    carta_negra TEXT,
    carta_blanca TEXT,
    contexto TEXT,
    ip_address TEXT,
    user_agent TEXT,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_form_tipo_carta ON form(tipo_carta);
CREATE INDEX IF NOT EXISTS idx_form_submitted_at ON form(submitted_at);
CREATE INDEX IF NOT EXISTS idx_form_ip_address ON form(ip_address);

-- Create a view for easy querying of card contributions
CREATE VIEW IF NOT EXISTS card_contributions AS
SELECT 
    id,
    tipo_carta,
    carta_negra,
    carta_blanca,
    contexto,
    DATE(submitted_at) as submission_date,
    submitted_at
FROM form
ORDER BY submitted_at DESC;

-- Create a summary view for statistics
CREATE VIEW IF NOT EXISTS contribution_stats AS
SELECT 
    tipo_carta,
    COUNT(*) as total_contributions,
    COUNT(CASE WHEN carta_negra IS NOT NULL AND carta_negra != '' THEN 1 END) as black_cards_count,
    COUNT(CASE WHEN carta_blanca IS NOT NULL AND carta_blanca != '' THEN 1 END) as white_cards_count,
    DATE(MIN(submitted_at)) as first_submission,
    DATE(MAX(submitted_at)) as last_submission
FROM form 
GROUP BY tipo_carta;
