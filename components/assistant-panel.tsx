"use client";

import { FormEvent, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type {
  AssistantChatResponse,
  AssistantClientContext,
} from "@/lib/assistant/types";

interface AssistantPanelProps {
  enabled: boolean;
  context?: AssistantClientContext;
}

interface ChatLine {
  role: "user" | "assistant";
  text: string;
}

export function AssistantPanel({
  enabled,
  context,
}: AssistantPanelProps) {
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [messages, setMessages] = useState<ChatLine[]>([]);

  const placeholder = useMemo(() => {
    if (context?.currentStep === "email") {
      return "Ask about email verification or what happens next.";
    }

    if (context?.currentStep === "verify") {
      return "Ask about verification, statuses, or the next step.";
    }

    if (context?.currentStep === "details") {
      return "Ask what details are needed for removal requests.";
    }

    if (context?.currentStep === "review") {
      return "Ask about request sending, broker emails, or next actions.";
    }

    return "Ask about brokers, statuses, replies, or the next step in this app.";
  }, [context?.currentStep]);

  if (!enabled) {
    return null;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const trimmed = message.trim();
    if (!trimmed) {
      return;
    }

    setIsLoading(true);
    setError("");
    setMessages((current) => [...current, { role: "user", text: trimmed }]);
    setMessage("");

    try {
      const response = await fetch("/api/assistant/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: trimmed,
          context,
        }),
      });

      const payload = (await response.json()) as
        | AssistantChatResponse
        | { error?: string };

      if (!response.ok && "error" in payload && payload.error) {
        throw new Error(payload.error);
      }

      if (!("reply" in payload)) {
        throw new Error("The assistant returned an unexpected response.");
      }

      setMessages((current) => [
        ...current,
        { role: "assistant", text: payload.reply },
      ]);
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : "The assistant is unavailable right now.",
      );
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <section className="w-full max-w-2xl mx-auto">
      <Card className="bg-plum-900 border-plum-700 p-6 space-y-4">
        <div className="space-y-2">
          <h2 className="text-xl font-semibold text-warmgray">
            Privacy Removal Assistant
          </h2>
          <p className="text-sm text-warmgray/80">
            This assistant only helps with brokers, workflow statuses, replies,
            removal steps, and next actions inside this app.
          </p>
        </div>

        <div className="space-y-3">
          {messages.length === 0 && (
            <p className="text-sm text-warmgray/70">
              It will refuse unrelated questions and will only answer when the
              request is grounded in this app’s workflow.
            </p>
          )}

          {messages.map((entry, index) => (
            <div
              key={`${entry.role}-${index}`}
              className={
                entry.role === "user"
                  ? "rounded-md border border-plum-600 bg-plum-800/70 p-3 text-sm text-warmgray"
                  : "rounded-md border border-gold/30 bg-[#3a3654] p-3 text-sm text-warmgray/90"
              }
            >
              <p className="mb-1 text-xs uppercase tracking-wide text-warmgray/60">
                {entry.role === "user" ? "You" : "Assistant"}
              </p>
              <p>{entry.text}</p>
            </div>
          ))}
        </div>

        <form className="space-y-3" onSubmit={handleSubmit}>
          <Input
            value={message}
            onChange={(event) => setMessage(event.target.value)}
            placeholder={placeholder}
            disabled={isLoading}
          />
          {error && <p className="text-sm text-red-400">{error}</p>}
          <Button type="submit" disabled={isLoading}>
            {isLoading ? "Thinking..." : "Ask assistant"}
          </Button>
        </form>
      </Card>
    </section>
  );
}
