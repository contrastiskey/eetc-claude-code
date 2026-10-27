# DOM and security

From tsec, Google's checks for the browser APIs that turn strings into HTML
or code, the root of XSS:

- Never put a string built from data into an HTML or script sink:
  `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write` /
  `writeln`, `DOMParser.parseFromString`, `Range.createContextualFragment`,
  `iframe.srcdoc`, `script.text` / `textContent`,
  `document.execCommand('insertHTML')`, or `setAttribute` with an event
  handler (`onclick`) or URL attribute. Framework escape hatches are sinks
  too: React `dangerouslySetInnerHTML`, Angular `bypassSecurityTrust*`, Vue
  `v-html`.
- Instead set `textContent`, build elements with `createElement`, or let the
  framework's templating escape the value. When HTML from data is
  unavoidable, sanitize it at the sink with
  [safevalues](https://github.com/google/safevalues) (Google) or DOMPurify.
- No code from strings: `eval`, `new Function('...')`,
  `setTimeout('code')`, `setInterval('code')`. Script URLs (`script.src`,
  `new Worker()`, `navigator.serviceWorker.register()`) are constants, never
  data.
- A URL from data that goes into `href`, `src` or `location` is relative,
  `https:` or `http:`. Reject anything else; `javascript:` URLs run code.

The rest of the style is in [SKILL.md](SKILL.md).
