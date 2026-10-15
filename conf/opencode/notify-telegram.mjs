import { createRequire } from 'node:module';
import { realpathSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';

const EVENT_LABELS = Object.freeze({
  complete: '本轮已完成',
  question: '有待回答的问题',
  permission: '有待处理的权限请求',
});

const MAX_TEXT_CHARS = 4096;
const REQUEST_TIMEOUT_MS = 10_000;
const MAX_RATE_LIMIT_RETRY_SECONDS = 5;

function resultError(code, event = 'unknown', testing = false) {
  return { ok: false, code, event, testing };
}

function sanitizeSingleLine(value, maxCodePoints) {
  const normalized = Array.from(String(value ?? ''), (char) => {
    const code = char.codePointAt(0);
    return code < 0x20 || (code >= 0x7f && code <= 0x9f) ? ' ' : char;
  }).join('').replace(/\s+/gu, ' ').trim();
  return Array.from(normalized).slice(0, maxCodePoints).join('');
}

function makeMessage({ testing, projectName, sessionTitle, timestamp, event }) {
  const prefix = testing ? '[测试] ' : '';
  const title = sanitizeSingleLine(sessionTitle, 256) || '未命名会话';
  const time = sanitizeSingleLine(timestamp, 96) || '未知';
  const project = sanitizeSingleLine(projectName, 256) || '未知';
  const text = `${prefix}OpenCode 通知\n项目：${project}\n会话：${title}\n事件：${EVENT_LABELS[event]}\n时间：${time}`;
  return Array.from(text).slice(0, MAX_TEXT_CHARS).join('');
}

function validRecipient(value) {
  if (typeof value !== 'string' || !/^\d+$/u.test(value)) return false;
  try {
    return BigInt(value) > 0n;
  } catch {
    return false;
  }
}

function proxyProtocol(proxyUrl) {
  let parsed;
  try {
    parsed = new URL(proxyUrl);
  } catch {
    return null;
  }
  if (parsed.username || parsed.password) return null;
  if (['http:', 'https:'].includes(parsed.protocol)) return 'http';
  if (['socks:', 'socks4:', 'socks4a:', 'socks5:', 'socks5h:'].includes(parsed.protocol)) return 'socks';
  return null;
}

function loadRuntimeTransport(env, proxyUrl) {
  const home = env.XDG_DATA_HOME || `${env.HOME || ''}/.local/share`;
  if (!home || home === '/.local/share') return { error: 'runtime_unavailable' };
  const runtimePackage = `${home}/opencode-telegram-bot/runtime-0.26.4/package.json`;
  let requireFromRuntime;
  try {
    requireFromRuntime = createRequire(runtimePackage);
  } catch {
    return { error: 'runtime_unavailable' };
  }

  let fetchImpl;
  try {
    const nodeFetch = requireFromRuntime('node-fetch');
    fetchImpl = nodeFetch.default || nodeFetch;
  } catch {
    return { error: 'runtime_unavailable' };
  }

  if (!proxyUrl) return { fetchImpl };
  const kind = proxyProtocol(proxyUrl);
  if (!kind) return { error: 'proxy_invalid' };
  try {
    if (kind === 'http') {
      const imported = requireFromRuntime('https-proxy-agent');
      const Agent = imported.HttpsProxyAgent || imported.default || imported;
      return { fetchImpl, agent: new Agent(proxyUrl) };
    }
    const imported = requireFromRuntime('socks-proxy-agent');
    const Agent = imported.SocksProxyAgent || imported.default || imported;
    return { fetchImpl, agent: new Agent(proxyUrl) };
  } catch {
    return { error: 'proxy_unavailable' };
  }
}

async function readTelegramReply(response) {
  try {
    const body = await response.json();
    return { ok: body?.ok === true, retryAfter: body?.parameters?.retry_after };
  } catch {
    return { ok: false, retryAfter: undefined };
  }
}

async function defaultSleep(seconds) {
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

/** Send one metadata-only Telegram notification. Inject transport only in offline tests. */
export async function sendNotification(options = {}) {
  const { event, projectName, sessionID, sessionTitle, timestamp, testing = false } = options;
  const knownEvent = Object.hasOwn(EVENT_LABELS, event);
  if (!knownEvent) return { ok: true, skipped: true, event: 'unsupported', testing: Boolean(testing) };

  const env = options.env || process.env;
  const token = env.TELEGRAM_BOT_TOKEN;
  const recipient = env.TELEGRAM_ALLOWED_USER_ID;
  if (typeof token !== 'string' || token.length === 0) return resultError('missing_token', event, Boolean(testing));
  if (!/^\d+:[A-Za-z0-9_-]+$/u.test(token)) return resultError('invalid_token', event, Boolean(testing));
  if (!validRecipient(recipient)) return resultError('invalid_recipient', event, Boolean(testing));

  const proxyUrl = env.TELEGRAM_PROXY_URL || '';
  let fetchImpl = options.fetchImpl;
  let agent = options.agent;
  if (!fetchImpl) {
    const transport = loadRuntimeTransport(env, proxyUrl);
    if (transport.error) return resultError(transport.error, event, Boolean(testing));
    fetchImpl = transport.fetchImpl;
    agent = transport.agent;
  } else if (proxyUrl) {
    const kind = proxyProtocol(proxyUrl);
    if (!kind) return resultError('proxy_invalid', event, Boolean(testing));
    if (options.proxyAgentFactory) {
      try {
        agent = options.proxyAgentFactory(kind, proxyUrl);
      } catch {
        return resultError('proxy_unavailable', event, Boolean(testing));
      }
    }
    if (!agent) return resultError('proxy_unavailable', event, Boolean(testing));
  }

  const message = makeMessage({ testing: Boolean(testing), projectName, sessionTitle, timestamp, event });
  if (Array.from(message).length > MAX_TEXT_CHARS) return resultError('message_too_long', event, Boolean(testing));

  // The token is required by Telegram's Bot API URL, but is never returned or logged.
  const endpoint = `https://api.telegram.org/bot${token}/sendMessage`;
  const request = {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: recipient, text: message }),
    timeout: REQUEST_TIMEOUT_MS,
    redirect: 'error',
    ...(agent ? { agent } : {}),
  };
  const sleep = options.sleepImpl || defaultSleep;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    let response;
    try {
      response = await fetchImpl(endpoint, request);
    } catch {
      return resultError('telegram_network_error', event, Boolean(testing));
    }

    if (response.status === 429) {
      const reply = await readTelegramReply(response);
      const delay = Number(reply.retryAfter);
      if (attempt === 0 && Number.isInteger(delay) && delay >= 0 && delay <= MAX_RATE_LIMIT_RETRY_SECONDS) {
        try {
          await sleep(delay);
        } catch {
          return resultError('telegram_retry_wait_failed', event, Boolean(testing));
        }
        continue;
      }
      return resultError('telegram_rate_limited', event, Boolean(testing));
    }

    if (!response.ok) return resultError(`telegram_http_${response.status}`, event, Boolean(testing));
    const reply = await readTelegramReply(response);
    if (!reply.ok) return resultError('telegram_rejected', event, Boolean(testing));
    return { ok: true, event, testing: Boolean(testing) };
  }
  return resultError('telegram_rate_limited', event, Boolean(testing));
}

export function parseArguments(argv) {
  const testing = argv[0] === '--test';
  const positional = testing ? argv.slice(1) : argv;
  return {
    event: positional[0],
    projectName: positional[1],
    sessionID: positional[2],
    sessionTitle: positional[3],
    timestamp: positional[4],
    testing,
  };
}

function isMainModule() {
  const entry = process.argv[1];
  if (typeof entry !== 'string' || entry.length === 0) return false;
  try {
    const modulePath = realpathSync(fileURLToPath(import.meta.url));
    const entryPath = realpathSync(fileURLToPath(pathToFileURL(entry)));
    return modulePath === entryPath;
  } catch {
    return false;
  }
}

if (isMainModule()) {
  const result = await sendNotification(parseArguments(process.argv.slice(2)));
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (!result.ok) process.exitCode = 1;
}
