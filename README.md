# malloc_wrapper

This is a shell script to compile your file or project with a wrapper of malloc() and free() which is gonna tell you at any point of your program
which function in calling malloc or free and which address is getting allocated or freed, you can use it in combination with 'leaks' to figure out which variable is leaking.

## Info:

### Platform(s):

  - MacOS 🍏


## Usage

You can use this executable for compiling single files, multiple files or entire projects.

### Flags

  #### Mandatory
  
    --d directory_path: Specify the path of your project directory
  
  or
  
    --f file_path0 file_path...: Specify one or more files to compile with the wrapper
    
  #### Optional
  
    --e folder_to_exclude_name: Specify a folder which is inside the directory_path but you want to exclude from compiling (useful only with --d option)
    
    --flags flag0 flag...: Specify flags to use when compiling with gcc

    --fail malloc_to_fail_index: Specify which malloc should fail (return 0), 1 will fail first malloc and so on 
    
    --a arg0 arg...: Specify arguments to run with executable

    
  All the optional flags will be added to the gcc command in writing order

### Examples:

#### Run with single file

    ./malloc_wrapper.sh --f ft_split.c
    
#### Run with multiple file

    ./malloc_wrapper.sh --f ft_split.c ft_strlen.c

#### Run with project folder

    ./malloc_wrapper.sh --d minitalk

#### Run with options

    ./malloc_wrapper.sh --d . --flags -I src/ft_printf -Iincludes -lreadline -L/Users/XEDGit/.brew/opt/readline/lib -I/Users/XEDGit/.brew/opt/readline/include --e examples

## Understanding the output:

The output will present like

    (MALLOC_WRAPPER) semicolon_handle - ft_split allocated 16 bytes at 0x6000010b4040
    (MALLOC_WRAPPER) ft_split - copy_word allocated 5 bytes at 0x6000010b4050
    (MALLOC_WRAPPER) heredoc_check - heredoc_init allocated 8 bytes at 0x6000010b4060
    (MALLOC_FAIL) lexer - ft_strdup malloc num 4 failed
    (FREE_WRAPPER) error_free2dint/free2dint free 0x0
    (FREE_WRAPPER) error_free2dint/free2dint free 0x6000010b4060
    (FREE_WRAPPER) semicolon_handle/free2d free 0x0
    (FREE_WRAPPER) semicolon_handle/free2d free 0x6000010b4050
    (FREE_WRAPPER) semicolon_handle/free2d free 0x6000010b4040

  - (MALLOC_WRAPPER):
everytime a malloc happens this will be printed on the stdout, with the last two functions in the stack at the happening of malloc(), the amount of bytes and the address allocated
    
  - (MALLOC_FREE):
everytime a free happens this will be printed on the stdout, with the last two functions in the stack at the happening of malloc() and the address freed

  - (MALLOC_FAIL):
everytime your program will execute the value of --fail times a malloc() this will be printed on the stdout with the  last two functions in the stack at the happening of malloc()

## Makefile integration:
You can integrate this program with Makefile by filling this template and executing this command in your Makefile path

    cat << EOF >> Makefile
    malloc_wrapper:
        /path/to/malloc_wrapper.sh --d /path/to/project --flags $(YOUR_LIBS) $(YOUR_HEADERS)
    EOF


## Consider adding it to your $PATH so you can run it whitout having to move the scipt everytime!
