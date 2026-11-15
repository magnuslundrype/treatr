#!/bin/bash
export HOME=/root PATH=/root/.local/bin:/root/.hermes/node/bin:/usr/local/bin:/usr/bin:/bin
export ANKER_BRIEF_TITLE="Treatr-arkitektur (Fable 5.2)" DISABLE_TELEMETRY=1
cd /srv/work/treatr-architecture
exec /root/.local/bin/claude --remote-control "Treatr-arkitektur (Fable 5.2)" \
  --model claude-fable-5-2 --permission-mode acceptEdits \
  --allowedTools "Read,Write,Edit,Glob,Grep,Bash,Skill,TodoWrite,Task,WebFetch,WebSearch"
