#!/bin/zsh
# 夜跑驱动：每轮一个新的 Claude Code 会话，状态全部在仓库里（git + docs/progress.md）。
# 用法：在 tmux 里 `DEADLINE=<epoch 秒> zsh overnight.sh`（启动前 env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID）。
# 停止：touch run/STOP。锁定模型：echo opus > run/FORCE_MODEL。
#
# 规则（来自 2026-10-26 Typora 试跑）：
# - 清单阶段用 KICKOFF.md；progress.md 第一行出现 ALL_DONE 后改用 KICKOFF-polish.md，跑到截止时间。
# - 连续两轮无提交 → 下一轮换备用模型。
# - 限流按类型退避：周期配额等到重置；速率限制等 10 分钟；网关 503 等 2 分钟并换模型。
# - 单轮超过 ROUND_MAX_MIN 且工作区干净时结束本轮（Opus 靠自动压缩上下文，不会自己停）。
# - DEADLINE 最多是启动后 10 小时；主力和备用的配额都要到截止时间以后才重置时，提前结束（技能「常设授权」第 2 条）。
repo=${REPO:?}           # 新仓库目录
run=${RUN_DIR:?}         # 本目录（含 launch.py、models.json、*.env、KICKOFF*.md）
deadline=${DEADLINE:?}
[ $(( deadline - $(date +%s) )) -le 36000 ] || { echo "DEADLINE 超过启动后 10 小时" >&2; exit 1; }
primary=${PRIMARY:-glm}; backup=${BACKUP:-opus}
round_max=$(( ${ROUND_MAX_MIN:-90} * 60 ))
mkdir -p $run/logs
round=0; stalled=0; switch_next=0; primary_until=0

log() { echo "$(date '+%F %T') $*" >> $run/logs/rounds.txt; }
clean() { [ -z "$(git -C $repo status --porcelain)" ]; }

while [ $(date +%s) -lt $deadline ] && [ ! -e $run/STOP ]; do
  round=$((round + 1)); start=$(date +%s)
  model=$primary
  { [ $stalled -ge 2 ] || [ $switch_next = 1 ] || [ $(date +%s) -lt $primary_until ]; } && model=$backup; switch_next=0
  phase=checklist; kickoff=$run/KICKOFF.md
  head -1 $repo/docs/progress.md 2>/dev/null | grep -q '^ALL_DONE' && { phase=polish; kickoff=$run/KICKOFF-polish.md; }
  before=$(git -C $repo rev-parse HEAD)
  out=$run/logs/round-$round-$model.jsonl
  (cd $repo && exec python3 -I $run/launch.py run $model -p "$(cat $kickoff)" \
     --dangerously-skip-permissions --output-format stream-json --verbose) > $out 2>&1 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep 30
    age=$(( $(date +%s) - start ))
    if { [ $age -gt $round_max ] && clean; } || [ $age -gt $((round_max + 1800)) ] || [ $(date +%s) -ge $deadline ]; then
      kill -TERM $pid 2>/dev/null; log "round=$round ended by driver after ${age}s (clean=$(clean && echo yes || echo no))"
    fi
  done
  wait $pid; code=$?
  secs=$(( $(date +%s) - start ))
  after=$(git -C $repo rev-parse HEAD)
  commits=$(git -C $repo rev-list --count $before..$after)
  ending=$(python3 -I $run/launch.py classify $out)
  log "round=$round model=$model phase=$phase exit=$code secs=$secs commits=$commits ending='$ending' head=${after:0:7}"
  if [ $commits -eq 0 ]; then stalled=$((stalled + 1)); else stalled=0; fi
  [ $model = $backup ] && stalled=0
  case $ending in
    quota*)     wait_s=${ending#quota }
                if [ $model = $primary ]; then primary_until=$(( $(date +%s) + wait_s )); log "primary quota: using $backup for ${wait_s}s"
                elif [ $(date +%s) -lt $primary_until ] && [ $primary_until -ge $deadline ] && [ $(( $(date +%s) + wait_s )) -ge $deadline ]; then
                  log "both channels out of quota past the deadline: stopping"; break
                else log "backup quota: sleeping"; sleep $(( wait_s < deadline - $(date +%s) ? wait_s : 60 )); fi ;;
    ratelimit*) sleep ${ending#ratelimit } ;;
    gateway)    sleep 120; [ $model = $primary ] && switch_next=1 ;;
  esac
done
(cd $repo && bash scripts/verify.sh) > $run/logs/final-verify.log 2>&1
log "finished, final verify exit=$?"
