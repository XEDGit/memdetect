# malloc_wrapper
<img src="https://img.shields.io/badge/Tools-finished-brightgreen)" />
This is a shell script to compile your file or project with a wrapper of malloc() and free() which is going to help you debugging, you can also use it in combination with ‘leaks malloc_debug’

## Info:

### Platform:

 - MacOS 🍏

### Enviroment:

 - gcc

### Output file:

 - malloc_debug

## Setup:

### Adding malloc_wrapper to your $PATH:
You can add this program to your $PATH by executing this command

```console
./malloc_wrapper --add-path
```
from now on you can just type `malloc_wrapper` in your terminal from any folder in the system!

### Makefile integration:
You can integrate this program with Makefile by executing this command in your Makefile path

```shell
echo >> ./Makefile '
malloc_wrapper:
    /path/to/malloc_wrapper.sh --d /path/to/project # --flags $(YOUR_FLAGS) $(YOUR_LIBS) $(YOUR_HEADERS)'
```

## Usage:

You can use this executable for compiling single files, multiple files or entire projects.

### Flags:

 - #### Mandatory (choose only one):

   * `--d directory_path`: Specify the path of your project directory

   * `--f file_path0 file_path...`: Specify one or more files to compile with the wrapper
   
 - #### Optional:

   - `--e folder_to_exclude_name`: Specify a folder which is inside the `--d directory_path` but you want to exclude from compiling

   - `--flags flag0 flag...`: Specify flags to use when compiling with gcc

   - `--a arg0 arg...`: Specify arguments to run with executable

 - ##### --fail:

   - `--fail malloc_to_fail_number`: Specify which malloc should fail (return 0), 1 will fail first malloc and so on

   - `--fail all`: Start a loop to compile your code and run it failing 1st malloc on 1st execution, 2nd on 2nd execution and so on
 
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

    ./malloc_wrapper.sh --d .. --flags -Isrc/ft_printf -Iincludes -lreadline -L/Users/XEDGit/.brew/opt/readline/lib -I/Users/XEDGit/.brew/opt/readline/include --e examples 

## Understanding the output:

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

    Output:
    (MALLOC_WRAPPER) start - main allocated 3 bytes at 0x6000010b4040
    (MALLOC_WRAPPER) main - strdup allocated 3 bytes at 0x6000010b4050
    (MALLOC_FAIL) main - ft_strdup malloc num 3 failed
    (FREE_WRAPPER) start - main free 0x6000010b4050

 - `(MALLOC_WRAPPER)`:
everytime a malloc happens this will be printed on the stdout, with the last two functions in the stack at the happening of malloc(), the amount of bytes and the address allocated
   
 - `(MALLOC_FREE)`:
everytime a free happens this will be printed on the stdout, with the last two functions in the stack at the happening of malloc() and the address freed

 - `(MALLOC_FAIL)`:
Every time your program executes the value of `--fail` times a malloc() this will be printed on the stdout with the  last two functions in the stack at the happening of malloc()

There is also a leak report at the end of your program, "Malloc calls" doesn't include failed malloc

    (MALLOC_REPORT)
       Malloc calls: 2
       Failed malloc: 1
       Free calls: 1
       Free calls to 0x0: 0
    Leaks at exit:
    From main of size 3 at address 0x6000003b4040
