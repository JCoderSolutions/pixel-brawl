// Habilita cross-origin isolation en hosts donde no se pueden configurar headers
// (GitHub Pages). El build Web de Godot 4.2 usa hilos y necesita SharedArrayBuffer,
// que el navegador solo expone con COOP/COEP. Este archivo corre en dos modos:
// como service worker agrega esos headers a cada respuesta; como <script> en la
// página registra el worker y recarga una vez para que tome el control.
if (typeof window === "undefined") {
	self.addEventListener("install", () => self.skipWaiting());
	self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));
	self.addEventListener("fetch", (event) => {
		const request = event.request;
		if (request.cache === "only-if-cached" && request.mode !== "same-origin") {
			return;
		}
		event.respondWith(fetch(request).then((response) => {
			if (response.status === 0) {
				return response;
			}
			const headers = new Headers(response.headers);
			headers.set("Cross-Origin-Embedder-Policy", "require-corp");
			headers.set("Cross-Origin-Opener-Policy", "same-origin");
			headers.set("Cross-Origin-Resource-Policy", "cross-origin");
			return new Response(response.body, {
				status: response.status,
				statusText: response.statusText,
				headers: headers,
			});
		}));
	});
} else if (!window.crossOriginIsolated && window.isSecureContext && "serviceWorker" in navigator) {
	const RELOAD_KEY = "coi-reloaded";
	navigator.serviceWorker.register(document.currentScript.src).then(() => navigator.serviceWorker.ready).then(() => {
		// Recargar una sola vez: si tras recargar sigue sin aislamiento, no entrar en loop.
		if (!sessionStorage.getItem(RELOAD_KEY)) {
			sessionStorage.setItem(RELOAD_KEY, "1");
			window.location.reload();
		}
	}).catch((error) => console.error("coi-serviceworker:", error));
} else if (window.crossOriginIsolated) {
	sessionStorage.removeItem("coi-reloaded");
}
