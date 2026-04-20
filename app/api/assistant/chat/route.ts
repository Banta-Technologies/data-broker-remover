import { createHash, randomUUID } from "crypto";
import { NextRequest, NextResponse } from "next/server";
import { buildAssistantContext } from "@/lib/assistant/context";
import { getAssistantConfig } from "@/lib/assistant/config";
import { buildAssistantSystemPrompt } from "@/lib/assistant/prompt";
import {
  classifyAssistantRequest,
  getScopeRefusalMessage,
} from "@/lib/assistant/scope";
import { generateAssistantReply } from "@/lib/assistant/provider";
import type {
  AssistantChatRequest,
  AssistantChatResponse,
  AssistantScopeClassification,
} from "@/lib/assistant/types";

function auditLog(
  requestId: string,
  classification: AssistantScopeClassification,
  message: string,
  details: Record<string, string | number | boolean | null | undefined>,
) {
  const digest = createHash("sha256").update(message).digest("hex").slice(0, 16);
  console.info("assistant_request", {
    requestId,
    classification,
    messageDigest: digest,
    messageLength: message.length,
    ...details,
  });
}

export async function POST(request: NextRequest) {
  const requestId = randomUUID();
  const config = getAssistantConfig();

  if (!config.enabled) {
    return NextResponse.json(
      {
        reply:
          "The assistant is currently disabled for this deployment.",
        classification: "out_of_scope",
        requestId,
      } satisfies AssistantChatResponse,
      { status: 404 },
    );
  }

  let body: AssistantChatRequest;

  try {
    body = (await request.json()) as AssistantChatRequest;
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON request body.", requestId },
      { status: 400 },
    );
  }

  const message = body.message?.trim() || "";
  const classification = classifyAssistantRequest(message);
  const context = buildAssistantContext(body.context);

  auditLog(requestId, classification, message, {
    currentStep: context.currentStep,
    selectedBroker: context.selectedBroker,
    requestStatus: context.requestStatus,
    hasBrokerReplyExcerpt: Boolean(context.brokerReplyExcerpt),
    brokerCount: context.availableBrokerCount,
    model: config.model,
    hasApiKey: config.hasApiKey,
  });

  if (!message) {
    return NextResponse.json(
      { error: "Message is required.", requestId },
      { status: 400 },
    );
  }

  if (classification !== "in_scope") {
    return NextResponse.json({
      reply: getScopeRefusalMessage(classification),
      classification,
      requestId,
    } satisfies AssistantChatResponse);
  }

  if (!config.hasApiKey) {
    console.error("assistant_misconfigured", {
      requestId,
      reason: "OPENAI_API_KEY missing while assistant is enabled",
    });

    return NextResponse.json(
      {
        reply:
          "The assistant is enabled, but it is not configured completely yet. Please try again later.",
        classification,
        requestId,
      } satisfies AssistantChatResponse,
      { status: 503 },
    );
  }

  try {
    const systemPrompt = buildAssistantSystemPrompt(context);
    const reply = await generateAssistantReply({
      systemPrompt,
      userMessage: message,
    });

    return NextResponse.json({
      reply,
      classification,
      requestId,
    } satisfies AssistantChatResponse);
  } catch (error) {
    console.error("assistant_error", {
      requestId,
      error: error instanceof Error ? error.message : String(error),
    });

    return NextResponse.json(
      {
        reply:
          "The assistant could not answer right now. You can still continue the removal workflow normally.",
        classification,
        requestId,
      } satisfies AssistantChatResponse,
      { status: 502 },
    );
  }
}
