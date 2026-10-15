import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseArguments, sendNotification } from '../notify-telegram.mjs';

const fakeEnv = Object.freeze({
  TELEGRAM_BOT_TOKEN: '123456:fixture_token_never_real',
  TELEGRAM_ALLOWED_USER_ID: '42',
});

function telegramResponse(status, payload) {
  return { status, ok: status >= 200 && status < 300, json: async () => payload };
}

test('sends metadata-only message for each allowed event and labels test sends', async () => {
  for (const [event, label] of [
    ['complete', '本轮已完成'],
    ['question', '有待回答的问题'],
    ['permission', '有待处理的权限请求'],
  ]) {
    let call;
    const result = await sendNotification({
      event,
      projectName: 'demo-project',
      sessionID: 'ses_abcdefgh12345678',
      sessionTitle: '真实会话标题',
      timestamp: '12:34:56',
      testing: true,
      env: fakeEnv,
      fetchImpl: async (...args) => {
        call = args;
        return telegramResponse(200, { ok: true, result: { message_id: 1 } });
      },
    });

    assert.deepEqual(result, { ok: true, event, testing: true });
    assert.equal(call[0], 'https://api.telegram.org/bot123456:fixture_token_never_real/sendMessage');
    assert.equal(call[1].method, 'POST');
    const payload = JSON.parse(call[1].body);
    assert.equal(payload.chat_id, '42');
    assert.equal(payload.text, `[测试] OpenCode 通知\n项目：demo-project\n会话：真实会话标题\n事件：${label}\n时间：12:34:56`);
    assert.equal(payload.text.includes('12345678'), false);
    assert.equal(call[1].headers['content-type'], 'application/json');
    assert.equal(call[1].redirect, 'error');
  }
});

test('unsupported event succeeds as skipped without HTTP', async () => {
  let calls = 0;
  const result = await sendNotification({
    event: 'tool', env: fakeEnv,
    fetchImpl: async () => { calls += 1; throw new Error('must not call'); },
  });
  assert.deepEqual(result, { ok: true, skipped: true, event: 'unsupported', testing: false });
  assert.equal(calls, 0);
});

test('missing or blank session title uses an explicit fallback, never the session ID', async () => {
  for (const sessionTitle of [undefined, '', ' \t\n ']) {
    let payload;
    const result = await sendNotification({
      event: 'complete', projectName: 'demo', sessionID: 'ses_secretid12345678', sessionTitle,
      timestamp: '09:15:00', env: fakeEnv,
      fetchImpl: async (_url, request) => {
        payload = JSON.parse(request.body);
        return telegramResponse(200, { ok: true });
      },
    });
    assert.equal(result.ok, true);
    assert.match(payload.text, /会话：未命名会话/u);
    assert.equal(payload.text.includes('12345678'), false);
    assert.match(payload.text, /时间：09:15:00/u);
  }
});

test('CLI argument parsing forwards title and timestamp after the legacy three arguments', () => {
  assert.deepEqual(parseArguments([
    '--test', 'complete', 'demo', 'ses_12345678', '真实会话标题', '12:34:56',
  ]), {
    event: 'complete',
    projectName: 'demo',
    sessionID: 'ses_12345678',
    sessionTitle: '真实会话标题',
    timestamp: '12:34:56',
    testing: true,
  });
  assert.deepEqual(parseArguments(['complete', 'demo', 'ses_12345678']), {
    event: 'complete',
    projectName: 'demo',
    sessionID: 'ses_12345678',
    sessionTitle: undefined,
    timestamp: undefined,
    testing: false,
  });
});

test('a positional title equal to --test is preserved and does not enable test mode', async () => {
  assert.deepEqual(parseArguments(['complete', 'demo', 'ses_12345678', '--test', '12:34:56']), {
    event: 'complete',
    projectName: 'demo',
    sessionID: 'ses_12345678',
    sessionTitle: '--test',
    timestamp: '12:34:56',
    testing: false,
  });

  let payload;
  const result = await sendNotification({
    ...parseArguments(['complete', 'demo', 'ses_12345678', '--test', '12:34:56']),
    env: fakeEnv,
    fetchImpl: async (_url, request) => {
      payload = JSON.parse(request.body);
      return telegramResponse(200, { ok: true });
    },
  });
  assert.deepEqual(result, { ok: true, event: 'complete', testing: false });
  assert.match(payload.text, /会话：--test/u);
  assert.equal(payload.text.startsWith('[测试] '), false);
});

test('notifier command appends title and timestamp placeholders after the legacy arguments', () => {
  const configPath = fileURLToPath(new URL('../opencode-notifier.json', import.meta.url));
  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  assert.deepEqual(config.command.args.slice(-5), [
    '{event}', '{projectName}', '{sessionID}', '{sessionTitle}', '{timestamp}',
  ]);
});

test('missing credentials and invalid recipient fail before transport', async (t) => {
  for (const [env, code] of [
    [{ TELEGRAM_ALLOWED_USER_ID: '42' }, 'missing_token'],
    [{ ...fakeEnv, TELEGRAM_BOT_TOKEN: '' }, 'missing_token'],
    [{ ...fakeEnv, TELEGRAM_BOT_TOKEN: 'fixture-token with spaces' }, 'invalid_token'],
    [{ ...fakeEnv, TELEGRAM_ALLOWED_USER_ID: '0' }, 'invalid_recipient'],
    [{ ...fakeEnv, TELEGRAM_ALLOWED_USER_ID: '42; echo bad' }, 'invalid_recipient'],
  ]) {
    await t.test(code, async () => {
      let calls = 0;
      const result = await sendNotification({
        event: 'complete', env,
        fetchImpl: async () => { calls += 1; throw new Error('must not call'); },
      });
      assert.equal(result.ok, false);
      assert.equal(result.code, code);
      assert.equal(calls, 0);
    });
  }
});

test('proxy protocols are validated and explicit proxy agent is passed', async (t) => {
  for (const [proxy, expectedKind] of [
    ['http://127.0.0.1:7890', 'http'],
    ['socks5h://127.0.0.1:1080', 'socks'],
  ]) {
    await t.test(expectedKind, async () => {
      const sentinelAgent = { kind: expectedKind };
      let agentSeen;
      const result = await sendNotification({
        event: 'complete', env: { ...fakeEnv, TELEGRAM_PROXY_URL: proxy },
        proxyAgentFactory: (kind, url) => {
          assert.equal(kind, expectedKind);
          assert.equal(url, proxy);
          return sentinelAgent;
        },
        fetchImpl: async (_url, options) => {
          agentSeen = options.agent;
          return telegramResponse(200, { ok: true });
        },
      });
      assert.equal(result.ok, true);
      assert.equal(agentSeen, sentinelAgent);
      assert.equal(JSON.stringify(result).includes(proxy), false);
    });
  }
  const invalid = await sendNotification({
    event: 'complete', env: { ...fakeEnv, TELEGRAM_PROXY_URL: 'file:///tmp/proxy' },
    fetchImpl: async () => { throw new Error('must not call'); },
  });
  assert.equal(invalid.code, 'proxy_invalid');

  let directCalls = 0;
  const failedProxy = await sendNotification({
    event: 'complete', env: { ...fakeEnv, TELEGRAM_PROXY_URL: 'http://127.0.0.1:7890' },
    proxyAgentFactory: () => { throw new Error('fixture proxy failure'); },
    fetchImpl: async () => { directCalls += 1; return telegramResponse(200, { ok: true }); },
  });
  assert.equal(failedProxy.code, 'proxy_unavailable');
  assert.equal(directCalls, 0);
});

test('rate limit retries once only within the bounded delay; otherwise reports failure', async (t) => {
  await t.test('bounded retry', async () => {
    let calls = 0;
    const waits = [];
    const result = await sendNotification({
      event: 'question', env: fakeEnv,
      sleepImpl: async (seconds) => waits.push(seconds),
      fetchImpl: async () => {
        calls += 1;
        return calls === 1
          ? telegramResponse(429, { ok: false, parameters: { retry_after: 2 } })
          : telegramResponse(200, { ok: true });
      },
    });
    assert.equal(result.ok, true);
    assert.equal(calls, 2);
    assert.deepEqual(waits, [2]);
  });
  await t.test('no retry for oversized delay', async () => {
    let calls = 0;
    const result = await sendNotification({
      event: 'question', env: fakeEnv,
      fetchImpl: async () => {
        calls += 1;
        return telegramResponse(429, { ok: false, parameters: { retry_after: 6 } });
      },
    });
    assert.equal(result.code, 'telegram_rate_limited');
    assert.equal(calls, 1);
  });
  await t.test('retry is capped at one attempt', async () => {
    let calls = 0;
    const result = await sendNotification({
      event: 'question', env: fakeEnv,
      sleepImpl: async () => {},
      fetchImpl: async () => {
        calls += 1;
        return telegramResponse(429, { ok: false, parameters: { retry_after: 0 } });
      },
    });
    assert.equal(result.code, 'telegram_rate_limited');
    assert.equal(calls, 2);
  });
});

test('HTTP errors, malformed API response, and thrown network errors are generic and secret-safe', async (t) => {
  for (const [name, fetchImpl, expected] of [
    ['unauthorized', async () => telegramResponse(401, { ok: false, description: '123456:fixture_token_never_real' }), 'telegram_http_401'],
    ['server error', async () => telegramResponse(503, { ok: false }), 'telegram_http_503'],
    ['API rejected', async () => telegramResponse(200, { ok: false, description: '123456:fixture_token_never_real' }), 'telegram_rejected'],
    ['network exception', async () => { throw new Error('https://api.telegram.org/bot123456:fixture_token_never_real/sendMessage'); }, 'telegram_network_error'],
  ]) {
    await t.test(name, async () => {
      const result = await sendNotification({ event: 'complete', env: fakeEnv, fetchImpl });
      assert.equal(result.ok, false);
      assert.equal(result.code, expected);
      assert.equal(JSON.stringify(result).includes(fakeEnv.TELEGRAM_BOT_TOKEN), false);
      assert.equal(JSON.stringify(result).includes('https://'), false);
    });
  }
});

test('untrusted title, project, and timestamp are bounded single-line data and never evaluated', async () => {
  let payload;
  const attackText = '`; process.exit(99);\n\u0000' + 'x'.repeat(5000);
  const result = await sendNotification({
    event: 'complete',
    projectName: attackText,
    sessionID: 'ses_\nIGNORE',
    sessionTitle: '`; process.exit(98);\n\u0000' + '标題🙂'.repeat(200),
    timestamp: '12:34:56\n伪造事件：permission',
    env: fakeEnv,
    fetchImpl: async (_url, request) => {
      payload = JSON.parse(request.body);
      return telegramResponse(200, { ok: true });
    },
  });
  assert.equal(result.ok, true);
  assert.equal(payload.text.includes('process.exit(99)'), true);
  assert.equal(payload.text.includes('process.exit(98)'), true);
  assert.equal(payload.text.includes('\n伪造事件：permission'), false);
  assert.equal(payload.text.includes('\nIGNORE'), false);
  const titleLine = payload.text.split('\n').find((line) => line.startsWith('会话：'));
  assert.equal(Array.from(titleLine.slice('会话：'.length)).length, 256);
  assert.equal(payload.text.includes('ses_'), false);
  assert.equal(Array.from(payload.text).length <= 4096, true);
  assert.equal(payload.text.includes('reasoning'), false);
  assert.equal(payload.text.includes('tool'), false);
});

test('importing the sender has no network side effect', () => {
  const moduleUrl = new URL('../notify-telegram.mjs', import.meta.url).href;
  const child = spawnSync(process.execPath, ['--input-type=module', '-e', `await import(${JSON.stringify(moduleUrl)})`], {
    encoding: 'utf8',
    env: { PATH: process.env.PATH, HOME: '/tmp/opencode/notify-telegram-test-home' },
  });
  assert.equal(child.status, 0);
  assert.equal(child.stdout, '');
  assert.equal(child.stderr, '');
});

test('CLI entry detection handles real path and file/directory symlink aliases', () => {
  const sourcePath = realpathSync(fileURLToPath(new URL('../notify-telegram.mjs', import.meta.url)));
  const tempBase = existsSync('/tmp/opencode') ? '/tmp/opencode' : os.tmpdir();
  const fixtureRoot = mkdtempSync(path.join(tempBase, 'notify-telegram-entry-'));
  try {
    const fileAlias = path.join(fixtureRoot, 'file alias ü.mjs');
    const directoryAlias = path.join(fixtureRoot, 'directory alias ü');
    symlinkSync(sourcePath, fileAlias);
    symlinkSync(path.dirname(sourcePath), directoryAlias, 'dir');
    const directoryFileAlias = path.join(directoryAlias, path.basename(sourcePath));

    const invocations = [
      [[], sourcePath],
      [[], fileAlias],
      [[], directoryFileAlias],
      [['--preserve-symlinks-main'], fileAlias],
      [['--preserve-symlinks-main'], directoryFileAlias],
    ];
    for (const [flags, entry] of invocations) {
      const child = spawnSync(process.execPath, [...flags, entry, 'unsupported-test-event'], {
        cwd: fixtureRoot,
        encoding: 'utf8',
        env: { PATH: process.env.PATH || '', HOME: fixtureRoot },
      });
      assert.equal(child.status, 0, `CLI exited unsuccessfully for ${flags.length ? 'preserve-symlinks' : 'normal'} entry`);
      assert.equal(child.stderr, '');
      assert.deepEqual(JSON.parse(child.stdout), {
        ok: true,
        skipped: true,
        event: 'unsupported',
        testing: false,
      });
    }
  } finally {
    rmSync(fixtureRoot, { recursive: true, force: true });
  }
});
