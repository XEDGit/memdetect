# malloc_wrapper

This is a shell script to compile your file or project with a wrapper of malloc() and free() which is gonna tell you at any point of your program
which function in calling malloc or free and which address is getting allocated or freed.

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
	--a arg0 arg...: Specify arguments to run with executable

    
  All the optional flags will be added to the gcc command in writing order
  
### Run with single file

    ./malloc_wrapper.sh -f ft_split.c
    
### Run with multiple file

    ./malloc_wrapper.sh -f ft_split.c -f ft_strlen.c

### Run with project folder

    ./malloc_wrapper.sh -d minitalk
    
    Output:
    gcc $(find minitalk -name '*.c') -rdynamic

### Run with options

    ./malloc_wrapper.sh -d . -I includes -e examples -I src/ft_printf -l readline -L ~/.brew/opt/readline/lib -I ~/.brew/opt/readline/include
