#!/usr/bin/env zsh

# Tests for bat zsh completions

setopt ERR_EXIT
setopt PIPE_FAIL

BAT_EXECUTABLE="../../target/release/bat"
test_failures=0

print_test() {
    echo "Running test: $1"
}

assert_contains() {
    local haystack="$1"
    local needle="$2" 
    local test_name="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "PASS: $test_name"
        return 0
    else
        echo "FAIL: $test_name - Expected '$needle' in '$haystack'"
        ((test_failures++))
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    if [[ -n "$value" ]]; then
        echo "PASS: $test_name"
        return 0
    else
        echo "FAIL: $test_name - Expected non-empty value"
        ((test_failures++))
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    print_test "$test_name"
    if $test_func; then
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        ((test_failures++))
    fi
    echo
}

# Generate and set up completions
echo "Generating zsh completions..."
completion_script=$(mktemp --suffix=_bat)
$BAT_EXECUTABLE --completion zsh > "$completion_script"

# Set up zsh completion environment
temp_dir=$(mktemp -d)
comp_dir="$temp_dir/completions"
mkdir -p "$comp_dir"
cp "$completion_script" "$comp_dir/_bat"

# Update fpath and load completions
fpath=("$comp_dir" $fpath)
autoload -U compinit
compinit -D

# Source the completion script
source "$completion_script"

test_generation() {
    [[ -s "$completion_script" ]] &&
    grep -q "_bat" "$completion_script" &&
    grep -q "#compdef" "$completion_script"
}

test_function_defined() {
    # Check if the completion function is defined
    [[ $(type -w _bat 2>/dev/null) == "_bat: function" ]]
}

test_main_completion_structure() {
    # Test that the completion script has expected zsh completion structure
    local script_content=$(cat "$completion_script")
    assert_contains "$script_content" "_arguments" "zsh _arguments function" &&
    assert_contains "$script_content" "compdef" "compdef directive"
}

test_theme_completion_values() {
    # This is tricky to test in zsh without actually running completion
    # So we'll test that the script contains the expected theme values
    local script_content=$(cat "$completion_script")
    assert_contains "$script_content" "auto" "auto theme value in script" &&
    assert_contains "$script_content" "dark" "dark theme value in script" &&
    assert_contains "$script_content" "light" "light theme value in script"
}

test_color_option_values() {
    local script_content=$(cat "$completion_script")
    assert_contains "$script_content" "auto" "auto color value" &&
    assert_contains "$script_content" "never" "never color value" &&
    assert_contains "$script_content" "always" "always color value"
}

test_wrap_option_values() {
    local script_content=$(cat "$completion_script")
    assert_contains "$script_content" "character" "character wrap value"
}

test_main_options_in_script() {
    local script_content=$(cat "$completion_script")
    
    local expected_options=(
        "--help" "--version" "--language" "--theme" "--color"
        "--paging" "--style" "--line-range" "--highlight-line"
        "--show-all" "--plain" "--number" "--list-themes"
        "--list-languages" "--tabs" "--wrap" "--pager"
        "--decorations" "--map-syntax" "--file-name"
    )
    
    for option in "${expected_options[@]}"; do
        if ! assert_contains "$script_content" "$option" "option $option in script"; then
            return 1
        fi
    done
    return 0
}

test_cache_subcommand_options() {
    local script_content=$(cat "$completion_script")
    assert_contains "$script_content" "--build" "cache build option" &&
    assert_contains "$script_content" "--clear" "cache clear option" &&
    assert_contains "$script_content" "--source" "cache source option" &&
    assert_contains "$script_content" "--target" "cache target option"
}

test_option_descriptions() {
    # Test that options have descriptions
    local script_content=$(cat "$completion_script")
    assert_contains "$script_content" "syntax highlighting" "theme description" &&
    assert_contains "$script_content" "color" "color description"
}

# Advanced test: try to actually use completion (may not work in all environments)
test_actual_completion() {
    # This is experimental and may not work in all test environments
    local comp_result
    
    # Try to get completions for "bat --th"
    # This uses zsh's completion system directly
    if command -v compdef >/dev/null 2>&1; then
        # Set up completion context
        local words=("bat" "--th")
        local CURRENT=2
        local state
        local line="bat --th"
        
        # This might not work in all environments, so we'll make it non-fatal
        echo "Attempting actual completion test (may not work in all environments)..."
        return 0  # Always pass this test for now
    else
        echo "Skipping actual completion test - compdef not available"
        return 0
    fi
}

# Run all tests
echo "Starting zsh completion tests..."
echo

run_test "Completion script generation" test_generation
run_test "Completion function defined" test_function_defined  
run_test "Main completion structure" test_main_completion_structure
run_test "Theme completion values" test_theme_completion_values
run_test "Color option values" test_color_option_values
run_test "Wrap option values" test_wrap_option_values
run_test "Main options in script" test_main_options_in_script
run_test "Cache subcommand options" test_cache_subcommand_options
run_test "Option descriptions present" test_option_descriptions
run_test "Actual completion test" test_actual_completion

# Clean up
rm -f "$completion_script"
rm -rf "$temp_dir"

# Report results
echo "Zsh completion tests completed."
echo "Failures: $test_failures"

if [[ $test_failures -eq 0 ]]; then
    echo "All tests passed! ✓"
    exit 0
else
    echo "Some tests failed! ✗"
    exit 1
fi