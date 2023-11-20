Memdetect is a shell script to check your C or C++ project's memory leaks  
  
It can also:
 - show information about malloc and free calls at runtime
 - fail targeted malloc() calls at runtime, for military-grade stability!

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

The integrated Makefile tools will read and execute your current folder Makefile's first rule (or the one specified via the -m option)  
To run in makefile mode do **not** specify any directory or file before the other options
```shell
memdetect # You can optionally add gcc/memdetect options
```
*If you are encountering problems, try cleaning your target files, for example using `make fclean`*

## Run:

Memdetect runs standard in **C mode**, to enable **C++ mode** use the `-+` option

### Usage:

    ./memdetect.sh { [ directory_paths | files ] } [compiler_flags] [memdetect options]

#### Description:
 1. **files** or **directory paths**: Only one of these types can be specified. If you insert a directory path, every .c or .cpp file inside the directory is gonna be compiled, to exclude one or more sub-folders use the `-e` option, if you don't insert this parameter the script will use the Makefile tools, see **Makefile intergration**. This is te only positional argument.
 2. **Compiler_flags**: all the options that need to be passed to the `gcc` or `g++` compiler, they can be specified as *flag1 flag2 ... flagN* ex: *-I include -g -O3*
 3. **memdetect options**: see below for list, they can be specified as *option1 option1_arg option2 ... optionN* ex: *-a arg -or -e example*

### Options:

 - #### Compilation:

   - `-v | --verbose`: This option will cause memdetect to print the compilation commands

   - `-n | --dry-run`: Run the compilation process printing every command (like option -v) but without executing any

   - `-fl | --flags <flag0> ... <flagn>`: Another way to specify options to pass to gcc for compilation
   
   - `-e | --exclude <folder name>`: Specify a sub-folder inside one of the `directory_paths` which is excluded from compilation
  
   - `-m | --make-rule <rule>`: Specify the rule to be executed when using makefile tools (no directory or file specified)

 - #### Execution:
   
   - `-a | --args <arg0> ... <argn>`: Specify arguments to run the executable with, use when your program reads the argv

 - #### Fail malloc call (Use only one):

   - `-fail <number>`: Specify which malloc call should fail (return 0), 1 will fail first malloc, 2 the second and so on

   - `-fail <all>`: Adding this will fail all the malloc calls in the program

   - `-fail <loop> [<start>]`: This mode puts `memdetect -fail` in an infinite loop, failing the 1st malloc call on the 1st execution, the 2nd on the 2nd execution and so on incrementally. If you specify a number after `loop` it will start by failing the malloc call number `start` then `start + 1` and so on.

 - #### `-s | --show-calls`: prints informations about malloc and free calls at runtime
 - #### Modify `-s` behaviour: 

   - `-o | --output` filename: Removed for compatibility reasons, to archieve the same effect use stdout redirection with the terminal (memdetect ... > outfile)

   - `-il | --include-lib`: This option will include in the output the library name from where the first shown function have been called

   - `-ie | --include-ext`: This option will include in the output the calls to malloc and free from outside your source files.  
   *Watch out, some external functions will create confilct and crash your program if you intercept them, try to filter them out with `-fo`, but in most cases this option is overkill anyway*

   - `-ix | --include-xmalloc`: This option will include in the output the calls to xmalloc and xrealloc

   - `-fi | --filter-in <arg0> ... <argn>`: Show only results from memdetect output if substring `<arg>` is found inside the recent function stack

   - `-fo | --filter-out <arg0> ... <argn>`: Filter out results from memdetect output if substring `<arg>` is found inside the recent function stack

 - #### memdetect settings:

    - `-+ | -++`: Use to run in C++ mode
  
    - `-nr | --no-report`: Doesn't display the leaks report at the program exit
  
    - `-p | --preserve`: This option will mantain the executable output files

    - `-u | --update`: Only works if memdetect is installed, updates the installed executable to the latest commit from github

   - `-lb | --leaks-buff <size>`: Specify the size of the leaks report buffer, standard is 10000 (use only if the output tells you to do so)
     
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

#### Run with gcc options

    memdetect shell/ -lreadline -L~/.brew/opt/readline/lib -I~/.brew/opt/readline/include

#### Run using Makefile tools only adding memdetect options

    memdetect -fail loop --filter-out rl_ -e examples

#### Run using Makefile tools adding gcc and memdetect options

    memdetect -O3 -fail loop --filter-out rl_ -e examples

#### Run with gcc and memdetect options

    memdetect shell/ -lreadline -L~/.brew/opt/readline/lib -I~/.brew/opt/readline/include -fail loop --filter-out rl_ -e examples

## Understanding the output:

### Standard:
 - **Malloc report** this is a report of how many malloc and free calls have been executed during runtime
 - **Leaks at exit** this will contain every leaked address, the printed informations, in order, are:
   - the call index for every leaked address, which is the same as the one printed at runtime using **-s**
   - the name of the function which allocated memory at that address
   - the size of the allocation in bytes
   - the address of the allocation
   - the content, only if the data is readable in ASCII 

### Reference (-s):

All the output is printed following your program's runtime, so your output will be included in memdetect output and can be used as reference to distinguish between similar malloc calls, adding placeholder `printf` calls to your code can reveal itself very useful

 - `MALLOC N`:
    - for each malloc call, this is printed on the stdout, N represents the index of the malloc call, with the last two functions in the stack, the amount of bytes requested and the memory address
   
 - `FREE`:
    - for each free call, this is printed on the stdout, with the last two functions in the stack and the address freed

### Reference (-fail)

 - `FAILED MALLOC`:
    - when a malloc call gets failed by the `-fail` option this will be printed on the stdout with the last two functions in the stack

### Errors
 - `MEMDETECT ERROR`:
    - when this is printed it means the program didn't have enough stack size for storing informations about your malloc calls, use the option `--leaks-buff` ot `-lb` with a bigger value than default (10000) to fix this 

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

#### `-s|--show-calls` output:

```console
# With memdetect in $PATH
xedgit@pc:~ $ memdetect example.c -s -fail 3
```

    ================= memdetect by XEDGit ==================
    MALLOC 1: ?? -> main allocated 3 bytes at 0x5644ff3459d0
    MALLOC 2: main -> __strdup allocated 3 bytes at 0x5644ff347770
    MALLOC 3: main -> __strdup allocated 3 bytes at 0x5644ff3477b0
    FREE:    ?? -> main free 0x5644ff347770
    MEMDETECT REPORT:
            Malloc calls: 3 Free calls: 1   Free calls to 0x0: 0
    0)      From MALLOC 1 main of size 3 at address 0x5644ff3459d0  Content: "ex"
    1)      From MALLOC 3 __strdup of size 3 at address 0x5644ff3477b0      Content: "ex"
    Total leaks: 2

In this case the leak is str1, allocated using malloc in the main() function, str2 is correctly allocated and freed as displayed in the output, and str3 is a NULL pointer which will cause segmentation fault if not error checked


### **WARNINGS ⚠️**:  
   - The report will still include the leaks freed by exit()

   - There's no wrapper for calloc and realloc functions

   - This program is designed for a development enviroment, it is **not** intended to be run with root privileges and an unprivileged user should be prevented from being able to do so on a production system
