# malloc_wrapper
<img src="https://img.shields.io/badge/Tools-debug-blueviolet" />
A shell script to compile your file or project with a wrapper of malloc() and free(), which will help you understand your memory-management and debug better!

## Info:

### Platform:

  - 🍏 <img src="https://img.shields.io/badge/MacOs-working-brightgreen" />

  - 🐧 <img src="https://img.shields.io/badge/Linux-working-brightgreen" />

  - 🪟 <img src="https://img.shields.io/badge/Windows-working-brightgreen" /> **using WSL**

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
    /path/to/malloc_wrapper.sh /path/to/project $(GCC_FLAGS) # add malloc_wrapper flags here'
```

## Run:

You can either run malloc_wrapper on **files** by specifying their name, or with a **directory path**. If you insert a directory path every .c file inside the directory is gonna be compiled, to exclude some sub-folder use the `-e` flag

### Usage:
    ./malloc_wrapper.sh { <directory_path> | <file> [<file1...>] } [<gcc_flags>] [optional flags]

### Flags:

 - #### Compiling:

   - `-fl` `--flags` flag0 flag1...: Another way to specify flags to use when compiling with gcc
   
   - `-e` `--exclude` folder_name: Specify a folder inside the `directory_path` which gets excluded from compiling

 - #### Executing:
   
   - `-a` `--args` arg0 arg1...: Specify arguments to run with the executable


 - #### Fail (Use only one):

   - `-fail` number: Specify which malloc call should fail (return 0), 1 will fail first malloc and so on

   - `-fail` all: Adding this flag will fail all the malloc calls

   - `-fail` loop start_from: Your code will be compiled and ran in a loop, failing the 1st malloc call on the 1st execution, the 2nd on the 2nd            execution and so on. If you specify a number after `loop` it will start by failing `start_from` malloc and continue

 - #### Output:

   - `-il` `--include-lib`: Adding this flag will include in the output the library name from where the first shown function have been called

   - `-ie` `--include-ext`: Adding this flag will include in the output the calls to malloc and free from outside your source files

   - `-ix` `--include-xmalloc`: Adding this flag will include in the output the calls to xmalloc and xrealloc

   - `-nr` `--no-report`: Doesn't display the leaks report at the program exit

   - `-fi` `--filter` arg0 arg1...: Filter out results from the wrapper output if substring `arg` is found inside the output line

 - #### Output files:

   - `-p` `--preserve`: Adding this flag will mantain the executable output files

 - #### Program settings:

   - `-lb` `--leaks-buff` size: Specify the size of the leaks report buffer, standard is 10000 (use only if the output tells you to)
     
   - `-h` `--help`: Display help message
 
   - `--add-path`: adds malloc_wrapper to a $PATH of your choice

   
 All the optional flags will be added to the gcc command in writing order

### Examples:

#### Run with single file

    ./malloc_wrapper.sh ft_split.c
   
#### Run with multiple files

    ./malloc_wrapper.sh ft_split.c ft_strlen.c

#### Run with project folder

    ./malloc_wrapper.sh ..

#### Run with options

    ./malloc_wrapper.sh shell/ -lreadline -L~/.brew/opt/readline/lib -I~/.brew/opt/readline/include -fail loop --filter rl_ -e examples

## Understanding the output:

### Reference:

 - `(MALLOC_WRAPPER)`:
    - for each malloc call, it is printed on the stdout, with the last two functions in the stack, the amount of bytes and the address allocated
   
 - `(FREE_WRAPPER)`:
    - for each free call, it is printed on the stdout, with the last two functions in the stack and the address freed

 - `(MALLOC_FAIL)`:
    - when a malloc call gets failed by the `-fail` flag it will be printed on the stdout with the last two functions in the stack

 - `(MALLOC_ERROR)`:
    - This means the program didn't have enough buffer size for storing malloc calls, use the flag `--leaks-buff` ot `-lb` with a bigger value than default (10000) to fix this

After your program exits a leak report will be printed. 

**⚠️WARNING:  
if you use exit() all the addresses which have a reference stored in the stack gets freed automatically, but the report will still include them**

### Example:

#### example.c:

```c
#include <stdlib.h>
#include <string.h>

int main(void)
{
  char *str1, *str2, *str3;

  str1 = malloc(3);
  str1[0] = 'e';
  str1[1] = 'x';
  str1[2] = '\0';
  str2 = strdup(str1);
  str3 = strdup(str2);
  free(str2);
  return (0);
}
```

#### Output:

```console
# With malloc_wrapper in $PATH
xedgit@pc:~ $ malloc_wrapper example.c -fail 3
```

    DYLD_INSERT_LIBRARIES=./fake_malloc.dylib ./malloc_debug:
    (MALLOC_WRAPPER) start -> main allocated 3 bytes at 0x7fa643c03590
    (MALLOC_WRAPPER) main -> strdup allocated 3 bytes at 0x7fa643c03850
    (MALLOC_FAIL)    main -> strdup malloc num 3 failed
    (FREE_WRAPPER)   start -> main free 0x7fa643c03850
    (MALLOC_REPORT)
            Malloc calls: 2
            Free calls: 1
            Free calls to 0x0: 0
    Leaks at exit:
    1)      From main of size 3 at address 0x7fa643c03590   Content: "ex"
    Total leaks: 1
