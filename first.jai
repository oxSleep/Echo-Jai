#import "Basic";
#import "Compiler";

#run
{
    set_build_options_dc(.{do_output = false});

    workspace := compiler_create_workspace("Echo");
    options   := get_build_options(workspace);

    options.output_executable_name = "main";
    options.output_type = .EXECUTABLE;
    options.output_path = ".build";
    options.text_output_flags = 0;

    module_path: [..] string;
    array_add(*module_path, ..options.import_path);
    array_add(*module_path, "src/");
    options.import_path = module_path;

    set_build_options(options, workspace);
    add_build_file("src/main.jai", workspace);
}
