import type { AssistantScopeClassification } from "./types";

const IN_SCOPE_KEYWORDS = [
  "broker",
  "brokers",
  "remove",
  "removal",
  "opt out",
  "opt-out",
  "verification",
  "verify",
  "status",
  "reply",
  "replies",
  "request",
  "requests",
  "dashboard",
  "result",
  "results",
  "workflow",
  "step",
  "next step",
  "next action",
  "what next",
  "email template",
  "company email",
  "data broker",
  "privacy removal",
];

const ADJACENT_KEYWORDS = [
  "privacy",
  "personal information",
  "data rights",
  "gdpr",
  "ccpa",
];

const UNSAFE_KEYWORDS = [
  "ignore previous instructions",
  "system prompt",
  "reveal secrets",
  "api key",
  "aws credentials",
  "password",
  "medical advice",
  "diagnose",
  "politics",
  "vote",
  "stock tip",
  "investment advice",
  "write malware",
  "exploit",
];

const OUT_OF_SCOPE_KEYWORDS = [
  "weather",
  "sports",
  "recipe",
  "travel",
  "movie",
  "code review",
  "debug my app",
  "javascript help",
  "terraform help",
  "news",
];

export function classifyAssistantRequest(
  input: string,
): AssistantScopeClassification {
  const normalized = input.trim().toLowerCase();

  if (!normalized) {
    return "adjacent";
  }

  if (UNSAFE_KEYWORDS.some((keyword) => normalized.includes(keyword))) {
    return "unsafe";
  }

  if (IN_SCOPE_KEYWORDS.some((keyword) => normalized.includes(keyword))) {
    return "in_scope";
  }

  if (ADJACENT_KEYWORDS.some((keyword) => normalized.includes(keyword))) {
    return "adjacent";
  }

  if (OUT_OF_SCOPE_KEYWORDS.some((keyword) => normalized.includes(keyword))) {
    return "out_of_scope";
  }

  return "out_of_scope";
}

export function getScopeRefusalMessage(
  classification: Exclude<AssistantScopeClassification, "in_scope">,
): string {
  if (classification === "unsafe") {
    return "I can only help with in-app privacy removal workflow questions, and I can’t help with that request.";
  }

  if (classification === "adjacent") {
    return "I can help with the brokers, workflow steps, statuses, replies, and next actions inside this privacy-removal app. Try asking about a broker, a request status, or what to do next in the current step.";
  }

  return "I’m limited to this app’s privacy-removal workflow. Ask about broker records, removal steps, statuses, broker replies, or the next action inside the app.";
}
