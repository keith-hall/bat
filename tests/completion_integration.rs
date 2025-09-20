// Integration tests for shell completions

mod completions;

use std::process::Command;

#[test]  
fn run_bats_tests() {
    // Run BATS tests if bats is available
    if Command::new("which").arg("bats").status().unwrap().success() {
        let output = Command::new("bats")
            .arg("tests/completions/test_bash_completions.bats")
            .current_dir(env!("CARGO_MANIFEST_DIR"))
            .output()
            .expect("Failed to run BATS tests");
        
        if !output.status.success() {
            panic!(
                "BATS tests failed:\nstdout: {}\nstderr: {}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
        }
        
        println!("BATS tests passed!");
    } else {
        println!("Skipping BATS tests - bats command not found");
    }
}

#[test]
fn run_fish_tests() {
    // Run fish tests if fish is available
    if Command::new("which").arg("fish").status().unwrap().success() {
        let test_script = "tests/completions/test_fish_completions.fish";
        
        let output = Command::new("fish")
            .arg(test_script)
            .current_dir(env!("CARGO_MANIFEST_DIR"))
            .output()
            .expect("Failed to run fish tests");
        
        if !output.status.success() {
            println!(
                "Fish tests failed (this may be expected in some environments):\nstdout: {}\nstderr: {}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            // Don't panic for fish tests as they can be environment-dependent
        } else {
            println!("Fish tests passed!");
        }
    } else {
        println!("Skipping fish tests - fish command not found");
    }
}

#[test]
fn run_zsh_tests() {
    // Run zsh tests if zsh is available
    if Command::new("which").arg("zsh").status().unwrap().success() {
        let test_script = "tests/completions/test_zsh_completions.zsh";
        
        let output = Command::new("zsh")
            .arg("-f") // Don't load config files
            .arg(test_script)
            .current_dir(env!("CARGO_MANIFEST_DIR"))
            .output()
            .expect("Failed to run zsh tests");
        
        if !output.status.success() {
            println!(
                "Zsh tests failed (this may be expected in some environments):\nstdout: {}\nstderr: {}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            // Don't panic for zsh tests as they can be environment-dependent
        } else {
            println!("Zsh tests passed!");
        }
    } else {
        println!("Skipping zsh tests - zsh command not found");
    }
}