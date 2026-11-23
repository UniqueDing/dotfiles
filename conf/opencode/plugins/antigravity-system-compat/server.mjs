const supportedModels = new Set([
  'claude-opus-5-5-high',
  'claude-sonnet-5-5-high',
  'gemini-4-carbon-high',
  'gemini-4-neon-xhigh',
  'gemini-4-hydrogen-xhigh',
]);

export async function transformContext(event) {
  if (event?.model?.providerID !== 'gemini' || !supportedModels.has(event.model.id)) return;
  if (!Array.isArray(event.system)) return;

  for (const block of event.system) {
    if (block?.type === 'text' && typeof block.text === 'string') {
      block.text = block.text.replaceAll('tools.opencode.session_move', 'tools["opencode"].session_move');
    }
  }
}

export default {
  id: 'local.antigravity-system-compat',
  async setup(ctx) {
    const context = await ctx.session.hook('context', transformContext);
    let compaction;
    try {
      compaction = await ctx.session.hook('compaction', transformContext);
    } catch (error) {
      await context.dispose();
      throw error;
    }
    return async () => {
      try { await compaction.dispose(); } finally { await context.dispose(); }
    };
  },
};
