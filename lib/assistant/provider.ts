import "server-only";

import { getAssistantConfig } from "./config";

interface ProviderInput {
  systemPrompt: string;
  userMessage: string;
}

function extractOutputText(payload: any): string {
  if (typeof payload?.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text.trim();
  }

  const textParts =
    payload?.output
      ?.flatMap((item: any) => item?.content || [])
      ?.filter((item: any) => item?.type === "output_text")
      ?.map((item: any) => item?.text)
      ?.filter(Boolean) || [];

  return textParts.join("\n").trim();
}

export async function generateAssistantReply({
  systemPrompt,
  userMessage,
}: ProviderInput): Promise<string> {
  const config = getAssistantConfig();

  if (!config.enabled) {
    throw new Error("AI assistant is disabled.");
  }

  if (!process.env.OPENAI_API_KEY) {
    throw new Error("AI assistant is enabled but OPENAI_API_KEY is not configured.");
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: config.model,
      store: false,
      reasoning: { effort: "low" },
      instructions: systemPrompt,
      input: userMessage,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `OpenAI request failed with status ${response.status}: ${errorText.slice(0, 400)}`,
    );
  }

  const payload = await response.json();
  const outputText = extractOutputText(payload);

  if (!outputText) {
    throw new Error("OpenAI response did not contain output text.");
  }

  return outputText;
}
