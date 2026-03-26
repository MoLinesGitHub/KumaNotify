setopt prompt_subst

autoload -Uz add-zsh-hook

_capsule_literal_segment() {
  local fg="$1"
  local bg="$2"
  local icon="$3"
  local text="$4"
  local pad="${5:- }"
  local body=" "

  [[ -n "$icon" ]] && body+="${icon}"
  [[ -n "$text" ]] && body+=" ${text}"
  body+="$pad"

  print -nrP "%F{$bg}%K{$bg}%F{$fg}${body}%k%f%F{$bg}%f"
}

_capsule_literal_fade_left() {
  print -nrP "%K{#6b6f83} %k%K{#8f93a6} %k%K{#c3c6d0} %k"
}

_capsule_literal_fade_right() {
  print -nrP "%K{#c3c6d0} %k%K{#8f93a6} %k%K{#6b6f83} %k"
}

_capsule_literal_path_text() {
  local path="${PWD/#$HOME/~}"

  if [[ "$path" == "~" ]]; then
    print -nr -- "~"
    return
  fi

  if [[ "$path" == "~/"* ]]; then
    local rel="${path#~/}"
    local -a parts
    parts=("${(@s:/:)rel}")
    if (( ${#parts} > 2 )); then
      print -nr -- "~/${parts[-2]}/${parts[-1]}"
    else
      print -nr -- "$path"
    fi
    return
  fi

  local -a parts
  parts=("${(@s:/:)path}")
  if (( ${#parts} > 2 )); then
    print -nr -- "…/${parts[-2]}/${parts[-1]}"
  else
    print -nr -- "$path"
  fi
}

_capsule_literal_path_icon() {
  if [[ "${PWD/#$HOME/~}" == "~" ]]; then
    print -nr -- ""
  else
    print -nr -- ""
  fi
}

_capsule_literal_git_branch() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
  git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

_capsule_literal_left_prompt() {
  local left=""
  local path_text="$(_capsule_literal_path_text)"
  local path_icon="$(_capsule_literal_path_icon)"
  local branch="$(_capsule_literal_git_branch)"

  left+="$(_capsule_literal_fade_left)"
  left+=" "
  left+="$(_capsule_literal_segment '#101319' '#f6f7fb' '' '' '')"
  left+="$(_capsule_literal_segment '#ffffff' '#1298ff' "$path_icon" "$path_text")"

  if [[ -n "$branch" ]]; then
    left+="$(_capsule_literal_segment '#ffffff' '#6d72ff' '' "$branch")"
  fi

  print -nr -- "$left"
}

_capsule_literal_right_prompt() {
  local last_status="$1"
  local status_icon="✓"
  local status_bg="#5f63eb"
  local time_text
  time_text="$(LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 date '+at %I:%M:%S %p' 2>/dev/null)"
  [[ -n "$time_text" ]] || time_text="$(date '+at %I:%M:%S')"

  if (( last_status != 0 )); then
    status_icon="✕"
    status_bg="#d45778"
  fi

  local right=""
  right+="$(_capsule_literal_segment '#ffffff' "$status_bg" "$status_icon" '' '')"
  right+="$(_capsule_literal_segment '#2f3542' '#f3f4f6' '' "${time_text} ")"
  right+=" "
  right+="$(_capsule_literal_fade_right)"

  print -nr -- "$right"
}

_capsule_literal_precmd() {
  local last_status=$?
  PROMPT="$(_capsule_literal_left_prompt)"$'\n'"%K{#8f93a6} %k "
  RPROMPT="$(_capsule_literal_right_prompt "$last_status")"
}

add-zsh-hook precmd _capsule_literal_precmd

PROMPT='%K{#8f93a6} %k '
RPROMPT=
