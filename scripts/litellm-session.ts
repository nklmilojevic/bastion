import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PROVIDER = "litellm";
const MODEL_PREFIX = "claude/";

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_request", (event, ctx) => {
    if (ctx.model?.provider !== PROVIDER) return undefined;
    if (!ctx.model.id.startsWith(MODEL_PREFIX)) return undefined;
    const sessionId = ctx.sessionManager.getSessionId();
    if (!sessionId) return undefined;
    const payload = event.payload as Record<string, unknown>;
    return { ...payload, user: JSON.stringify({ session_id: sessionId }) };
  });
}
