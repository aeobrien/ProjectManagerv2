# 6. Adversarial Review

**Entry point:** AdversarialReviewView — accessible from the Project Detail view.

**This is the most architecturally different AI flow.** It bypasses ContextAssembler, PromptTemplates, and the behavioural contract entirely.

**Flow:**
1. **Export (no AI):** Package project documents as JSON for sending to external reviewers
2. **External review (manual):** User copies JSON, sends to external AI models (Claude, GPT-4, etc.), gets critiques back
3. **Import (no AI):** User pastes critique JSON, decoded into structured critique objects
4. **Synthesis (AI):** A custom prompt is built containing original documents + all critiques. The AI identifies overlapping concerns, recommends which to address, and produces revised documents.
5. **Follow-up (AI):** Multi-turn conversation continuing the synthesis
6. **Approval:** User approves revised documents, which are saved back

**What's different:** Direct `LLMClient.send()` calls with no system prompt, no behavioural contract, no ContextAssembler, no action blocks. The synthesis prompt is entirely self-contained. This is intentional — the adversarial review is meant to be a separate, more critical perspective, not filtered through the supportive assistant persona.
