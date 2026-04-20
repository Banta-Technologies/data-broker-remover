export type AssistantScopeClassification =
  | "in_scope"
  | "adjacent"
  | "out_of_scope"
  | "unsafe";

export type AssistantWorkflowStep = "email" | "verify" | "details" | "review";

export interface AssistantClientContext {
  currentStep?: AssistantWorkflowStep;
  selectedBroker?: string | null;
  requestStatus?: string | null;
  brokerReplyExcerpt?: string | null;
}

export interface AssistantContextPayload {
  currentStep?: AssistantWorkflowStep;
  selectedBroker?: string | null;
  requestStatus?: string | null;
  brokerReplyExcerpt?: string | null;
  availableBrokerNames: string[];
  availableBrokerCount: number;
}

export interface AssistantChatRequest {
  message: string;
  context?: AssistantClientContext;
}

export interface AssistantChatResponse {
  reply: string;
  classification: AssistantScopeClassification;
  requestId: string;
}
