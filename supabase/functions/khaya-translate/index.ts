import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const KHAYA_BASE_URL = "https://translation-api.ghananlp.org";
const KHAYA_TRANSLATION_ENDPOINT = "/translate";

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

    const { text, languagePair } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Text to translate is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!languagePair || typeof languagePair !== "string" || !languagePair.includes("-")) {
      return new Response(
        JSON.stringify({ error: "A valid languagePair (e.g. 'en-tw') is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const [sourceLang, targetLang] = languagePair.split("-");
    if (sourceLang === targetLang) {
      return new Response(
        JSON.stringify({ success: true, translation: text, languagePair, skipped: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const subscriptionKey = Deno.env.get("GHANA_NLP_SUBSCRIPTION_KEY");
    if (!subscriptionKey) {
      return new Response(
        JSON.stringify({ error: "GHANA_NLP_SUBSCRIPTION_KEY is not configured on the server." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const translateUrl = `${KHAYA_BASE_URL}${KHAYA_TRANSLATION_ENDPOINT}`;

    const response = await fetch(translateUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": subscriptionKey,
      },
      body: JSON.stringify({
        in: text.trim(),
        lang: languagePair.trim(),
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      return new Response(
        JSON.stringify({ error: `Khaya Translation v2 returned status ${response.status}`, details: errText }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const responseText = await response.text();
    let translation = responseText.trim();

    if (translation.startsWith("{") && translation.endsWith("}")) {
      try {
        const decoded = JSON.parse(translation);
        translation = decoded.translatedText || decoded.translation ||
                      decoded.out || decoded.result || decoded.text || translation;
        if (typeof translation !== "string") translation = responseText.trim();
      } catch (_) { /* ignore */ }
    }
    if (translation.startsWith('"') && translation.endsWith('"') && translation.length > 1) {
      translation = translation.substring(1, translation.length - 1).trim();
    }

    return new Response(
      JSON.stringify({
        success: true,
        translation: translation,
        languagePair: languagePair,
        apiVersion: "v2",
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
