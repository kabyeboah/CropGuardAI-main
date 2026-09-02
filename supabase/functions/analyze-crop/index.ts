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

    const { imageBase64, cropType, initialTopCandidates } = await req.json();

    if (!imageBase64 || typeof imageBase64 !== "string") {
      return new Response(
        JSON.stringify({ error: "Valid imageBase64 data is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY is not configured on the server." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const candidateInfo = Array.isArray(initialTopCandidates) && initialTopCandidates.length > 0
      ? `On-device preliminary model candidates: ${initialTopCandidates.join(", ")}.`
      : "";
    const cropContext = cropType ? `Crop Type: ${cropType}.` : "";

    const promptText = `You are an expert plant pathologist and agricultural scientist specializing in West African & global crop diseases (e.g., Cocoa, Cassava, Maize, Rice, Tomato, Plantain).
Analyze this crop leaf/plant image carefully and return a JSON object with the following schema:

{
  "label": "Name of the crop disease or Healthy state (e.g. Cocoa Black Pod Disease, Cassava Mosaic Disease, Healthy Maize)",
  "confidence": 0.88,
  "isHealthy": false,
  "symptoms": ["Dark water-soaked lesions", "Fungal mycelium growth"],
  "rootCause": "Phytophthora palmivora pathogen infection accelerated by high humidity.",
  "organicRemedies": ["Apply copper-based fungicide spray", "Prune affected lower canopy leaves"],
  "preventionTips": ["Ensure adequate shade management", "Improve field drainage"],
  "sourceBasis": "Authoritative agricultural basis (e.g., CABI Plantwise / MoFA PPRSD / CRIG / IITA Guidelines)",
  "safetyPrecautions": "Wear PPE (gloves, mask, eye protection) when applying treatments. Follow Pre-Harvest Intervals (PHI).",
  "rawReasoning": "Detailed visual analysis of lesions, leaf chlorosis, and texture."
}

Context:
${cropContext}
${candidateInfo}
Return strictly valid JSON only.`;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${apiKey}`;

    const payload = {
      contents: [
        {
          parts: [
            { text: promptText },
            {
              inline_data: {
                mime_type: "image/jpeg",
                data: imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: "application/json",
        temperature: 0.2,
      },
    };

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errText = await response.text();
      return new Response(
        JSON.stringify({ error: `Gemini API returned status ${response.status}`, details: errText }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const resJson = await response.json();
    const candidateText = resJson?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!candidateText) {
      return new Response(
        JSON.stringify({ error: "Empty response received from Gemini Cloud AI." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const cleanJson = candidateText.replace(/^```json\s*|\s*```$/g, "").trim();
    const resultObj = JSON.parse(cleanJson);

    return new Response(
      JSON.stringify({ success: true, result: resultObj }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
