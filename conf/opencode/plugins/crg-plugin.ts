import type { Plugin } from "@opencode-ai/plugin"

/**
 * code-review-graph plugin for OpenCode.
 *
 * Keeps the knowledge graph up-to-date and surfaces status
 * information automatically during coding sessions.
 *
 * Installed by: code-review-graph install --platform opencode
 */

const plugin: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      try {
        if (event.type === "file.edited") {
          await $`code-review-graph update --skip-flows`.quiet()
        }

        if (event.type === "session.created") {
          const result = await $`code-review-graph status`.quiet()
          const output = result.stdout?.toString().trim()
          if (output) {
            console.log("[code-review-graph]", output)
          }
        }
      } catch {
        // Swallow — graph commands must never block OpenCode.
      }
    },

    "tool.execute.before": async (input, output) => {
      try {
        if (input.tool !== "bash") return

        const command = output.args.command
        if (typeof command === "string" && /^git\s+commit/i.test(command)) {
          const result = await $`code-review-graph detect-changes --brief`.quiet()
          const analysis = result.stdout?.toString().trim()
          if (analysis) {
            console.log("[code-review-graph] Pre-commit analysis:\n" + analysis)
          }
        }
      } catch {
        // Swallow — never block a commit.
      }
    },
  }
}

export default plugin
