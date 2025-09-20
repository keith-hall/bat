#!/usr/bin/env fish

# Tests for bat fish completions

set BAT_EXECUTABLE "../../target/release/bat"
set test_failures 0

function test_description
    echo "Running test: $argv"
end

function assert_contains
    set -l haystack $argv[1]
    set -l needle $argv[2]
    set -l test_name $argv[3]
    
    if not string match -q "*$needle*" "$haystack"
        echo "FAIL: $test_name - Expected '$needle' in '$haystack'"
        set test_failures (math $test_failures + 1)
        return 1
    else
        echo "PASS: $test_name"
        return 0
    end
end

function assert_not_empty
    set -l value $argv[1]
    set -l test_name $argv[2]
    
    if test -z "$value"
        echo "FAIL: $test_name - Expected non-empty value"
        set test_failures (math $test_failures + 1)
        return 1
    else
        echo "PASS: $test_name"
        return 0
    end
end

function run_test
    set -l test_name $argv[1]
    set -l test_func $argv[2]
    
    test_description "$test_name"
    if $test_func
        echo "✓ $test_name"
    else
        echo "✗ $test_name"
        set test_failures (math $test_failures + 1)
    end
    echo
end

# Generate and load completions
echo "Generating fish completions..."
set completion_script (mktemp --suffix=.fish)
$BAT_EXECUTABLE --completion fish > $completion_script

# Source the completion script
source $completion_script

function test_generation
    test -s $completion_script
    and string match -q "*complete -c*" (cat $completion_script)
end

function test_basic_option_completion
    set completions (complete -C "bat --th")
    assert_contains "$completions" "--theme" "theme option completion"
end

function test_theme_value_completion
    set completions (complete -C "bat --theme ")
    assert_contains "$completions" "auto" "auto theme value"
    and assert_contains "$completions" "dark" "dark theme value"
    and assert_contains "$completions" "light" "light theme value"
end

function test_color_value_completion  
    set completions (complete -C "bat --color ")
    assert_contains "$completions" "auto" "auto color value"
    and assert_contains "$completions" "never" "never color value"
    and assert_contains "$completions" "always" "always color value"  
end

function test_language_completion
    set completions (complete -C "bat --language rust")
    # Should have some completions for rust (Rust language)
    assert_not_empty "$completions" "language completion not empty"
end

function test_paging_completion
    set completions (complete -C "bat --paging ")
    assert_contains "$completions" "auto" "auto paging value"
    and assert_contains "$completions" "never" "never paging value"
    and assert_contains "$completions" "always" "always paging value"
end

function test_wrap_completion
    set completions (complete -C "bat --wrap ")
    assert_contains "$completions" "auto" "auto wrap value"
    and assert_contains "$completions" "never" "never wrap value"
    and assert_contains "$completions" "character" "character wrap value"
end

function test_style_completion
    set completions (complete -C "bat --style ")
    assert_contains "$completions" "default" "default style value"
    and assert_contains "$completions" "plain" "plain style value"
    and assert_contains "$completions" "full" "full style value"
end

function test_cache_subcommand
    set completions (complete -C "bat cache --")
    assert_contains "$completions" "--build" "cache build option"
    and assert_contains "$completions" "--clear" "cache clear option"
end

function test_file_completion
    # Create a test file
    touch test_file.txt
    
    set completions (complete -C "bat test_")
    set result (assert_contains "$completions" "test_file.txt" "file completion")
    
    # Clean up
    rm -f test_file.txt
    return $result
end

function test_main_options_present
    set completions (complete -C "bat --")
    
    set expected_options \
        "--help" "--version" "--language" "--theme" "--color" \
        "--paging" "--style" "--line-range" "--highlight-line" \
        "--show-all" "--plain" "--number" "--list-themes" \
        "--list-languages" "--tabs" "--wrap" "--pager"
    
    for option in $expected_options
        if not assert_contains "$completions" "$option" "main option $option present"
            return 1
        end
    end
    return 0
end

# Run all tests
echo "Starting fish completion tests..."
echo

run_test "Completion script generation" test_generation
run_test "Basic option completion" test_basic_option_completion  
run_test "Theme value completion" test_theme_value_completion
run_test "Color value completion" test_color_value_completion
run_test "Language completion" test_language_completion
run_test "Paging completion" test_paging_completion
run_test "Wrap completion" test_wrap_completion
run_test "Style completion" test_style_completion
run_test "Cache subcommand completion" test_cache_subcommand
run_test "File completion" test_file_completion
run_test "Main options present" test_main_options_present

# Clean up
rm -f $completion_script

# Report results
echo "Fish completion tests completed."
echo "Failures: $test_failures"

if test $test_failures -eq 0
    echo "All tests passed! ✓"
    exit 0
else
    echo "Some tests failed! ✗"
    exit 1
end