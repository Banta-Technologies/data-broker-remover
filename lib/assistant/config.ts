import "server-only";

export interface AssistantConfig {
  enabled: boolean;
  model: string;
  scopeMode: string;
  hasApiKey: boolean;
}

function envFlag(value: string | undefined): boolean {
  return value === "true";
}

export function getAssistantConfig(): AssistantConfig {
  return {
    enabled: envFlag(process.env.ENABLE_AI_ASSISTANT),
    model: process.env.OPENAI_MODEL || "gpt-5.4",
    scopeMode: process.env.ASSISTANT_SCOPE_MODE || "strict",
    hasApiKey: Boolean(process.env.OPENAI_API_KEY),
  };
}
