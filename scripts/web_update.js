/* Keep the entry page and its content-addressed Godot files on one release. */
(() => {
	const build = '__GAME_BUILD__';
	let checking = null;

	async function checkRelease() {
		if (checking) return checking;
		checking = (async () => {
			const controller = new AbortController();
			const timeout = setTimeout(() => controller.abort(), 3000);
			try {
				const manifest = new URL('version.json', window.location.href);
				// Bypass both the browser cache and a CDN's cached manifest.
				manifest.searchParams.set('_check', Date.now().toString());
				const response = await fetch(manifest, {
					cache: 'no-store', signal: controller.signal,
				});
				if (!response.ok) return true;
				const latest = await response.json();
				if (!/^[a-f0-9]{16}$/.test(latest.build) || latest.build === build) return true;
				const next = new URL(window.location.href);
				// A versioned navigation also bypasses a stale entry HTML response.
				// Do not loop if a CDN briefly returns mixed releases during rollout.
				if (next.searchParams.get('build') === latest.build) return true;
				next.searchParams.set('build', latest.build);
				window.location.replace(next.href);
				return false;
			} catch (_) {
				// A failed version check must not prevent a working build starting.
				return true;
			} finally {
				clearTimeout(timeout);
			}
		})();
		try {
			return await checking;
		} finally {
			checking = null;
		}
	}

	window.ensureCurrentGameBuild = checkRelease;
	window.addEventListener('pageshow', (event) => {
		if (event.persisted) void checkRelease();
	});
	document.addEventListener('visibilitychange', () => {
		if (!document.hidden) void checkRelease();
	});
})();
