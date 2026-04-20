import "server-only";

import { getBrokerList } from "@/lib/data-broker-remover/aws-clients";
import type {
  AssistantClientContext,
  AssistantContextPayload,
} from "./types";

function sanitizeText(value?: string | null): string | null {
  if (!value) {
    return null;
  }

  return value.trim().slice(0, 500);
}

export function buildAssistantContext(
  input?: AssistantClientContext,
): AssistantContextPayload {
  const brokers = getBrokerList();

  return {
    currentStep: input?.currentStep,
    selectedBroker: sanitizeText(input?.selectedBroker),
    requestStatus: sanitizeText(input?.requestStatus),
    brokerReplyExcerpt: sanitizeText(input?.brokerReplyExcerpt),
    availableBrokerNames: brokers.map((broker) => broker.name).slice(0, 25),
    availableBrokerCount: brokers.length,
  };
}

export function formatAssistantContext(context: AssistantContextPayload): string {
  const sections = [
    `Current workflow step: ${context.currentStep || "unknown"}`,
    `Selected broker: ${context.selectedBroker || "none"}`,
    `Known request status: ${context.requestStatus || "unknown"}`,
    `Broker reply excerpt: ${context.brokerReplyExcerpt || "not provided"}`,
    `Configured brokers in app: ${context.availableBrokerCount}`,
    `Sample broker names: ${
      context.availableBrokerNames.length > 0
        ? context.availableBrokerNames.join(", ")
        : "none configured"
    }`,
  ];

  return sections.join("\n");
}
