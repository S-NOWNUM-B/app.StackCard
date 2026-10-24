// Trusted API не должен менять адрес назначения после передачи token или payload.
export function safeApiEndpoint(value: string, allowDemoHttp = false): string | null {
  if (!/^https?:\/\/[^/]/.test(value) || /[\s\\?#\u0000-\u001f\u007f]/.test(value)) return null;
  try {
    const url = new URL(value);
    if (
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      (url.protocol !== 'https:' &&
        !(
          allowDemoHttp &&
          url.protocol === 'http:' &&
          ['localhost', '127.0.0.1'].includes(url.hostname)
        ))
    )
      return null;
    return url.href;
  } catch {
    return null;
  }
}
