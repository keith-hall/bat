#!/usr/bin/env bats

# Tests for bat bash completions using BATS (Bash Automated Testing System)

setup() {
    # Set up test environment
    export BAT_EXECUTABLE="../../target/release/bat"
    export COMPLETION_SCRIPT=$(mktemp)
    
    # Generate bash completion script
    $BAT_EXECUTABLE --completion bash > "$COMPLETION_SCRIPT"
    
    # Source the completion script
    source "$COMPLETION_SCRIPT"
    
    # Set up bash completion testing helpers
    export COMP_WORDS=()
    export COMP_CWORD=0
    export COMP_LINE=""
    export COMP_POINT=0
    export COMPREPLY=()
}

teardown() {
    # Clean up
    rm -f "$COMPLETION_SCRIPT"
}

# Helper function to test completions
test_completion() {
    local input="$1"
    local expected="$2"
    
    # Parse input into COMP_WORDS
    read -ra COMP_WORDS <<< "$input"
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMP_LINE="$input"
    COMP_POINT=${#COMP_LINE}
    
    # Clear previous results
    COMPREPLY=()
    
    # Call the completion function
    _bat
    
    # Check if expected completion is present
    local found=false
    for completion in "${COMPREPLY[@]}"; do
        if [[ "$completion" == "$expected" ]]; then
            found=true
            break
        fi
    done
    
    if ! $found; then
        echo "Expected '$expected' in completions, got: ${COMPREPLY[*]}" >&2
        return 1
    fi
}

@test "completion script is generated successfully" {
    [ -s "$COMPLETION_SCRIPT" ]
    grep -q "_bat()" "$COMPLETION_SCRIPT"
}

@test "basic option completion works" {
    test_completion "bat --th" "--theme"
}

@test "color option values are completed" {
    # Set up for value completion
    COMP_WORDS=("bat" "--color" "")
    COMP_CWORD=2
    COMP_LINE="bat --color "
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Check that color values are present
    [[ " ${COMPREPLY[*]} " =~ " auto " ]]
    [[ " ${COMPREPLY[*]} " =~ " never " ]]
    [[ " ${COMPREPLY[*]} " =~ " always " ]]
}

@test "theme option completion includes special values" {
    COMP_WORDS=("bat" "--theme" "")
    COMP_CWORD=2
    COMP_LINE="bat --theme "
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Check for special theme values
    [[ " ${COMPREPLY[*]} " =~ " auto " ]]
    [[ " ${COMPREPLY[*]} " =~ " dark " ]]
    [[ " ${COMPREPLY[*]} " =~ " light " ]]
}

@test "language completion works" {
    COMP_WORDS=("bat" "--language" "ru")
    COMP_CWORD=2
    COMP_LINE="bat --language ru"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Should complete to "rust" (or similar)
    local found_rust=false
    for completion in "${COMPREPLY[@]}"; do
        if [[ "$completion" =~ ^[Rr]ust ]]; then
            found_rust=true
            break
        fi
    done
    [ "$found_rust" = true ]
}

@test "file completion works for regular files" {
    # Create a test file
    touch "test_file.txt"
    
    COMP_WORDS=("bat" "test_")
    COMP_CWORD=1
    COMP_LINE="bat test_"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Should include the test file
    [[ " ${COMPREPLY[*]} " =~ " test_file.txt " ]]
    
    # Clean up
    rm -f "test_file.txt"
}

@test "cache subcommand completion works" {
    COMP_WORDS=("bat" "cache" "--bu")
    COMP_CWORD=2
    COMP_LINE="bat cache --bu"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Should complete to --build
    [[ " ${COMPREPLY[*]} " =~ " --build " ]]
}

@test "cache subcommand has all expected options" {
    COMP_WORDS=("bat" "cache" "--")
    COMP_CWORD=2
    COMP_LINE="bat cache --"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Check for cache-specific options
    [[ " ${COMPREPLY[*]} " =~ " --build " ]]
    [[ " ${COMPREPLY[*]} " =~ " --clear " ]]
    [[ " ${COMPREPLY[*]} " =~ " --source " ]]
    [[ " ${COMPREPLY[*]} " =~ " --target " ]]
}

@test "wrap option values are completed correctly" {
    COMP_WORDS=("bat" "--wrap" "")
    COMP_CWORD=2
    COMP_LINE="bat --wrap "
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Check wrap values
    [[ " ${COMPREPLY[*]} " =~ " auto " ]]
    [[ " ${COMPREPLY[*]} " =~ " never " ]]
    [[ " ${COMPREPLY[*]} " =~ " character " ]]
}

@test "style option allows comma-separated values" {
    COMP_WORDS=("bat" "--style" "header,")
    COMP_CWORD=2
    COMP_LINE="bat --style header,"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Should offer additional style options
    local has_grid=false
    for completion in "${COMPREPLY[@]}"; do
        if [[ "$completion" =~ grid ]]; then
            has_grid=true
            break
        fi
    done
    [ "$has_grid" = true ]
}

@test "all main options are present in completion" {
    COMP_WORDS=("bat" "--")
    COMP_CWORD=1
    COMP_LINE="bat --"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Test for some key options that should be present
    local expected_options=(
        "--help"
        "--version" 
        "--language"
        "--theme"
        "--color"
        "--paging"
        "--style"
        "--line-range"
        "--highlight-line"
        "--show-all"
        "--plain"
        "--number"
        "--list-themes"
        "--list-languages"
        "--file-name"
        "--diff"
        "--tabs"
        "--wrap"
        "--terminal-width"
        "--pager"
        "--map-syntax"
        "--decorations"
        "--italic-text"
        "--force-colorization"
        "--no-config"
        "--no-custom-assets"
        "--diagnostic"
        "--acknowledgements"
        "--config-dir"
        "--config-file"
        "--cache-dir"
        "--generate-config-file"
    )
    
    for option in "${expected_options[@]}"; do
        if [[ ! " ${COMPREPLY[*]} " =~ " ${option} " ]]; then
            echo "Missing option: $option" >&2
            echo "Available completions: ${COMPREPLY[*]}" >&2
            return 1
        fi
    done
}

@test "completion does not offer options that cause exit" {
    # Options like --help, --version should not prevent file completion
    COMP_WORDS=("bat" "--help" "some")
    COMP_CWORD=2
    COMP_LINE="bat --help some"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Should return early and not offer completions after --help
    [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "directory completion works for cache source/target" {
    # Create a test directory
    mkdir -p "test_dir"
    
    COMP_WORDS=("bat" "cache" "--source" "test_")
    COMP_CWORD=3
    COMP_LINE="bat cache --source test_"
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    
    _bat
    
    # Should complete to directory
    [[ " ${COMPREPLY[*]} " =~ " test_dir/" ]]
    
    # Clean up
    rmdir "test_dir"
}