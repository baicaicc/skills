#!/usr/bin/env python3 -I
"""Overnight helper.

  launch.py run <model> <claude args...>   start Claude Code with the env file run/<model>.env
  launch.py classify <round.jsonl>         print how a round ended: ok | ratelimit <secs> | quota <secs> | gateway | other

<model>.env is the 0600 JSON written by
  kll resolve claude-code <model-id> --json --launch-env-file run/<model>.env
run/models.json maps the short name to the CLI model id, e.g. {"glm": "glm-5.3", "opus": "claude-opus-5-5"}.
run/FORCE_MODEL (one line, a short name) overrides the requested model for every later round.
Never prints credential values.
"""
import datetime, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
# Variables that leak from a parent Claude Code / Codex session or point at another provider.
REMOVE = ['CLAUDECODE', 'CLAUDE_CODE_SESSION_ID', 'CLAUDE_CODE_CHILD_SESSION', 'CLAUDE_CODE_ENTRYPOINT',
          'CLAUDE_CODE_EXECPATH', 'CLAUDE_PID', 'CODEX_THREAD_ID', 'CODEX_SESSION_ID',
          'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'CLAUDE_CODE_OAUTH_TOKEN',
          'ANTHROPIC_DEFAULT_FABLE_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL', 'ANTHROPIC_SMALL_FAST_MODEL',
          'ANTHROPIC_MODEL', 'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL']


def run(model, args):
    force = os.path.join(HERE, 'FORCE_MODEL')
    if os.path.exists(force):
        forced = open(force).read().strip()
        print(f'launch.py: requested={model} forced={forced} (FORCE_MODEL)', file=sys.stderr, flush=True)
        model = forced
    models = json.load(open(os.path.join(HERE, 'models.json')))
    env = {k: v for k, v in os.environ.items() if k not in REMOVE}
    with open(os.path.join(HERE, f'{model}.env')) as f:
        env.update({k: v for k, v in json.load(f).items() if v != ''})
    claude = os.environ.get('CLAUDE_BIN') or 'claude'
    os.execvpe(claude, [claude, '--model', models[model], *args], env)


def classify(path):
    """Look at the final result line of a stream-json round log."""
    tail = open(path, 'rb').read()[-20000:].decode('utf-8', 'replace')
    result = ''
    for line in tail.splitlines():
        if '"type":"result"' in line:
            try: result = str(json.loads(line).get('result', ''))
            except Exception: result = line
    if '429' not in result and '503' not in result and 'API Error' not in result:
        return 'ok'
    reset = re.search(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s*重置', result)
    if reset:  # periodic quota, e.g. GLM 1308 "5 小时上限，将在 <Beijing time> 重置"
        at = datetime.datetime.strptime(reset.group(1), '%Y-%m-%d %H:%M:%S').replace(
            tzinfo=datetime.timezone(datetime.timedelta(hours=8)))
        secs = int((at - datetime.datetime.now(datetime.timezone.utc)).total_seconds()) + 60
        return f'quota {max(secs, 60)}'
    if '429' in result:
        return 'ratelimit 600'
    if '503' in result or 'upstream' in result:
        return 'gateway'
    return 'other'


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'run' and len(sys.argv) > 2:
        run(sys.argv[2], sys.argv[3:])
    elif cmd == 'classify' and len(sys.argv) == 3:
        print(classify(sys.argv[2]))
    else:
        sys.exit(__doc__)
