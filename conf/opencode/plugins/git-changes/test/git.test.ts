import { afterEach, describe, expect, mock, spyOn, test } from "bun:test"
import { watchGitChanges, type GitSnapshot } from "../git"

const spies: Array<{ mockRestore: () => void }> = []
afterEach(() => {
	for (const spy of spies.splice(0)) spy.mockRestore()
	mock.restore()
})

function harness(options: {
	session?: any
	sessionID?: string
	status?: (input: any) => unknown | Promise<unknown>
	loadSession?: () => any
} = {}) {
	const events = new Map<string, Array<() => void>>()
	const sync = mock(async (_location: unknown) => {})
	const status = mock(options.status ?? (async () => ({ location: {}, data: [] })))
	const cachedGet = mock(() => options.session)
	const remoteGet = mock(options.loadSession ?? (() => options.session))
	const ctx = {
		data: {
			session: { get: cachedGet },
			location: { vcs: { sync } },
			on: (event: string, callback: () => void) => {
				const callbacks = events.get(event) ?? []
				callbacks.push(callback)
				events.set(event, callbacks)
				return () => events.set(event, callbacks.filter((item) => item !== callback))
			},
		},
		client: { session: { get: remoteGet }, vcs: { status } },
	}
	const intervals: Array<{ callback: () => void; delay: number | undefined }> = []
	const timeouts: Array<() => void> = []
	const setIntervalSpy = spyOn(globalThis, "setInterval").mockImplementation(((callback: TimerHandler, delay?: number) => {
		intervals.push({ callback: callback as () => void, delay })
		return 1 as any
	}) as typeof setInterval)
	const clearIntervalSpy = spyOn(globalThis, "clearInterval").mockImplementation(() => {})
	const setTimeoutSpy = spyOn(globalThis, "setTimeout").mockImplementation(((callback: TimerHandler) => {
		timeouts.push(callback as () => void)
		return timeouts.length as any
	}) as typeof setTimeout)
	const clearTimeoutSpy = spyOn(globalThis, "clearTimeout").mockImplementation(() => {})
	spies.push(setIntervalSpy, clearIntervalSpy, setTimeoutSpy, clearTimeoutSpy)
	const snapshots: GitSnapshot[] = []
	const stop = watchGitChanges(ctx, options.sessionID ?? "session-1", (snapshot) => snapshots.push(snapshot))
	return { ctx, events, intervals, timeouts, snapshots, stop, sync, status, cachedGet, remoteGet, clearIntervalSpy, clearTimeoutSpy }
}

async function settle() {
	for (let i = 0; i < 8; i++) await Promise.resolve()
}

describe("watchGitChanges", () => {
	test("uses the session location and official status shape, including all change statuses", async () => {
		const location = { directory: "/repo/a" }
		const h = harness({
			session: { id: "session-1", location },
			status: async (input) => ({ location: input.location, data: [
				{ file: "new", additions: 3, deletions: 0, status: "added" },
				{ file: "edit", additions: 2, deletions: 1, status: "modified" },
				{ file: "gone", additions: 0, deletions: 4, status: "deleted" },
			] }),
		})
		expect(h.snapshots[0]?.state).toBe("loading")
		await settle()
		expect(h.sync).toHaveBeenCalledWith(location)
		expect(h.status).toHaveBeenCalledWith({ location })
		expect(h.snapshots.at(-1)).toMatchObject({ state: "ready", directory: "/repo/a", additions: 5, deletions: 5 })
		expect(h.snapshots.at(-1)?.files).toHaveLength(3)
		h.stop()
	})

	test("different sessions in the same repo share location/results; another repo follows its location", async () => {
		const location = { directory: "/repo/shared" }
		const data = [{ file: "edit", additions: 2, deletions: 1, status: "modified" }]
		const h = harness({ sessionID: "A", session: { location }, status: async ({ location }) => ({ location, data }) })
		await settle()
		expect(h.snapshots.at(-1)?.directory).toBe("/repo/shared")
		const a2 = harness({ sessionID: "A2", session: { location }, status: async ({ location }) => ({ location, data }) })
		await settle()
		expect(a2.status).toHaveBeenCalledWith({ location })
		expect(a2.snapshots.at(-1)).toMatchObject({ state: "ready", files: data, additions: 2, deletions: 1 })
		h.stop()
		a2.stop()
		const other = harness({ session: { location: { directory: "/repo/other" } }, status: async ({ location }) => ({ location, data: [] }) })
		await settle()
		expect(other.status).toHaveBeenCalledWith({ location: { directory: "/repo/other" } })
		expect(other.snapshots.at(-1)?.directory).toBe("/repo/other")
		other.stop()
	})

	test("clean workspaces are ready with no files", async () => {
		const h = harness({ session: { location: { directory: "/repo/clean" } } })
		await settle()
		expect(h.snapshots.at(-1)).toMatchObject({ state: "ready", files: [], additions: 0, deletions: 0 })
		h.stop()
	})

	test("malformed responses and thrown service errors are explicit errors, not clean results", async () => {
		const h = harness({ session: { location: { directory: "/repo" } }, status: async () => ({ data: [{ file: "bad", additions: "0", deletions: 0, status: "modified" }] }) })
		await settle()
		expect(h.snapshots.at(-1)?.state).toBe("error")
		expect(h.snapshots.at(-1)?.error).toContain("Invalid VCS status")
		h.stop()
		const failure = harness({ session: { location: { directory: "/repo" } }, status: async () => { throw new Error("service unavailable") } })
		await settle()
		expect(failure.snapshots.at(-1)).toMatchObject({ state: "error", error: "service unavailable" })
		expect(failure.snapshots.at(-1)?.state).not.toBe("ready")
		failure.stop()
	})

	test("filesystem events debounce a refresh", async () => {
		const h = harness({ session: { location: { directory: "/repo" } } })
		await settle()
		const changed = h.events.get("filesystem.changed")![0]!
		changed()
		changed()
		expect(h.status).toHaveBeenCalledTimes(1)
		expect(h.timeouts).toHaveLength(2)
		expect(h.clearTimeoutSpy).toHaveBeenCalledTimes(1)
		h.timeouts.at(-1)!()
		await settle()
		expect(h.status).toHaveBeenCalledTimes(2)
		h.stop()
		expect(h.events.get("filesystem.changed")).toHaveLength(0)
		expect(h.events.get("session.execution.succeeded")).toHaveLength(0)
	})

	test("10-second polling publishes changed and clean results; cleanup disables the callback", async () => {
		let data: any[] = [{ file: "edit", additions: 2, deletions: 0, status: "modified" }]
		const h = harness({ session: { location: { directory: "/repo" } }, status: async ({ location }) => ({ location, data }) })
		await settle()
		expect(h.intervals[0]?.delay).toBe(10_000)
		expect(h.snapshots.at(-1)?.files).toEqual(data)
		data = []
		h.intervals[0]!.callback()
		await settle()
		expect(h.snapshots.at(-1)).toMatchObject({ state: "ready", files: [], additions: 0, deletions: 0 })
		h.stop()
		const calls = h.status.mock.calls.length
		h.intervals[0]!.callback()
		await settle()
		expect(h.status).toHaveBeenCalledTimes(calls)
	})

	test("overlapping poll and event requests coalesce to one non-concurrent refresh", async () => {
		let resolveFirst!: (value: unknown) => void
		let active = 0
		let maximumActive = 0
		let calls = 0
		const h = harness({ session: { location: { directory: "/repo" } }, status: () => {
			calls++
			active++
			maximumActive = Math.max(maximumActive, active)
			if (calls === 1) return new Promise((resolve) => { resolveFirst = (value) => { active--; resolve(value) } })
			active--
			return { location: {}, data: [] }
		} })
		h.intervals[0]!.callback()
		h.intervals[0]!.callback()
		h.events.get("filesystem.changed")![0]!()
		h.timeouts.at(-1)!()
		await settle()
		expect(h.status).toHaveBeenCalledTimes(1)
		resolveFirst({ location: {}, data: [] })
		await settle()
		expect(h.status).toHaveBeenCalledTimes(2)
		expect(maximumActive).toBe(1)
		h.stop()

		let resolvePending!: (value: unknown) => void
		const pending = harness({ session: { location: { directory: "/repo" } }, status: () => new Promise((resolve) => { resolvePending = resolve }) })
		await settle()
		pending.intervals[0]!.callback()
		pending.stop()
		resolvePending({ location: {}, data: [] })
		await settle()
		expect(pending.status).toHaveBeenCalledTimes(1)
		expect(pending.snapshots).toHaveLength(1)
	})

	test("cache misses use the official session lookup and cleanup blocks late results", async () => {
		let resolveStatus!: (value: unknown) => void
		const h = harness({ session: undefined, loadSession: () => ({ location: { directory: "/remote/repo" } }), status: () => new Promise((resolve) => { resolveStatus = resolve }) })
		await settle()
		expect(h.remoteGet).toHaveBeenCalledWith({ sessionID: "session-1" })
		h.stop()
		resolveStatus({ location: {}, data: [] })
		await settle()
		expect(h.snapshots).toHaveLength(1)
		expect(h.snapshots[0]?.state).toBe("loading")
		expect(h.clearIntervalSpy).toHaveBeenCalled()
	})
})
