#!/bin/bash

# Test the check-stale-devices edge function locally

echo "🧪 Testing check-stale-devices function locally..."
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install it first:"
    echo "   brew install supabase/tap/supabase"
    echo "   OR"
    echo "   npm install -g supabase"
    exit 1
fi

echo "Starting local Supabase functions server..."
echo "(Press Ctrl+C to stop after testing)"
echo ""

# Serve the function locally
supabase functions serve check-stale-devices --env-file .env.local --no-verify-jwt
