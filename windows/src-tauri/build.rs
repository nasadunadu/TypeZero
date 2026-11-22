fn main() {
    let target_is_windows =
        std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows");

    // On real Windows hosts (CI / local Windows dev), run strict tauri_build::build() with full winres embedding.
    // On non-Windows hosts running `cargo check --target x86_64-pc-windows-msvc`, allow skipping `llvm-rc`
    // after Tauri finishes generating capabilities and env vars so Win32 code can be fully type-checked on macOS/Linux.
    if cfg!(not(target_os = "windows")) && target_is_windows {
        let _ = std::panic::catch_unwind(tauri_build::build);
    } else {
        tauri_build::build();
    }
}
