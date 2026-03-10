// NEXT_PUBLIC_* vars are baked at build time in Next.js, so setting them
// in docker-compose `environment` has no effect at runtime.  Instead we
// auto-detect: use the browser's current hostname with a configurable port
// so the dashboard works on localhost, LAN IPs, and custom Docker port maps
// without any code changes.
//
// Override order:
//   1. Build-time NEXT_PUBLIC_API_URL (for advanced users who rebuild the image)
//   2. Runtime auto-detect from window.location.hostname + port 8000

function resolveForwardedBackendOrigin(location: Location): string | null {
  const { hostname, protocol } = location;

  // GitHub Codespaces / forwarded ports use subdomains like:
  //   <slug>-3000.app.github.dev
  // The backend is exposed as the sibling forwarded port domain:
  //   <slug>-8000.app.github.dev
  const githubForwarded = hostname.match(/^(.*?)-\d+\.(app\.github\.dev|github\.dev)$/);
  if (githubForwarded) {
    return `${protocol}//${githubForwarded[1]}-8000.${githubForwarded[2]}`;
  }

  return null;
}

function resolveApiBase(): string {
  // Build-time override (works when image is rebuilt with the env var)
  if (process.env.NEXT_PUBLIC_API_URL) {
    return process.env.NEXT_PUBLIC_API_URL;
  }

  // Server-side rendering: fall back to localhost
  if (typeof window === "undefined") {
    return "http://localhost:8000";
  }

  // Client-side: use the same hostname the user is browsing on
  const forwardedOrigin = resolveForwardedBackendOrigin(window.location);
  if (forwardedOrigin) {
    return forwardedOrigin;
  }

  const proto = window.location.protocol;
  const host = window.location.hostname;
  return `${proto}//${host}:8000`;
}

export const API_BASE = resolveApiBase();
