import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const KHAYA_BASE_URL = "https://translation-api.ghananlp.org";
const KHAYA_ASR_VERSION = "v3";

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

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid user session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { audioBase64, language = "tw" } = await req.json();

    if (!audioBase64 || typeof audioBase64 !== "string") {
      return new Response(
        JSON.stringify({ error: "audioBase64 is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const subscriptionKey = Deno.env.get("GHANA_NLP_SUBSCRIPTION_KEY");
    if (!subscriptionKey) {
      return new Response(
        JSON.stringify({ error: "GHANA_NLP_SUBSCRIPTION_KEY is not configured on the server." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const asrUrl = `${KHAYA_BASE_URL}/asr/${KHAYA_ASR_VERSION}/transcribe?language=${language}`;

    // Decode base64 to binary Uint8Array
    const binaryString = atob(audioBase64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    const response = await fetch(asrUrl, {
      method: "POST",
      headers: {
        "Content-Type": "audio/wav",
        "Ocp-Apim-Subscription-Key": subscriptionKey,
      },
      body: bytes,
    });

    if (!response.ok) {
      const errText = await response.text();
      return new Response(
        JSON.stringify({ error: `Khaya ASR v3 returned status ${response.status}`, details: errText }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const responseText = await response.text();
    let text = responseText.trim();

    if (text.startsWith("{") && text.endsWith("}")) {
      try {
        const decoded = JSON.parse(text);
        if (decoded && typeof decoded.text === "string") {
          text = decoded.text.trim();
        }
      } catch (_) { /* ignore */ }
    }
    if (text.startsWith('"') && text.endsWith('"') && text.length > 1) {
      text = text.substring(1, text.length - 1).trim();
    }

    return new Response(
      JSON.stringify({
        success: true,
        transcription: text,
        language: language,
        apiVersion: KHAYA_ASR_VERSION,
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
