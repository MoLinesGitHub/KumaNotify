const STATUS_ONLY_CSS = `
<style id="status-public-lockdown">
button,
a[href="/manage-status-page"],
a[href^="/dashboard"] {
    display: none !important;
}

a[data-status-locked="true"] {
    pointer-events: none !important;
    cursor: default !important;
    text-decoration: none !important;
    color: inherit !important;
}
</style>`;

const STATUS_ONLY_JS = `
<script id="status-public-lockdown-script">
(() => {
    const ALLOWED_HOST = "www.molinesdesigns.com";
    const NAME_MAP = {
        "EXT - Kuma": "Kuma",
        "EXT - DNS molinesdesigns.com": "DNS molinesdesigns.com",
        "EXT - Web": "Web molinesdesigns.com",
        "EXT - Landing Cortes": "Landing Cortes",
        "EXT - Landing Anstop": "Landing Anstop",
        "EXT - Landing Dashboard Admin": "Dashboard Admin",
        "EXT - Health Backend API": "API Backend",
        "EXT - JWKS Endpoint": "Claves JWKS",
        "INT - Health Backend API": "API Backend Interna",
        "INT - Health: PostgreSQL Check": "PostgreSQL",
        "INT - Health: Redis Check": "Redis",
        "INT - JWKS Endpoint": "Claves JWKS Internas"
    };

    function isAllowedLink(anchor) {
        const href = anchor.getAttribute("href");
        if (!href) {
            return false;
        }

        try {
            const url = new URL(href, window.location.origin);
            return url.hostname === ALLOWED_HOST;
        } catch {
            return false;
        }
    }

    function renameMonitorLabels() {
        const selectors = [
            ".item-name",
            ".monitor-list p",
            ".monitor-list .info span:last-child",
            "p",
        ];

        selectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((node) => {
                const text = (node.textContent || "").trim();
                const mapped = NAME_MAP[text];
                if (mapped) {
                    node.textContent = mapped;
                }
            });
        });
    }

    function lockPage() {
        document.querySelectorAll("button").forEach((button) => {
            button.remove();
        });

        document.querySelectorAll("a").forEach((anchor) => {
            if (isAllowedLink(anchor)) {
                return;
            }

            anchor.dataset.statusLocked = "true";
            anchor.removeAttribute("href");
            anchor.removeAttribute("target");
            anchor.removeAttribute("rel");
            anchor.setAttribute("aria-disabled", "true");
            anchor.addEventListener("click", (event) => {
                event.preventDefault();
                event.stopPropagation();
            });
        });

        renameMonitorLabels();
    }

    document.addEventListener("DOMContentLoaded", lockPage);
    new MutationObserver(lockPage).observe(document.documentElement, {
        childList: true,
        subtree: true
    });
})();
</script>`;

export default {
    async fetch(request) {
        const url = new URL(request.url);

        if (url.pathname.startsWith("/dashboard") || url.pathname.startsWith("/manage-status-page")) {
            return Response.redirect(`https://kuma.molinesdesigns.com${url.pathname}${url.search}`, 302);
        }

        const upstreamUrl = new URL(request.url);
        upstreamUrl.protocol = "https:";
        upstreamUrl.hostname = "kuma.molinesdesigns.com";
        upstreamUrl.port = "";

        if (url.pathname === "/") {
            upstreamUrl.pathname = "/status/cortes";
            upstreamUrl.search = "";
        }

        const upstreamRequest = new Request(upstreamUrl.toString(), request);
        upstreamRequest.headers.set("host", "kuma.molinesdesigns.com");

        const upstreamResponse = await fetch(upstreamRequest, {
            redirect: "manual",
        });

        const responseHeaders = new Headers(upstreamResponse.headers);
        const location = responseHeaders.get("location");

        if (location) {
            responseHeaders.set(
                "location",
                location
                    .replace("https://kuma.molinesdesigns.com/status/cortes", "https://status.molinesdesigns.com/")
                    .replace("https://kuma.molinesdesigns.com", "https://status.molinesdesigns.com")
            );
        }

        const contentType = responseHeaders.get("content-type") || "";

        if (contentType.includes("text/html")) {
            responseHeaders.delete("content-length");
            const html = await upstreamResponse.text();
            const lockedHtml = html.replace(
                "</head>",
                `${STATUS_ONLY_CSS}${STATUS_ONLY_JS}</head>`
            );

            return new Response(lockedHtml, {
                status: upstreamResponse.status,
                statusText: upstreamResponse.statusText,
                headers: responseHeaders,
            });
        }

        return new Response(upstreamResponse.body, {
            status: upstreamResponse.status,
            statusText: upstreamResponse.statusText,
            headers: responseHeaders,
        });
    },
};
