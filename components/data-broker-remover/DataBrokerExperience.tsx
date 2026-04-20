"use client";

import { useState } from "react";
import { AssistantPanel } from "@/components/assistant-panel";
import { DataBrokerWizard } from "./DataBrokerWizard";
import type { WizardStep } from "@/lib/data-broker-remover/types";

interface DataBrokerExperienceProps {
  assistantEnabled: boolean;
}

export function DataBrokerExperience({
  assistantEnabled,
}: DataBrokerExperienceProps) {
  const [step, setStep] = useState<WizardStep>("email");

  return (
    <div className="space-y-8">
      <DataBrokerWizard onStepChange={setStep} />
      <AssistantPanel enabled={assistantEnabled} context={{ currentStep: step }} />
    </div>
  );
}
