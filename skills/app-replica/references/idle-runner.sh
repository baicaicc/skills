#!/bin/bash
# 空闲窗口执行器：在用户的日用机（原 App 装在那）上跑实机步骤（L1、实机验收），不找人确认。
# 只在「未锁屏且 ≥ IDLE_MIN 秒没人动」时开跑；每步前后比鼠标位置，变了就中止、还原，等下一个空闲窗口从没做完的那步续跑。
# 用法（在日用机上 nohup 起）：
#   DIR=/tmp/<代号>-e2e STEPS="g01 g02 …" STEP_CMD="bash /tmp/<代号>-e2e/e2e.sh" \
#   PREP="退出原 App、存剪贴板/音量" RESTORE="恢复剪贴板/音量、重开原 App" nohup bash idle-runner.sh &
# 结果：$DIR/out/<步骤>.done 与 $DIR/runner.log；全部做完写 $DIR/ALL_DONE。PREP/RESTORE 是 shell 命令串。
DIR=${DIR:?}; STEPS=${STEPS:?}; STEP_CMD=${STEP_CMD:?}; IDLE_MIN=${IDLE_MIN:-240}; HOURS=${HOURS:-20}
LOG=$DIR/runner.log; mkdir -p "$DIR/out"
locked() { ioreg -n Root -d1 -a 2>/dev/null | grep -A1 CGSSessionScreenIsLocked | grep -q true; }
idle() { echo $(( $(ioreg -c IOHIDSystem | awk '/HIDIdleTime/{print $NF; exit}') / 1000000000 )); }
mouse() { python3 -c 'import ctypes,ctypes.util
cg=ctypes.CDLL(ctypes.util.find_library("CoreGraphics"))
class P(ctypes.Structure): _fields_=[("x",ctypes.c_double),("y",ctypes.c_double)]
cg.CGEventCreate.restype=ctypes.c_void_p; cg.CGEventGetLocation.restype=P; cg.CGEventGetLocation.argtypes=[ctypes.c_void_p]
p=cg.CGEventGetLocation(cg.CGEventCreate(None)); print(int(p.x),int(p.y))'; }
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }
deadline=$(( $(date +%s) + HOURS*3600 )); log "runner start"
while [ "$(date +%s)" -lt $deadline ]; do
  if locked || [ "$(idle)" -lt "$IDLE_MIN" ]; then sleep 30; continue; fi
  log "idle window: idle=$(idle)s"; caffeinate -dimsu -t 7200 >/dev/null 2>&1 & CAF=$!
  M0=$(mouse); eval "${PREP:-true}"; ok=1
  for s in $STEPS; do
    [ -f "$DIR/out/$s.done" ] && continue
    if [ "$(mouse)" != "$M0" ] || locked; then log "user back before $s"; ok=0; break; fi
    $STEP_CMD "$s" > "$DIR/out/$s.txt" 2>&1
    if [ "$(mouse)" != "$M0" ]; then log "user moved during $s → discard"; rm -f "$DIR/out/$s.txt"; ok=0; break; fi
    touch "$DIR/out/$s.done"; log "done $s: $(tail -1 "$DIR/out/$s.txt" | cut -c1-120)"
  done
  eval "${RESTORE:-true}"; kill $CAF 2>/dev/null
  if [ $ok = 1 ]; then log "all done"; touch "$DIR/ALL_DONE"; exit 0; fi
  sleep 60
done
log "deadline reached"
