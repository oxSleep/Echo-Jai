#run {
    set_build_options_dc(.{do_output = false});

    workspace := compiler_create_workspace("Echo");
    options   := get_build_options(workspace);

    debug        := true;
    should_clear := false;
    should_run   := false;

    for options.compile_time_command_line {
        if it == {
            case "release";
                debug = false;
            case "run";
                should_run = true;
            case "clear";
                should_clear = true;
        }
    }

    if should_clear {
        delete_directory(OUTPUT_PATH);
        log("Clearing % directory.\n", OUTPUT_PATH);
    }

    if debug log("Debug build.\n");
    else {
        set_optimization(*options, .OPTIMIZED);
        options.stack_trace = false;
        log("Release build.\n");
    }

    options.output_executable_name = EXECUTABLE_NAME;
    options.output_path            = OUTPUT_PATH;
    options.text_output_flags      = OUTPUT_TEXT;

    module_path: [..] string;
    array_add(*module_path, ..options.import_path);
    array_add(*module_path, MODULE_PATH);
    options.import_path = module_path;

    set_build_options(options, workspace);

    autorun_plugin: *Metaprogram_Plugin;
    if should_run {
        autorun_plugin = Autorun.get_plugin();
        autorun_plugin.workspace = workspace;
    }

    compiler_begin_intercept(workspace);
    add_build_file("src/main.jai", workspace);

    while true {
        message := compiler_wait_for_message();

        if autorun_plugin && autorun_plugin.message {
            autorun_plugin.message(autorun_plugin, message);
        }

        if message.kind == .COMPLETE break;
    }

    compiler_end_intercept(workspace);

    if autorun_plugin && autorun_plugin.shutdown {
        autorun_plugin.shutdown(autorun_plugin);
    }
}

EXECUTABLE_NAME :: "Echo";
OUTPUT_TEXT     :: 0;
OUTPUT_PATH     :: ".build";
MODULE_PATH     :: "src";

#import "Basic";
#import "File";
#import "Compiler";
Autorun :: #import "Autorun"(".exe");
