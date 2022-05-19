# malloc_wrapper
<img src="https://img.shields.io/badge/Tools-debug-blueviolet" />
This is a shell script to compile your file or project with a wrapper of malloc() and free(), which will help you understand your memory-management and debugging better!

## Info:

### Platform:

  - 🍏 <img src="https://img.shields.io/badge/MacOs-working-brightgreen" />


  - 🐧 <img src="https://img.shields.io/badge/Linux-working-brightgreen" />

### Enviroment:

  - 🖥️ <img src="https://img.shields.io/badge/C-gcc-blueviolet" />

### Output file:

  - 📄 malloc_debug


## Setup:

### Adding malloc_wrapper to your $PATH:
You can add this program to your $PATH by adding this flag

```console
./malloc_wrapper.sh --add-path
```
from now on you can just type `malloc_wrapper` in your terminal from any folder in the system!
 
### Makefile integration:
You can integrate this program with Makefile by executing this command in your Makefile path

```shell
echo >> ./Makefile '
mall_wrapper:
    /path/to/malloc_wrapper.sh --d /path/to/project # --flags $(YOUR_FLAGS) $(YOUR_LIBS) $(YOUR_HEADERS)'
```

## Usage:

You can use this executable for compiling single files, multiple files or entire projects.

### Flags:

 - #### Mandatory (choose only one):

   * `--d directory_path`: Specify the path of your project directory

   * `--f file_path0 file_path...`: Specify one or more files to compile with the wrapper
   
 - #### Optional:

   - `--e folder_to_exclude`: Specify a folder inside the `--d directory_path` which gets excluded from compiling

   - `--flags flag0 flag...`: Specify flags to use when compiling with gcc

   - `--filter arg`: Specify a string which will filter out results from the wrapper output if `arg` is in the calling function
   
   - `--a arg0 arg...`: Specify arguments to run with the executable

   - `--leaks-buff size`: Specify the size of the leaks report buffer, standard is 10000 (use only if the output tells you to)

 - ##### --fail (Use only one):

   - `--fail number`: Specify which malloc call should fail (return 0), 1 will fail first malloc and so on

   - `--fail all`: Adding this flag will fail all the malloc calls

   - `--fail loop`: Your code will be compiled and ran in a loop, failing the 1st malloc call on the 1st execution, the 2nd on the 2nd execution and so on
 
 - ##### --add-path: adds malloc_wrapper to a $PATH of your choice

   
 All the optional flags will be added to the gcc command in writing order

### Examples:

#### Run with single file

    ./malloc_wrapper.sh --f ft_split.c
   
#### Run with multiple files

    ./malloc_wrapper.sh --f ft_split.c ft_strlen.c

#### Run with project folder

    ./malloc_wrapper.sh --d minitalk

#### Run with options

    ./malloc_wrapper.sh --d .. --fail loop --filter rl_ --flags -Iincludes -lreadline -L/Users/XEDGit/.brew/opt/readline/lib -I/Users/XEDGit/.brew/opt/readline/include --e examples 

## Understanding the output:

### Before:

The optimal enviroment to run this wrapper is MacOS, since all the calls to malloc or free coming from outside the source files aren't redirected to the wrapper, it's possible that Linux is gonna have more noise of library functions calling malloc in the output in particular if you use libraries

### Reference:

 - `(MALLOC_WRAPPER)`:
    - for each malloc call, it is printed on the stdout, with the last two functions in the stack, the amount of bytes and the address allocated
   
 - `(FREE_WRAPPER)`:
    - for each free call, it is printed on the stdout, with the last two functions in the stack and the address freed

 - `(MALLOC_FAIL)`:
    - when a malloc call gets failed by the `--fail` flag it will be printed on the stdout with the last two functions in the stack

After your program exits a leak report will be printed

### Example:

#### Input:

```console
# With malloc_wrapper in $PATH
xedgit@pc:~ $ malloc_wrapper --f example.c --fail 3
```

```c
// example.c:

#include <stdlib.h>
#include <string.h>

char *my_strdup(char *str)
{
  char    *new;
  int     c;
  
  new = malloc(strlen(str) + 1);
  if (!new)
    return (0);
  c = 0;
  while (*str)
    new[c++] = *str++;
  new[c] = 0;
  return (new);
}

int main(void)
{
  char *str1, *str2, *str3;

  str1 = malloc(3);
  str1[0] = 'e';
  str1[1] = 'x';
  str1[2] = '\0';
  str2 = my_strdup(str1);
  str3 = my_strdup(str2);
  free(str2);
  return (0);
}
```

#### Output:
    
    (MALLOC_WRAPPER) start - main allocated 3 bytes at 0x6000010b4040
    (MALLOC_WRAPPER) main - strdup allocated 3 bytes at 0x6000010b4050
    (MALLOC_FAIL) main - ft_strdup malloc num 3 failed
    (FREE_WRAPPER) start - main free 0x6000010b4050
    (MALLOC_REPORT)
       Malloc calls: 2
       Free calls: 1
       Free calls to 0x0: 0
    Leaks at exit:
    1) From main of size 3 at address 0x6000003b4040
