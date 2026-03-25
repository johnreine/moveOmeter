/**
 * Supabase Edge Function: Check Stale Devices
 *
 * This function periodically checks for devices that haven't sent data recently
 * and updates their connection status (online -> stale -> offline)
 *
 * Should be called every 30-60 seconds via cron job
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role key (bypasses RLS)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Call the check_stale_devices() database function
    const { data, error } = await supabase.rpc('check_stale_devices')

    if (error) {
      console.error('Error checking stale devices:', error)
      return new Response(
        JSON.stringify({
          success: false,
          error: error.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Log the results
    const changedDevices = data || []
    console.log(`Checked stale devices: ${changedDevices.length} status changes`)

    if (changedDevices.length > 0) {
      changedDevices.forEach((device: any) => {
        console.log(`  ${device.device_id}: ${device.old_status} → ${device.new_status}`)
      })
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        timestamp: new Date().toISOString(),
        changes: changedDevices.length,
        devices: changedDevices
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
