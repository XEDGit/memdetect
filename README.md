Memdetect is a cross-platform shell script to compile and run your C or C++ project with a wrapper of malloc and free, which will help you understand your memory-management and find memory leaks.


It can also fail targeted malloc() calls at runtime, for military-grade stability!

## Platforms:

[<img src="https://img.shields.io/badge/Working-52CF44?style=for-the-badge&label=MacOS&logo=apple&logoColor=white" />](https://github.com/XEDGit/memdetect)

[<img src="https://img.shields.io/badge/Working-52CF44?style=for-the-badge&label=Linux&logo=linux&logoColor=white" />](https://github.com/XEDGit/memdetect)

[<img src="https://img.shields.io/badge/Compatible via WSL-52CF44?style=for-the-badge&label=Windows&logo=windows&logoColor=white" />](https://docs.microsoft.com/en-us/windows/wsl/install)

## Enviroment:

[<img src="https://img.shields.io/badge/GCC-00599C?style=for-the-badge&logo=c&logoColor=white" />](https://github.com/XEDGit/memdetect)
[<img src="https://img.shields.io/badge/G++-00599C?style=for-the-badge&logo=c%2B%2B&logoColor=white" />](https://github.com/XEDGit/memdetect)

## Setup:

### First run:
This program is made by a single bash script, so it doesn't need proper installation, to be able to run it just clone this repository and you're ready to test

```console
git clone https://github.com/XEDGit/memdetect.git
cd memdetect
./memdetect.sh
```

### Installation (adding to your $PATH):
You can add this program to your $PATH by using the option `--add-path`
```console
./memdetect.sh --add-path
```
from now on you can just type `memdetect` in your terminal from any folder in the system!
 
### Makefile integration:

The integrated Makefile tools will read and execute your current folder Makefile's first rule (or the one specified via -m)  
To run in makefile mode do not specify any directory or file before the memdetect options
```shell
memdetect # You can optionally add gcc/memdetect options
```
If you are having problems, try cleaning your target files, for example using `make fclean`

## Run:

Memdetect runs standard in **C mode**, to enable **C++ mode** use the `-+` option

### Usage:

    ./memdetect.sh { [ directory_paths | files ] [compiler_flags] [memdetect options] }

#### Description:
 1. **files** or **directory paths**: Only one of these types can be specified. If you insert a directory path, every .c or .cpp file inside the directory is gonna be compiled, to exclude one or more sub-folders use the `-e` option, if you don't insert this parameter the script will use the Makefile tools, see **Makefile intergration**
 2. **Compiler_flags**: all the options that need to be passed to the `gcc` or `g++` compiler, they can be specified as *flag1 flag2 ... flagN* ex: *-I include -g -O3*
 3. **memdetect options**: see below for list, they can be specified as *option1 option1_arg option2 ... optionN* ex: *-a arg -or -e example*

The arguments are all **optional**, but **positional**, which means you have to add them in the order specified by **Usage**

### Options:

 - #### Compiling:

   - `-fl | --flags <flag0> ... <flagn>`: Another way to specify options to pass to gcc for compilation
   
   - `-e | --exclude <folder name>`: Specify a sub-folder inside one of the `directory_paths` which is excluded from compilation

 - #### Executing:
   
   - `-a | --args <arg0> ... <argn>`: Specify arguments to run the executable with, use when your program reads the argv

   - `-n | --dry-run`: Run the program printing every command and without executing any


 - #### Fail malloc (Use one per command):

   - `-fail <number>`: Specify which malloc call should fail (return 0), 1 will fail first malloc, 2 the second and so on

   - `-fail <all>`: Adding this will fail all the malloc calls in the program

   - `-fail <loop> [<start>]`: This mode puts `memdetect -fail` in an infinite loop, failing the 1st malloc call on the 1st execution, the 2nd on the 2nd execution and so on incrementally. If you specify a number after `loop` it will start by failing the malloc call number `start` then `start + 1` and so on.

 - #### Output manipulation:

   - `-s | --show-calls`: Print info about the malloc or free calls

   - `-v | --verbose`: This option will cause memdetect to print the compilation commands

   - `-o | --output` filename: Removed for compatibility reasons, to archieve the same effect use stdout redirection with the terminal (memdetect ... > outfile)

   - `-il | --include-lib`: This option will include in the output the library name from where the first shown function have been called

   - `-ie | --include-ext`: This option will include in the output the calls to malloc and free from outside your source files.  
   *Watch out, some external functions will create confilct and crash your program if you intercept them, try to filter them out with `-fo`, but in most cases this option is overkill anyway*

   - `-ix | --include-xmalloc`: This option will include in the output the calls to xmalloc and xrealloc

   - `-nr | --no-report`: Doesn't display the leaks report at the program exit

   - `-fi | --filter-in <arg0> ... <argn>`: Show only results from memdetect output if substring `<arg>` is found inside the recent function stack

   - `-fo | --filter-out <arg0> ... <argn>`: Filter out results from memdetect output if substring `<arg>` is found inside the recent function stack

 - #### Output files:

   - `-p | --preserve`: This option will mantain the executable output files

 - #### Program settings:

    - `-+ | -++`: Use to run in C++ mode

    - `-u | --update`: Only works if memdetect is installed, updates the installed executable to the latest commit from github

   - `-lb | --leaks-buff <size>`: Specify the size of the leaks report buffer, standard is 10000 (use only if the output tells you to do so)

   - `-m | --make-rule <rule>`: Specify the rule to be executed when using makefile tools (no directory or file specified)
     
   - `-h | --help`: Display help message
 
   - `--add-path`: Installs memdetect, moving the executable into a $PATH folder of your choice 


 All the compiler flags will be added to the gcc command in writing order

### Examples:

#### Run with single file

    memdetect ft_split.c
   
#### Run with multiple files

    memdetect ft_split.c ft_strlen.c -I include

#### Run with project folder

    memdetect .

#### Run with project folder

    memdetect src lib -I include -I lib/include

#### Run with options

    memdetect shell/ -lreadline -L~/.brew/opt/readline/lib -I~/.brew/opt/readline/include -fail loop --filter-out rl_ -e examples

## Understanding the output:

### Reference:

All the output is printed following your program's runtime, so your output will be included in memdetect output and can be used as reference to distinguish between similar malloc calls, adding placeholder `printf` calls to your code can reveal itself very useful

 - `(MALLOC_WRAPPER N)`:
    - for each malloc call, this is printed on the stdout, N represents the index of the malloc call, with the last two functions in the stack, the amount of bytes requested and the memory address
   
 - `(FREE_WRAPPER)`:
    - for each free call, this is printed on the stdout, with the last two functions in the stack and the address freed

 - `(MALLOC_FAIL)`:
    - when a malloc call gets failed by the `-fail` option this will be printed on the stdout with the last two functions in the stack

 - `(MALLOC_ERROR)`:
    - when this is printed it means the program didn't have enough stack size for storing informations about your malloc calls, use the option `--leaks-buff` ot `-lb` with a bigger value than default (10000) to fix this

After your program exits a **Leaks at exit** section will be printed, it will contains the call index for every leaked address, which is the same as the one printed at runtime. 

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
# With memdetect in $PATH
xedgit@pc:~ $ memdetect example.c -s -fail 3
```

    ================= memdetect by XEDGit ==================
    gcc  example.c -rdynamic -o ./malloc_debug
    DYLD_INSERT_LIBRARIES=./fake_malloc.dylib ./malloc_debug:
    (MALLOC_WRAPPER 1) start -> main allocated 3 bytes at 0x137606df0
    (MALLOC_WRAPPER 2) main -> strdup allocated 3 bytes at 0x137606d70
    (MALLOC_FAIL)    main -> strdup malloc num 3 failed
    (FREE_WRAPPER)   start -> main free 0x137606d70
    (MALLOC_REPORT)
        Malloc calls: 3
        Free calls: 1
        Free calls to 0x0: 0
    Leaks at exit:
    0)  From (M_W 1) main of size 3 at address 0x137606df0  Content: "ex"
    Total leaks: 1

In this case the leak is str1, allocated using malloc in the main() function, str2 is correctly allocated and freed as displayed in the output, and str3 is a NULL pointer which will cause segmentation fault if not error checked


### **WARNINGS ⚠️**:  
   - The report will still include the leaks freed by exit()

   - There's no wrapper for calloc and realloc functions

   - This program is designed for a developement enviroment, it is **not** intended to be run with root privileges and an unprivileged user should be prevented from being able to do so on a production system
