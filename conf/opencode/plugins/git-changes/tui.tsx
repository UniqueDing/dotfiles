import { Plugin } from "@opencode/plugin/tui"
import { createEffect, createSignal, For, onCleanup, Show } from "solid-js"
import { watchGitChanges, type GitSnapshot } from "./git"

const empty: GitSnapshot = {
  state: "loading",
  files: [],
  additions: 0,
  deletions: 0,
}

const GitChangesPlugin = Plugin.define({
  id: "local.git-changes",
  setup(ctx) {
    return ctx.ui.slot({
    after: "sidebar.content",
    render(input) {
      const [snapshot, setSnapshot] = createSignal<GitSnapshot>(empty)
      const [collapsed, setCollapsed] = createSignal(false)

      // Keep the session read inside the reactive effect; destructuring the
      // render input here would freeze the initial session id.
      let activeSession: string | undefined
      let stop: (() => void) | undefined
      const syncSession = () => {
        const sessionID = input.sessionID
        if (sessionID === activeSession) return
        stop?.()
        activeSession = sessionID
        setSnapshot(empty)
        if (!sessionID) return
        stop = watchGitChanges(ctx, sessionID, setSnapshot)
      }

      createEffect(syncSession)
      // Slot render is re-run by the host when its input changes. This cleanup
      // also prevents an old monitor surviving slot teardown.
      onCleanup(() => stop?.())

      return (
        <Show when={snapshot().state !== "ready" || snapshot().files.length > 0}>
        <ShowChanges
          snapshot={snapshot()}
          collapsed={collapsed()}
          toggle={() => setCollapsed((value) => !value)}
          openDiff={() => ctx.ui.panel.open("diff")}
          theme={ctx.theme.text}
        />
        </Show>
      )
    },
    })
  },
})

export default GitChangesPlugin

function ShowChanges(props: {
  snapshot: GitSnapshot
  collapsed: boolean
  toggle: () => void
  openDiff: () => void
  theme: any
}) {
  const state = () => props.snapshot
  const rows = () => state().files.slice(0, 8)
  const hidden = () => Math.max(0, state().files.length - rows().length)

  return (
    <box flexDirection="column" paddingLeft={1} paddingRight={1}>
      <box flexDirection="row" gap={1} onMouseDown={props.toggle}>
        <text fg={state().state === "error" ? props.theme.feedback.error.base : props.theme.base}>
          {props.collapsed ? "▶" : "▼"}
        </text>
        <text fg={state().state === "error" ? props.theme.feedback.error.base : props.theme.base}>
          <b>Git Changes ({state().state === "ready" ? state().files.length : "…"})</b>
        </text>
        <box flexGrow={1} />
        <Show when={state().state === "ready"}>
          <text fg={props.theme.feedback.success.base}>+{state().additions}</text>
          <text fg={props.theme.feedback.error.base}>−{state().deletions}</text>
        </Show>
      </box>
      {!props.collapsed && (
        <Show when={state().state === "error"}>
          <text fg={props.theme.feedback.error.base}>Unable to read Git changes</text>
        </Show>
      )}
      {!props.collapsed && state().state === "ready" && (
        <>
          <For each={rows()}>
            {(file) => (
              <box flexDirection="row" gap={1} onMouseDown={props.openDiff}>
                <text fg={props.theme.muted} wrapMode="none" flexGrow={1} flexShrink={1} minWidth={0}>
                  {file.file}
                </text>
                <text fg={props.theme.feedback.success.base} flexShrink={0}>+{file.additions}</text>
                <text fg={props.theme.feedback.error.base} flexShrink={0}>−{file.deletions}</text>
              </box>
            )}
          </For>
          <Show when={hidden() > 0}>
            <text fg={props.theme.muted}>… and {hidden()} more</text>
          </Show>
        </>
      )}
    </box>
  )
}
