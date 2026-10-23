import { isAbsolute, relative as relativePath } from "node:path"

export type GitSnapshot = {
	state: "loading" | "ready" | "error"
	directory?: string
	repository?: { branch?: string; worktree: string; relativeWorktree?: string }
	files: Array<{
		file: string
		additions: number
		deletions: number
		status: "added" | "modified" | "deleted"
	}>
	additions: number
	deletions: number
	error?: string
}

const POLL_INTERVAL = 10_000
const EVENT_DEBOUNCE = 150

type FileChange = GitSnapshot["files"][number]

function isFileChange(value: unknown): value is FileChange {
	if (!value || typeof value !== "object") return false
	const file = value as Record<string, unknown>
	return (
		typeof file.file === "string" &&
		Number.isSafeInteger(file.additions) && (file.additions as number) >= 0 &&
		Number.isSafeInteger(file.deletions) && (file.deletions as number) >= 0 &&
		(file.status === "added" || file.status === "modified" || file.status === "deleted")
	)
}

function errorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error)
}

export function watchGitChanges(
	ctx: any,
	sessionID: string,
	notify: (state: GitSnapshot) => void,
): () => void {
	let active = true
	let running = false
	let rerunRequested = false
	let debounceTimer: ReturnType<typeof setTimeout> | undefined
	let last: GitSnapshot = { state: "loading", files: [], additions: 0, deletions: 0 }

	const publish = (snapshot: GitSnapshot) => {
		if (!active) return
		last = snapshot
		notify(snapshot)
	}

	const read = async (): Promise<GitSnapshot> => {
		let session = ctx.data.session.get(sessionID)
		if (!session) session = await ctx.client.session.get({ sessionID })
		const directory = session?.location?.directory
		if (typeof directory !== "string" || directory.length === 0) {
			throw new Error("Session has no workspace location")
		}

		await ctx.data.location.vcs.sync(session.location)
		const vcsInfo = ctx.data.location.vcs.info(session.location)
		let repository: GitSnapshot["repository"]
		if (vcsInfo?.provider === "git") {
			const locationInfo = await ctx.client.location.get({ location: session.location })
			const worktree = locationInfo?.project?.directory
			if (typeof worktree === "string" && worktree.length > 0) {
				repository = { worktree }
				const canonical = locationInfo?.project?.canonical
				if (
					typeof canonical === "string" &&
					canonical.length > 0 &&
					!canonical.includes("\0") &&
					!worktree.includes("\0") &&
					isAbsolute(canonical) &&
					isAbsolute(worktree)
				) {
					repository.relativeWorktree = relativePath(canonical, worktree) || "."
				}
				if (typeof vcsInfo.branch?.current === "string" && vcsInfo.branch.current.length > 0) {
					repository.branch = vcsInfo.branch.current
				}
			}
		}
		const response = await ctx.client.vcs.status({ location: session.location })
		if (!response || !Array.isArray(response.data) || !response.data.every(isFileChange)) {
			throw new Error("Invalid VCS status response")
		}
		const files = response.data.map((file: FileChange) => ({ ...file }))
		return {
			state: "ready",
			directory,
			...(repository ? { repository } : {}),
			files,
			additions: files.reduce((total, file) => total + file.additions, 0),
			deletions: files.reduce((total, file) => total + file.deletions, 0),
		}
	}

	const refresh = async () => {
		if (!active) return
		if (running) {
			rerunRequested = true
			return
		}
		running = true
		try {
			do {
				rerunRequested = false
				try {
					publish(await read())
				} catch (error) {
					publish({
						state: "error",
						directory: last.directory,
						repository: last.repository,
						files: last.files,
						additions: last.additions,
						deletions: last.deletions,
						error: errorMessage(error),
					})
				}
			} while (active && rerunRequested)
		} finally {
			running = false
		}
	}

	const scheduleRefresh = () => {
		if (!active) return
		if (debounceTimer !== undefined) clearTimeout(debounceTimer)
		debounceTimer = setTimeout(() => {
			debounceTimer = undefined
			void refresh()
		}, EVENT_DEBOUNCE)
	}

	const unsubscribe: Array<() => void> = []
	for (const event of ["filesystem.changed", "session.execution.succeeded"]) {
		const off = ctx.data.on(event, scheduleRefresh)
		if (typeof off === "function") unsubscribe.push(off)
	}
	const interval = setInterval(() => void refresh(), POLL_INTERVAL)
	notify(last)
	void refresh()

	return () => {
		if (!active) return
		active = false
		clearInterval(interval)
		if (debounceTimer !== undefined) clearTimeout(debounceTimer)
		for (const off of unsubscribe) off()
	}
}
