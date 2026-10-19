# Helpers for the tests that read the arguments recorded by the fake herdr.

# Puts every value that the fake herdr received for the option into the values array.
herdr_option_values() {
  local args=() arg i
  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < "$FAKE_HERDR_RECORD/args"
  values=()
  for ((i = 0; i + 1 < ${#args[@]}; i++)); do
    if [[ ${args[i]} == "$1" ]]; then
      values+=("${args[i + 1]}")
    fi
  done
}

# Prints how many times the fake herdr received the option.
herdr_option_count() {
  herdr_option_values "$1"
  echo "${#values[@]}"
}

# Succeeds when the fake herdr received the option with the value.
herdr_received() {
  local value
  herdr_option_values "$1"
  for value in "${values[@]}"; do
    [[ $value == "$2" ]] && return 0
  done
  return 1
}

# Prints the value of the environment variable that the fake herdr received with --env.
# Fails when the variable was not passed.
herdr_env_value() {
  local value
  herdr_option_values --env
  for value in "${values[@]}"; do
    if [[ $value == "$1="* ]]; then
      echo "${value#"$1="}"
      return 0
    fi
  done
  return 1
}
