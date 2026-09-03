import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUserClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseUserClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid user session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const uid = user.id;
    const body = await req.json().catch(() => ({}));
    const reportId = body.reportId;
    const confirm = Boolean(body.confirm);

    if (!reportId || typeof reportId !== "string" || reportId.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "A valid reportId string is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Fetch the outbreak report
    const { data: report, error: fetchError } = await supabaseAdminClient
      .from("outbreaks")
      .select("*")
      .eq("id", reportId.trim())
      .maybeSingle();

    if (fetchError || !report) {
      return new Response(
        JSON.stringify({ error: `Outbreak report '${reportId}' not found.` }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const rawVerified: string[] = Array.isArray(report.verified_by) ? report.verified_by : [];
    const rawRefuted: string[] = Array.isArray(report.refuted_by) ? report.refuted_by : [];

    const verifiedSet = new Set(rawVerified);
    const refutedSet = new Set(rawRefuted);

    // Check for duplicate voting (idempotency)
    if (confirm) {
      if (verifiedSet.has(uid) && !refutedSet.has(uid)) {
        return new Response(
          JSON.stringify({
            success: true,
            reportId: reportId.trim(),
            status: "noop",
            message: "User already verified this outbreak report.",
            verifiedCount: verifiedSet.size,
            refutedCount: refutedSet.size,
            confidenceScore: report.confidence || Math.max(1, 1 + verifiedSet.size - refutedSet.size),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      verifiedSet.add(uid);
      refutedSet.delete(uid);
    } else {
      if (refutedSet.has(uid) && !verifiedSet.has(uid)) {
        return new Response(
          JSON.stringify({
            success: true,
            reportId: reportId.trim(),
            status: "noop",
            message: "User already refuted this outbreak report.",
            verifiedCount: verifiedSet.size,
            refutedCount: refutedSet.size,
            confidenceScore: report.confidence || Math.max(1, 1 + verifiedSet.size - refutedSet.size),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      refutedSet.add(uid);
      verifiedSet.delete(uid);
    }

    const updatedVerifiedBy = Array.from(verifiedSet);
    const updatedRefutedBy = Array.from(refutedSet);
    const updatedConfidence = Math.max(1, 1 + updatedVerifiedBy.length - updatedRefutedBy.length);

    const { error: updateError } = await supabaseAdminClient
      .from("outbreaks")
      .update({
        verified_by: updatedVerifiedBy,
        refuted_by: updatedRefutedBy,
        confidence: updatedConfidence,
        updated_at: new Date().toISOString(),
      })
      .eq("id", reportId.trim());

    if (updateError) {
      return new Response(
        JSON.stringify({ error: `Failed to update outbreak: ${updateError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        reportId: reportId.trim(),
        status: "updated",
        verifiedCount: updatedVerifiedBy.length,
        refutedCount: updatedRefutedBy.length,
        confidenceScore: updatedConfidence,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
