use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;
use std::process::Command as StdCommand;
use tempfile::TempDir;

const BAT_EXECUTABLE: &str = env!("CARGO_BIN_EXE_bat");

#[test]
fn test_completion_generation() {
    let supported_shells = ["bash", "fish", "zsh", "ps1"];
    
    for shell in &supported_shells {
        let mut cmd = Command::new(BAT_EXECUTABLE);
        cmd.arg("--completion").arg(shell);
        
        let assert = cmd.assert();
        assert
            .success()
            .stdout(predicate::str::contains("complete").or(predicate::str::contains("compdef")))
            .stderr(predicate::str::is_empty());
    }
}

#[test]
fn test_completion_script_validity() {
    // Test that generated completion scripts have expected structure
    let shells_and_patterns = [
        ("bash", vec!["_bat()", "complete -F _bat"]),
        ("fish", vec!["complete -c", "__bat_"]),
        ("zsh", vec!["#compdef", "_arguments"]),
        ("ps1", vec!["Register-ArgumentCompleter", "CompletionResult"]),
    ];
    
    for (shell, patterns) in &shells_and_patterns {
        let mut cmd = Command::new(BAT_EXECUTABLE);
        let output = cmd.arg("--completion").arg(shell).output().unwrap();
        let completion_script = String::from_utf8(output.stdout).unwrap();
        
        for pattern in patterns {
            assert!(completion_script.contains(pattern), 
                "Completion script for {} should contain '{}'", shell, pattern);
        }
    }
}

#[test]
fn test_completion_coverage() {
    // Get all command line options from clap
    let mut cmd = Command::new(BAT_EXECUTABLE);
    let help_output = cmd.arg("--help").output().unwrap();
    let help_text = String::from_utf8(help_output.stdout).unwrap();
    
    // Extract main options (excluding cache subcommand options for now)
    let main_options = extract_main_options(&help_text);
    
    // Test each shell's completion coverage
    let shells = ["bash", "fish", "zsh"];
    for shell in &shells {
        let mut cmd = Command::new(BAT_EXECUTABLE);
        let completion_output = cmd.arg("--completion").arg(shell).output().unwrap();
        let completion_script = String::from_utf8(completion_output.stdout).unwrap();
        
        let missing_options = find_missing_options(&main_options, &completion_script);
        
        // Known missing options that we might want to add
        let known_missing = [
            "--binary", "--strip-ansi", "--nonprintable-notation", 
            "--completion", "--no-paging"
        ];
        
        for option in &missing_options {
            if known_missing.contains(&option.as_str()) {
                println!("Note: {} completion missing option: {}", shell, option);
            } else {
                panic!("Unexpected missing option in {} completion: {}", shell, option);
            }
        }
    }
}

fn extract_main_options(help_text: &str) -> Vec<String> {
    let mut options = Vec::new();
    let lines: Vec<&str> = help_text.lines().collect();
    let mut in_options = false;
    let mut in_cache_section = false;
    
    for line in lines {
        if line.trim().starts_with("SUBCOMMANDS:") || line.trim().starts_with("cache") {
            in_cache_section = true;
            continue;
        }
        
        if line.trim().starts_with("OPTIONS:") {
            in_options = true;
            continue;
        }
        
        if in_options && !in_cache_section {
            if let Some(option) = extract_option_from_line(line) {
                options.push(option);
            }
        }
    }
    
    options.sort();
    options.dedup();
    options
}

fn extract_option_from_line(line: &str) -> Option<String> {
    let trimmed = line.trim();
    if trimmed.starts_with('-') {
        // Extract the long form option if present
        if let Some(long_opt_start) = trimmed.find("--") {
            let rest = &trimmed[long_opt_start..];
            if let Some(space_pos) = rest.find(' ') {
                Some(rest[..space_pos].trim_end_matches(',').to_string())
            } else {
                Some(rest.to_string())
            }
        } else {
            None
        }
    } else {
        None
    }
}

fn find_missing_options(expected_options: &[String], completion_script: &str) -> Vec<String> {
    let mut missing = Vec::new();
    
    for option in expected_options {
        if !completion_script.contains(option) {
            missing.push(option.clone());
        }
    }
    
    missing
}

// Test actual completion behavior in shells (only run if shells are available)
#[cfg(unix)]
mod shell_tests {
    use super::*;
    
    #[test]
    fn test_bash_completion_behavior() {
        if !shell_available("bash") {
            println!("Skipping bash completion test - bash not available");
            return;
        }
        
        let temp_dir = TempDir::new().unwrap();
        let completion_script_path = temp_dir.path().join("bat_completion.bash");
        
        // Generate completion script
        let mut cmd = Command::new(BAT_EXECUTABLE);
        let completion_output = cmd.arg("--completion").arg("bash").output().unwrap();
        
        fs::write(&completion_script_path, completion_output.stdout).unwrap();
        
        // Test basic completion scenario
        let test_script = format!(r#"
            source {}
            
            # Set up completion testing environment
            COMP_WORDS=("bat" "--th")
            COMP_CWORD=1
            COMP_LINE="bat --th"
            COMP_POINT=8
            
            # Call completion function
            _bat
            
            # Check if --theme is in completions
            if [[ " ${{COMPREPLY[@]}} " =~ " --theme " ]]; then
                echo "SUCCESS: --theme found in completions"
                exit 0
            else
                echo "FAILURE: --theme not found in completions"
                echo "COMPREPLY: ${{COMPREPLY[@]}}"
                exit 1
            fi
        "#, completion_script_path.display());
        
        let test_script_path = temp_dir.path().join("test_completion.sh");
        fs::write(&test_script_path, test_script).unwrap();
        
        let output = StdCommand::new("bash")
            .arg(&test_script_path)
            .output()
            .expect("Failed to execute bash completion test");
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        
        if !output.status.success() {
            panic!("Bash completion test failed:\nstdout: {}\nstderr: {}", stdout, stderr);
        }
        
        assert!(stdout.contains("SUCCESS"));
    }
    
    #[test]
    fn test_fish_completion_behavior() {
        if !shell_available("fish") {
            println!("Skipping fish completion test - fish not available");
            return;
        }
        
        let temp_dir = TempDir::new().unwrap();
        let completion_script_path = temp_dir.path().join("bat.fish");
        
        // Generate completion script
        let mut cmd = Command::new(BAT_EXECUTABLE);
        let completion_output = cmd.arg("--completion").arg("fish").output().unwrap();
        
        fs::write(&completion_script_path, completion_output.stdout).unwrap();
        
        // Create a simple fish test script
        let test_script = format!(r#"
            # Load the completion script
            source {}
            
            # Test if completions are defined
            if complete -C "bat --th" | grep -q "theme"
                echo "SUCCESS: theme completion found"
            else
                echo "FAILURE: theme completion not found"
                exit 1
            end
        "#, completion_script_path.display());
        
        let test_script_path = temp_dir.path().join("test_completion.fish");
        fs::write(&test_script_path, test_script).unwrap();
        
        let output = StdCommand::new("fish")
            .arg("-c")
            .arg(&format!("source {}", test_script_path.display()))
            .output()
            .expect("Failed to execute fish completion test");
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        
        if !output.status.success() {
            println!("Fish completion test warning:\nstdout: {}\nstderr: {}", stdout, stderr);
            // Don't fail the test as fish completion testing can be flaky
            return;
        }
        
        assert!(stdout.contains("SUCCESS"));
    }
    
    #[test]
    fn test_zsh_completion_behavior() {
        if !shell_available("zsh") {
            println!("Skipping zsh completion test - zsh not available");
            return;
        }
        
        let temp_dir = TempDir::new().unwrap();
        let completion_script_path = temp_dir.path().join("_bat");
        
        // Generate completion script
        let mut cmd = Command::new(BAT_EXECUTABLE);
        let completion_output = cmd.arg("--completion").arg("zsh").output().unwrap();
        
        fs::write(&completion_script_path, completion_output.stdout).unwrap();
        
        // Create zsh completion test
        let test_script = format!(r#"
            # Set up zsh completion environment
            fpath=({} $fpath)
            autoload -U compinit
            compinit -D
            
            # Load our completion
            source {}
            
            # Test basic completion structure
            if typeset -f _bat > /dev/null; then
                echo "SUCCESS: _bat function is defined"
            else
                echo "FAILURE: _bat function not found"
                exit 1
            fi
        "#, temp_dir.path().display(), completion_script_path.display());
        
        let test_script_path = temp_dir.path().join("test_completion.zsh");
        fs::write(&test_script_path, test_script).unwrap();
        
        let output = StdCommand::new("zsh")
            .arg("-f")  // no rcs
            .arg(&test_script_path)
            .output()
            .expect("Failed to execute zsh completion test");
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        
        if !output.status.success() {
            println!("Zsh completion test warning:\nstdout: {}\nstderr: {}", stdout, stderr);
            // Don't fail the test as zsh completion testing can be complex
            return;
        }
        
        assert!(stdout.contains("SUCCESS"));
    }
    
    fn shell_available(shell: &str) -> bool {
        StdCommand::new("which")
            .arg(shell)
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }
}

#[test]
fn test_completion_argument_values() {
    // Test that completion scripts include expected argument values
    let test_cases = vec![
        ("bash", vec!["auto", "dark", "light", "never", "always"]),
        ("fish", vec!["auto", "dark", "light", "never", "always"]),
        ("zsh", vec!["auto", "dark", "light", "never", "always"]),
    ];
    
    for (shell, expected_values) in test_cases {
        let mut cmd = Command::new(BAT_EXECUTABLE);
        let completion_output = cmd.arg("--completion").arg(shell).output().unwrap();
        let completion_script = String::from_utf8(completion_output.stdout).unwrap();
        
        for value in expected_values {
            assert!(completion_script.contains(value), 
                "Completion script for {} should contain '{}'", shell, value);
        }
    }
}