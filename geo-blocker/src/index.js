// ABOUTME: Cloudflare Worker for geo-blocking users in restricted regions
// ABOUTME: Uses Cloudflare's built-in geolocation to check if user is in Mississippi

/**
 * List of blocked US states (currently just Mississippi due to age verification laws)
 */
const BLOCKED_REGIONS = ['MS']; // Mississippi

/**
 * Main request handler
 */
export default {
  async fetch(request, env, ctx) {
    // Enable CORS for Flutter app
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Content-Type': 'application/json',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only allow GET requests
    if (request.method !== 'GET') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: corsHeaders }
      );
    }

    try {
      // Extract geolocation data from Cloudflare's request object
      const country = request.cf?.country || 'UNKNOWN';
      const region = request.cf?.region || 'UNKNOWN'; // US state code (e.g., "MS", "CA")
      const city = request.cf?.city || 'UNKNOWN';

      // Check if user is in a blocked region
      const isBlocked = country === 'US' && BLOCKED_REGIONS.includes(region);

      // Return geolocation check result
      const response = {
        blocked: isBlocked,
        country: country,
        region: region,
        city: city,
        reason: isBlocked ? 'Age verification laws in your state prevent access to this service' : null,
      };

      // Use HTTP 451 (Unavailable For Legal Reasons) if blocked
      const statusCode = isBlocked ? 451 : 200;

      return new Response(
        JSON.stringify(response, null, 2),
        {
          status: statusCode,
          headers: corsHeaders
        }
      );
    } catch (error) {
      // If geolocation fails, allow access (fail open)
      return new Response(
        JSON.stringify({
          blocked: false,
          error: 'Geolocation unavailable',
          message: 'Access granted due to technical issue'
        }),
        {
          status: 200,
          headers: corsHeaders
        }
      );
    }
  },
};
