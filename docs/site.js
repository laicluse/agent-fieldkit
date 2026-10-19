(function () {
	"use strict";

	const state = {
		data: null,
		query: "",
		support: "all",
		category: "all",
	};

	const supportFilters = [
		{ id: "all", label: "All" },
		{ id: "both", label: "Claude + Codex" },
		{ id: "claude", label: "Claude only" },
	];

	const typeClass = {
		Breaking: "breaking",
		Added: "added",
		Changed: "changed",
		Fixed: "fixed",
	};

	function $(selector) {
		return document.querySelector(selector);
	}

	function escapeHtml(value) {
		return String(value || "")
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function plural(count, word) {
		return `${count} ${word}${count === 1 ? "" : "s"}`;
	}

	function siteHref(path) {
		return `/${String(path || "").replace(/^\/+/, "")}`;
	}

	function appHref(app) {
		return app.pagePath ? siteHref(app.pagePath) : app.homepageUrl;
	}

	function supportLabel(plugin) {
		return plugin.codex ? "Claude + Codex" : "Claude only";
	}

	function supportMode(plugin) {
		return plugin.codex ? "both" : "claude";
	}

	function categoryLabel(id) {
		const category = state.data.categories.find((item) => item.id === id);
		return category ? category.label : id;
	}

	function renderHero(data) {
		$("#hero-stats").innerHTML = `
			<div class="stat-row">
				<strong>${data.counts.sourcePackages}</strong>
				<span>packages</span>
			</div>
			<div class="stat-row">
				<strong>${data.counts.codexPackages}</strong>
				<span>Claude Code + Codex packages</span>
			</div>
			<div class="stat-row muted">
				<strong>${data.counts.claudeOnlyPackages}</strong>
				<span>Claude Code-only package</span>
			</div>
			<div class="stat-row">
				<strong>${data.counts.skillEntries}</strong>
				<span>skill entries indexed</span>
			</div>
		`;

		const latest = data.changelog[0];
		$("#hero-change").innerHTML = latest
			? `
				<span class="mini-label">Latest package note</span>
				<strong>${escapeHtml(latest.plugin)} ${escapeHtml(latest.packageVersion)}</strong>
				<p>${escapeHtml(latest.summary)}</p>
			`
			: "";
	}

	function renderSummaries(data) {
		$("#catalog-summary").innerHTML = `
			<span>${plural(data.counts.sourcePackages, "package")}</span>
			<span>${plural(data.counts.codexPackages, "Claude + Codex package")}</span>
			<span>${plural(data.counts.changelogEntries, "changelog note")}</span>
		`;
	}

	function renderFilterButtons(container, filters, active, onSelect) {
		container.innerHTML = filters
			.map(
				(filter) => `
					<button type="button" data-filter="${escapeHtml(filter.id)}" aria-pressed="${filter.id === active}">
						${escapeHtml(filter.label)}
					</button>
				`,
			)
			.join("");
		container.querySelectorAll("button").forEach((button) => {
			button.addEventListener("click", () => {
				onSelect(button.dataset.filter);
			});
		});
	}

	function syncFilterButtons() {
		document.querySelectorAll("#support-filters button").forEach((button) => {
			button.setAttribute("aria-pressed", String(button.dataset.filter === state.support));
		});
		document.querySelectorAll("#category-filters button").forEach((button) => {
			button.setAttribute("aria-pressed", String(button.dataset.filter === state.category));
		});
	}

	function renderControls(data) {
		renderFilterButtons($("#support-filters"), supportFilters, state.support, (filter) => {
			state.support = filter;
			syncFilterButtons();
			renderCatalog();
		});

		renderFilterButtons(
			$("#category-filters"),
			[{ id: "all", label: "All categories" }, ...data.categories],
			state.category,
			(filter) => {
				state.category = filter;
				syncFilterButtons();
				renderCatalog();
			},
		);

		$("#catalog-search").addEventListener("input", (event) => {
			state.query = event.target.value.toLowerCase().trim();
			renderCatalog();
		});
	}

	function pluginMatches(plugin) {
		if (state.support !== "all" && supportMode(plugin) !== state.support) return false;
		if (state.category !== "all" && plugin.category !== state.category) return false;
		if (!state.query) return true;
		const haystack = [
			plugin.name,
			plugin.summary,
			categoryLabel(plugin.category),
			supportLabel(plugin),
			plugin.latestChange && plugin.latestChange.summary,
		]
			.filter(Boolean)
			.join(" ")
			.toLowerCase();
		return haystack.includes(state.query);
	}

	function renderCatalog() {
		const grid = $("#plugin-grid");
		const plugins = state.data.plugins.filter(pluginMatches);
		$("#empty-state").hidden = plugins.length > 0;
		grid.innerHTML = plugins.map(renderPluginCard).join("");
	}

	function renderPluginCard(plugin) {
		const change = plugin.latestChange;
		const type = change ? change.type : "Changed";
		const badgeClass = typeClass[type] || "changed";
		const featureBits = [
			plural(plugin.skillCount, "skill"),
			plugin.commandCount ? plural(plugin.commandCount, "command") : null,
			plugin.hookFileCount ? "hooks" : null,
		].filter(Boolean);

		return `
			<article class="plugin-card">
				<header class="plugin-head">
					<div>
						<p class="plugin-category">${escapeHtml(categoryLabel(plugin.category))}</p>
						<h3><a href="${escapeHtml(siteHref(plugin.detailPath))}">${escapeHtml(plugin.name)}</a></h3>
					</div>
					<span class="version-pill">${escapeHtml(plugin.version)}</span>
				</header>
				<p class="plugin-summary">${escapeHtml(plugin.summary)}</p>
				<div class="plugin-meta" aria-label="Package metadata">
					<span class="support-pill ${supportMode(plugin)}">${escapeHtml(supportLabel(plugin))}</span>
					${featureBits.map((bit) => `<span>${escapeHtml(bit)}</span>`).join("")}
				</div>
				${
					change
						? `
							<div class="latest-note">
								<span class="change-type ${badgeClass}">${escapeHtml(type)}</span>
								<p>${escapeHtml(change.summary)}</p>
							</div>
						`
						: ""
				}
				<div class="plugin-actions">
					<a class="source-link" href="${escapeHtml(siteHref(plugin.detailPath))}">Details</a>
					<a class="source-link" href="${escapeHtml(plugin.sourceUrl)}">Package source</a>
				</div>
			</article>
		`;
	}

	function renderInstall(data) {
		const installSwitch = $("#install-switch");
		installSwitch.innerHTML = window.AgentCommandSwitch.render({
			id: "marketplace-install",
			label: "Marketplace install commands",
			commands: data.install,
		});
		window.AgentCommandSwitch.hydrate(installSwitch);
	}

	function renderChangelog(data) {
		$("#change-feed").innerHTML = data.changelog
			.map((change) => {
				const badgeClass = typeClass[change.type] || "changed";
				return `
					<article class="change-item">
						<div class="change-head">
							<div>
								<p><a class="change-plugin-link" href="${escapeHtml(siteHref(change.detailPath))}">${escapeHtml(change.plugin)}</a></p>
								<h3>${escapeHtml(change.packageVersion)}</h3>
							</div>
							<span class="change-type ${badgeClass}">${escapeHtml(change.type)}</span>
						</div>
						<p>${escapeHtml(change.summary)}</p>
						<a href="${escapeHtml(change.sourceUrl)}">Full changelog</a>
					</article>
				`;
			})
			.join("");
	}

	function renderApps(data) {
		const container = $("#app-breakout");
		if (!container) return;
		const apps = data.apps || [];
		container.innerHTML = apps
			.map(
				(app) => `
					<article class="app-card">
						<div class="app-card-body">
							<p class="app-category">${escapeHtml(app.category)}</p>
							<h3>${escapeHtml(app.name)}</h3>
							<p class="app-tagline">${escapeHtml(app.tagline)}</p>
							<ul class="app-features">
								${app.features.map((feature) => `<li>${escapeHtml(feature)}</li>`).join("")}
							</ul>
							<p class="app-requirement">${escapeHtml(app.requirement)}</p>
						</div>
						<div class="app-card-actions">
							<div class="app-install">
								<div class="block-heading">
									<span class="mini-label">Install</span>
								</div>
								<pre data-copyable><code>${escapeHtml(app.brew)}</code></pre>
							</div>
							<div class="app-buttons">
								<a class="button primary" href="${escapeHtml(appHref(app))}">Vocalist page</a>
								<a class="button secondary" href="${escapeHtml(app.repoUrl)}">Source</a>
							</div>
						</div>
					</article>
				`,
			)
			.join("");
	}

	function renderError(error) {
		$("#hero-stats").innerHTML = "<p>Catalog data could not be loaded.</p>";
		$("#plugin-grid").innerHTML = `
			<p class="error-state">
				${escapeHtml(error.message || "Unable to load docs/site-data.json.")}
			</p>
		`;
	}

	const dataUrl =
		document.currentScript && document.currentScript.src
			? new URL("site-data.json", document.currentScript.src)
			: "site-data.json";

	fetch(dataUrl)
		.then((response) => {
			if (!response.ok) throw new Error(`HTTP ${response.status}`);
			return response.json();
		})
		.then((data) => {
			state.data = data;
			renderHero(data);
			renderSummaries(data);
			renderControls(data);
			renderCatalog();
			renderApps(data);
			renderInstall(data);
			renderChangelog(data);
		})
		.catch(renderError);
})();
