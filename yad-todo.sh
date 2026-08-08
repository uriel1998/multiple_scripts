#!/usr/bin/env bash

########################################################################
#   Using YAD to make a quick todo entry GUI
#   by Steven Saus (c)2021
#   Licensed under the MIT license
#
#   Legacy mode:
#     First argument is the path to todo.txt if it's not already exported
#     as TODO_FILE.
#
#   Todoman mode:
#     If no todo.txt file is supplied, use todoman and allow selecting a
#     target list from the same multi-list setup used by fzf_todo.sh.
########################################################################

set -euo pipefail

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${XDG_CACHE_HOME}/yad_todo"
TODOMAN_CACHE_HOME="${TODOMAN_CACHE_HOME:-${CACHE_DIR}/todoman}"
TODO_LIST_ROOT="${TODO_LIST_ROOT:-$HOME/.tasks}"
ALL_TASKS_CACHE_FILE="${CACHE_DIR}/alltasks"

mkdir -p "$CACHE_DIR"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1 || die "missing required command: $command_name"
}

todo_cmd() {
    XDG_CACHE_HOME="$TODOMAN_CACHE_HOME" todo "$@"
}

yad_combo_values() {
    local include_blank="$1"
    shift

    local value
    local output=""
    local first_item=1

    if [[ "$include_blank" == "blank" ]]; then
        output=" "
        first_item=0
    fi

    for value in "$@"; do
        [[ -n "$value" ]] || continue
        value="${value//\\/\\\\}"
        value="${value//!/\\!}"

        if [[ "$first_item" -eq 1 ]]; then
            output="${value}"
            first_item=0
        else
            output="${output}\\!${value}"
        fi
    done

    if [[ -z "$output" ]]; then
        output=" \\!"
    fi

    printf '%s' "$output"
}

priority_combo_values_legacy() {
    yad_combo_values blank {A..Z}
}

priority_combo_values_todoman() {
    yad_combo_values noblank none low medium high
}

extract_contexts() {
    grep -oE '@[^[:space:]]+' 2>/dev/null | sed 's/^@//' | sort -u
}

extract_projects() {
    grep -oE '\+[^[:space:]]+' 2>/dev/null | sed 's/^+//' | sort -u
}

build_summary_text() {
    local task_text="$1"
    local context_name="$2"
    local project_name="$3"

    local summary="$task_text"

    if [[ -n "$context_name" ]]; then
        summary="${summary} @${context_name}"
    fi

    if [[ -n "$project_name" ]]; then
        summary="${summary} +${project_name}"
    fi

    printf '%s' "$summary"
}

refresh_all_tasks_cache() {
    mkdir -p "$TODOMAN_CACHE_HOME"
    todo_cmd --porcelain list >"$ALL_TASKS_CACHE_FILE"
}

build_todoman_lists() {
    {
        if [[ -d "$TODO_LIST_ROOT" ]]; then
            find -L "$TODO_LIST_ROOT" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null
        fi
        todo_cmd --porcelain lists | jq -r '.[]'
    } | awk 'NF' | sort -u
}

todoman_list_exists() {
    local target_list="$1"

    [[ -n "$target_list" ]] || return 1
    build_todoman_lists | grep -Fxq "$target_list"
}

legacy_mode() {
    local todo_file="$1"
    local projects
    local contexts
    local priority
    local out_string
    local new_task
    local new_context
    local new_project
    local new_priority
    local new_date
    local task_string

    mapfile -d '' -t project_values < <(extract_projects <"$todo_file" | tr '\n' '\0')
    mapfile -d '' -t context_values < <(extract_contexts <"$todo_file" | tr '\n' '\0')

    projects="$(yad_combo_values blank "${project_values[@]}")"
    contexts="$(yad_combo_values blank "${context_values[@]}")"
    priority="$(priority_combo_values_legacy)"

    if ! out_string=$(yad \
        --form \
        --title="todo.txt entry" \
        --date-format="%Y-%m-%d" \
        --width=400 \
        --center \
        --window-icon=gtk-info \
        --borders=3 \
        --field="Task" "New_Task" \
        --field="Context:CBE" "$contexts" \
        --field="Project:CBE" "$projects" \
        --field="Priority:CBE" "$priority" \
        --field="Due Date::DT"); then
        exit 0
    fi

    new_task="$(printf '%s' "$out_string" | sed "s/'/’/g" | sed 's/"/”/g' | awk -F '|' '{print $1}')"
    if [[ "$new_task" == "New_Task" || -z "$new_task" ]]; then
        printf 'Task not edited; exiting\n'
        exit 88
    fi

    new_context="$(printf '%s' "$out_string" | awk -F '|' '{print $2}')"
    if [[ -n "$new_context" ]]; then
        new_context="@${new_context}"
    fi

    new_project="$(printf '%s' "$out_string" | awk -F '|' '{print $3}')"
    if [[ -n "$new_project" ]]; then
        new_project="+${new_project}"
    fi

    new_priority="$(printf '%s' "$out_string" | awk -F '|' '{print $4}')"
    if [[ -n "$new_priority" ]]; then
        new_priority="(${new_priority})"
    fi

    new_date="$(printf '%s' "$out_string" | awk -F '|' '{print $5}')"
    task_string=$(printf '/usr/bin/todo-txt add "%s %s %s %s due:%s"' \
        "$new_priority" \
        "$new_task" \
        "$new_context" \
        "$new_project" \
        "$new_date")
    eval "$task_string"
}

todoman_mode() {
    local selected_list="${1:-}"
    local out_string
    local new_list
    local new_task
    local new_context
    local new_project
    local new_priority
    local new_date
    local summary_text
    local list_values
    local contexts
    local projects
    local -a todo_args
    local -a list_array=()
    local -a project_values=()
    local -a context_values=()

    require_command todo
    require_command jq

    refresh_all_tasks_cache

    mapfile -t list_array < <(build_todoman_lists)
    [[ "${#list_array[@]}" -gt 0 ]] || die "no todoman lists found"

    if [[ -n "$selected_list" ]]; then
        if ! printf '%s\n' "${list_array[@]}" | grep -Fxq "$selected_list"; then
            die "unknown todoman list: $selected_list"
        fi
        list_values="$(yad_combo_values noblank "$selected_list" "${list_array[@]}")"
    else
        list_values="$(yad_combo_values noblank "${list_array[@]}")"
    fi

    mapfile -d '' -t context_values < <(
        jq -r '.[] | .summary, (.description // "")' "$ALL_TASKS_CACHE_FILE" \
            | extract_contexts \
            | tr '\n' '\0'
    )
    mapfile -d '' -t project_values < <(
        jq -r '.[] | .summary, (.description // "")' "$ALL_TASKS_CACHE_FILE" \
            | extract_projects \
            | tr '\n' '\0'
    )

    contexts="$(yad_combo_values blank "${context_values[@]}")"
    projects="$(yad_combo_values blank "${project_values[@]}")"

    if ! out_string=$(yad \
        --form \
        --title="Task entry" \
        --date-format="%Y-%m-%d" \
        --width=480 \
        --center \
        --window-icon=gtk-info \
        --borders=3 \
        --field="List:CBE" "$list_values" \
        --field="Task" "New_Task" \
        --field="Context:CBE" "$contexts" \
        --field="Project:CBE" "$projects" \
        --field="Priority:CBE" "$(priority_combo_values_todoman)" \
        --field="Due Date::DT"); then
        exit 0
    fi

    new_list="$(printf '%s' "$out_string" | awk -F '|' '{print $1}')"
    new_task="$(printf '%s' "$out_string" | sed "s/'/’/g" | sed 's/"/”/g' | awk -F '|' '{print $2}')"
    new_context="$(printf '%s' "$out_string" | awk -F '|' '{print $3}')"
    new_project="$(printf '%s' "$out_string" | awk -F '|' '{print $4}')"
    new_priority="$(printf '%s' "$out_string" | awk -F '|' '{print $5}')"
    new_date="$(printf '%s' "$out_string" | awk -F '|' '{print $6}')"

    if [[ -z "$new_list" ]]; then
        printf 'No list selected; exiting\n'
        exit 88
    fi

    if [[ "$new_task" == "New_Task" || -z "$new_task" ]]; then
        printf 'Task not edited; exiting\n'
        exit 88
    fi

    summary_text="$(build_summary_text "$new_task" "$new_context" "$new_project")"

    todo_args=(new --list "$new_list")
    if [[ -n "$new_priority" && "$new_priority" != "none" ]]; then
        todo_args+=(--priority "$new_priority")
    fi
    if [[ -n "$new_date" ]]; then
        todo_args+=(--due "$new_date")
    fi

    todo_cmd "${todo_args[@]}" "$summary_text"
}

main() {
    local first_arg="${1:-}"
    local todo_file=""

    require_command yad

    if [[ -n "$first_arg" && -f "$first_arg" ]]; then
        todo_file="$first_arg"
    elif command -v todo >/dev/null 2>&1 && todoman_list_exists "$first_arg"; then
        todoman_mode "$first_arg"
        exit 0
    elif [[ -n "${TODO_FILE:-}" && -f "${TODO_FILE}" ]]; then
        todo_file="$TODO_FILE"
    fi

    if [[ -n "$todo_file" ]]; then
        legacy_mode "$todo_file"
        exit 0
    fi

    todoman_mode "$first_arg"
}

main "$@"
