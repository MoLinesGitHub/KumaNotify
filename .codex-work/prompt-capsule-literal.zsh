setopt prompt_subst

autoload -Uz add-zsh-hook

_capsule_literal_visible_width() {
  local rendered
  rendered="$(print -P -- "$1")"
  python3 - "$rendered" <<'PY'
import re, sys
s = sys.argv[1]
s = re.sub(r'\x1b\[[0-9;]*m', '', s)
print(len(s))
PY
}

_capsule_literal_segment() {
  local fg="$1"
  local bg="$2"
  local icon="$3"
  local text="$4"
  local pad="${5:- }"
  local left_edge="${6:-round}"
  local right_edge="${7:-round}"
  local body=" "
  local safe_icon="${icon//\%/%%}"
  local safe_text="${text//\%/%%}"
  local left_cap right_cap

  [[ -n "$safe_icon" ]] && body+="${safe_icon}"
  [[ -n "$safe_text" ]] && body+=" ${safe_text}"
  body+="$pad"

  if [[ "$left_edge" == square ]]; then
    left_cap="%K{$bg} %F{$fg}"
  else
    left_cap="%F{$bg}%K{$bg}%F{$fg}"
  fi

  if [[ "$right_edge" == square ]]; then
    right_cap="%K{$bg} %k%f"
  else
    right_cap="%k%F{$bg}%f"
  fi

  print -nr -- "${left_cap}${body}${right_cap}"
}

_capsule_literal_fade_left() {
  print -nr -- "%K{#70748a} %k%K{#8d91a5} %k%K{#b5b8c3} %k%K{#d3d5dc} %k"
}

_capsule_literal_fade_right() {
  print -nr -- "%K{#d3d5dc} %k%K{#b5b8c3} %k%K{#8d91a5} %k%K{#70748a} %k"
}

_capsule_literal_path_text() {
  local path="${PWD/#$HOME/~}"
  print -nr -- "$path"
}

_capsule_literal_path_icon() {
  if [[ "${PWD/#$HOME/~}" == "~" ]]; then
    print -nr -- ""
  else
    print -nr -- ""
  fi
}

_capsule_literal_git_branch() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
  git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

_capsule_literal_project_name() {
  local name=""

  if [[ -f package.json ]]; then
    name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json | head -n 1)"
  elif [[ -f Package.swift || -n *.xcodeproj(N) || -n *.xcworkspace(N) ]]; then
    local proj
    proj=(*.xcodeproj(N) *.xcworkspace(N))
    if (( ${#proj} )); then
      name="${proj[1]}"
      name="${name%.xcodeproj}"
      name="${name%.xcworkspace}"
    else
      name="${PWD:t}"
    fi
  elif [[ -f pyproject.toml ]]; then
    name="$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' pyproject.toml | head -n 1)"
  fi

  [[ -n "$name" ]] || return
  print -nr -- "${name:t}"
}

_capsule_literal_runtime() {
  if [[ -f Package.swift || -n *.xcodeproj(N) || -n *.xcworkspace(N) ]]; then
    (( $+commands[swift] )) || return
    local version
    version=$(swift --version 2>/dev/null | awk 'NR==1 {for (i=1; i<=NF; ++i) if ($i == "version") {print $(i+1); exit}}')
    [[ -n "$version" ]] && print -nr -- "🐦 ${version}"
    return
  fi

  if [[ -f package.json || -f .node-version || -f .nvmrc ]]; then
    (( $+commands[node] )) || return
    local version
    version=$(node -v 2>/dev/null)
    version=${version#v}
    [[ -n "$version" ]] && print -nr -- "🟢 ${version}"
    return
  fi

  if [[ -f pyproject.toml || -f requirements.txt || -f Pipfile ]]; then
    (( $+commands[python3] )) || return
    local version
    version=$(python3 --version 2>/dev/null)
    version=${version##* }
    [[ -n "$version" ]] && print -nr -- "🐍 ${version}"
  fi
}

_capsule_literal_ram_alert() {
  (( $+commands[memory_pressure] )) || return

  local report total free purgeable speculative available used
  report="$(memory_pressure 2>/dev/null)" || return

  total="$(print -r -- "$report" | sed -n 's/.*(\([0-9][0-9]*\) pages.*/\1/p' | head -n 1)"
  free="$(print -r -- "$report" | sed -n 's/^Pages free:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  purgeable="$(print -r -- "$report" | sed -n 's/^Pages purgeable:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  speculative="$(print -r -- "$report" | sed -n 's/^Pages speculative:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"

  [[ -n "$total" && -n "$free" && -n "$purgeable" && -n "$speculative" ]] || return
  (( total > 0 )) || return

  available=$(( free + purgeable + speculative ))
  used=$(( 100 - ((available * 100) / total) ))

  (( used >= 75 )) || return
  print -nr -- "🧠 ${used}%"
}

_capsule_literal_disk_free() {
  (( $+commands[df] )) || return

  local available
  available="$(df -H "$PWD" 2>/dev/null | awk 'NR==2 {print $4}')"
  [[ -n "$available" ]] || return
  print -nr -- "💾 ${available}"
}

_capsule_literal_git_dirty() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

  local porcelain staged modified untracked summary=""
  porcelain="$(git status --porcelain 2>/dev/null)" || return
  [[ -n "$porcelain" ]] || return

  staged=$(print -r -- "$porcelain" | awk 'substr($0,1,1)!=" " && substr($0,1,1)!="?" {c++} END{print c+0}')
  modified=$(print -r -- "$porcelain" | awk 'substr($0,2,1)!=" " && substr($0,1,1)!="?" {c++} END{print c+0}')
  untracked=$(print -r -- "$porcelain" | awk 'substr($0,1,2)=="??" {c++} END{print c+0}')

  (( staged > 0 )) && summary+=" +${staged}"
  (( modified > 0 )) && summary+=" ~${modified}"
  (( untracked > 0 )) && summary+=" ?${untracked}"
  [[ -n "$summary" ]] || return

  print -nr -- "📝${summary}"
}

_capsule_literal_left_prompt() {
  local left=""
  local path_text="$(_capsule_literal_path_text)"
  local path_icon="$(_capsule_literal_path_icon)"
  local branch="$(_capsule_literal_git_branch)"

  left+="$(_capsule_literal_fade_left)"
  left+=" "
  left+="$(_capsule_literal_segment '#0c0d10' '#f4f5f8' '' '' '')"
  left+="$(_capsule_literal_segment '#ffffff' '#6b6ff6' "$path_icon" "$path_text" ' ' round square)"

  if [[ -n "$branch" ]]; then
    left+="$(_capsule_literal_segment '#0b0b0e' '#d1a221' '' "$branch" ' ' square round)"
  fi

  print -nr -- "$left"
}

_capsule_literal_right_prompt() {
  local last_status="$1"
  local budget="${2:-999}"
  local status_icon="✅"
  local status_bg="#5f63eb"
  local time_text
  local runtime_text project_text ram_text dirty_text disk_text
  time_text="$(LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 date '+at %I:%M:%S %p' 2>/dev/null)"
  [[ -n "$time_text" ]] || time_text="$(date '+at %I:%M:%S')"
  runtime_text="$(_capsule_literal_runtime)"
  project_text="$(_capsule_literal_project_name)"
  ram_text="$(_capsule_literal_ram_alert)"
  dirty_text="$(_capsule_literal_git_dirty)"
  disk_text="$(_capsule_literal_disk_free)"

  if (( last_status != 0 )); then
    status_icon="❌"
    status_bg="#d45778"
  fi

  local status_seg ram_seg disk_seg time_seg right candidate
  status_seg="$(_capsule_literal_segment '#ffffff' "$status_bg" "$status_icon" '' '')"
  ram_seg=""
  [[ -n "$ram_text" ]] && ram_seg="$(_capsule_literal_segment '#ffffff' '#d16b48' '' "$ram_text")"
  disk_seg=""
  [[ -n "$disk_text" ]] && disk_seg="$(_capsule_literal_segment '#ffffff' '#2b8f6c' '' "$disk_text")"
  time_seg="$(_capsule_literal_segment '#2f3542' '#f3f4f6' '' "${time_text} ")"
  right="${status_seg}${disk_seg}${ram_seg}${time_seg}"

  local extra_seg
  for extra_seg in \
    "$([[ -n "$runtime_text" ]] && _capsule_literal_segment '#ffffff' '#5d66ff' '' "$runtime_text")" \
    "$([[ -n "$project_text" ]] && _capsule_literal_segment '#ffffff' '#3f4d72' '📦' "$project_text")" \
    "$([[ -n "$dirty_text" ]] && _capsule_literal_segment '#ffffff' '#7b4bb7' '' "$dirty_text")"
  do
    [[ -n "$extra_seg" ]] || continue
    candidate="${status_seg}${extra_seg}${disk_seg}${ram_seg}${time_seg} $(_capsule_literal_fade_right)"
    (( $(_capsule_literal_visible_width "$candidate") <= budget )) && right="${status_seg}${extra_seg}${disk_seg}${ram_seg}${time_seg}"
  done

  right+=" "
  right+="$(_capsule_literal_fade_right)"

  print -nr -- "$right"
}

_capsule_literal_precmd() {
  local last_status=$?
  local left_prompt right_prompt top_line
  local left_width right_width budget columns gap
  columns=${COLUMNS:-120}
  left_prompt="$(_capsule_literal_left_prompt)"
  left_width="$(_capsule_literal_visible_width "$left_prompt")"
  budget=$(( columns - left_width - 4 ))
  (( budget < 18 )) && budget=18

  right_prompt="$(_capsule_literal_right_prompt "$last_status" "$budget")"
  right_width="$(_capsule_literal_visible_width "$right_prompt")"
  gap=$(( columns - left_width - right_width ))
  (( gap < 1 )) && gap=1

  top_line="${left_prompt}$(printf '%*s' "$gap" '')${right_prompt}"
  PROMPT="${top_line}"$'\n'"%K{#818598}  %k "
  RPROMPT=
}

add-zsh-hook precmd _capsule_literal_precmd

PROMPT='%K{#818598}  %k '
RPROMPT=
