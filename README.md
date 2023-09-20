Memdetect is a cross-platform shell script to compile and run your C or C++ project with a wrapper of malloc() and free(), which will help you understand your memory-management and find memory leaks.


It also fails targeted malloc() calls, for military-grade stability in your program!

## Platforms:

[<img src="https://img.shields.io/badge/Working-52CF44?style=for-the-badge&label=MacOS&logo=apple&logoColor=white" />](https://github.com/XEDGit/memdetect)

[<img src="https://img.shields.io/badge/Working-52CF44?style=for-the-badge&label=Linux&logo=linux&logoColor=white" />](https://github.com/XEDGit/memdetect)

[<img src="https://img.shields.io/badge/Compatible via WSL-52CF44?style=for-the-badge&label=Windows&logo=windows&logoColor=white" />](https://docs.microsoft.com/en-us/windows/wsl/install)

## Enviroment:

[<img src="https://img.shields.io/badge/GCC-00599C?style=for-the-badge&logo=c&logoColor=white" />](https://github.com/XEDGit/memdetect)
[<img src="https://img.shields.io/badge/C++-00599C?style=for-the-badge&logo=c%2B%2B&logoColor=white" />](https://github.com/XEDGit/memdetect)

## Setup:

### Installation:
This program is made by a single shell executable, so it doesn't need proper installation, to be able to run it just clone this repository and you're ready to test

```console
git clone https://github.com/XEDGit/memdetect.git
cd memdetect
./memdetect.sh
```

### Adding memdetect to your $PATH:
You can add this program to your $PATH by adding this flag

```console
./memdetect.sh --add-path
```
from now on you can just type `memdetect` in your terminal from any folder in the system!
 
### Makefile integration:
You can integrate this program with Makefile by executing this command in your Makefile path

```shell
echo >> ./Makefile '
mem:
    /path/to/memdetect.sh /path/to/project $(GCC_FLAGS) # add memdetect flags here'
```
Another useful integration, if you want the freedom of executing with different flags everytime

```shell
echo >> ./Makefile '
mem:
    /path/to/memdetect.sh /path/to/project $(GCC_FLAGS) $(1)'
```

Which can be executed with

```shell
make mem 1='-fail 2'
```

## Run:

Memdetect runs standard in **C mode**, to enable **C++ mode** use the `-+` flag


You can either run memdetect on **files** by specifying their name, or with a **directory path**. If you insert a directory path every .c or .cpp file inside the directory is gonna be compiled, to exclude some sub-folder use the `-e` flag

### Usage:
    ./memdetect.sh { <directory_path> | <file> [<file1...>] } [<compiler_flags>] [memdetect flags]

### Flags:

 - #### Compiling:

   - `-fl | --flags <flag0 ... flagn>`: Another way to specify flags to use when compiling with gcc
   
   - `-e | --exclude <folder name>`: Specify a folder inside the `directorypath` which gets excluded from compiling

 - #### Executing:
   
   - `-a | --args <arg0> ... <argn>`: Specify arguments to run with the executable
   - `-n | --dry-run`: Run the program printing every command and without executing any 


 - #### Fail malloc (Use one per command):

   - `-fail <number>`: Specify which malloc call should fail (return 0), 1 will fail first malloc and so on

   - `-fail <all>`: Adding this flag will fail all the malloc calls

   - `-fail <loop> <start from>`: Your code will be compiled and ran in a loop, failing the 1st malloc call on the 1st execution, the 2nd on the 2nd execution and so on. If you specify a number after `loop` it will start by failing `start from` malloc and continue. **This flag is really useful for debugging**

 - #### Output manipulation:

   - `-o | --output` filename: Removed for compatibility reasons, to archieve the same effect use stdout redirection with the terminal (memdetect ... > outfile)

   - `-il | --include-lib`: Adding this flag will include in the output the library name from where the first shown function have been called

   - `-ie | --include-ext`: Adding this flag will include in the output the calls to malloc and free from outside your source files.  
   **Watch out, some external functions will create confilct and crash your program if you intercept them, try to filter them out with `-fo`**

   - `-ix | --include-xmalloc`: Adding this flag will include in the output the calls to xmalloc and xrealloc

   - `-or | --only-report`: Only display the leaks report at the program exit

   - `-nr | --no-report`: Doesn't display the leaks report at the program exit

   - `-fi | --filter-in <arg0> ... <argn>`: Show only results from memdetect output if substring `<arg>` is found inside the output line

   - `-fo | --filter-out <arg0> ... <argn>`: Filter out results from memdetect output if substring `arg` is found inside the output line

 - #### Output files:

   - `-p | --preserve`: Adding this flag will mantain the executable output files

 - #### Program settings:

    - `-+ | -++`: Use to run in C++ mode

    - `-u | --update`: Only works if the executable is located into one of the PATH folders, updates the executable to the latest commit from github

   - `-lb | --leaks-buff <size>`: Specify the size of the leaks report buffer, standard is 10000 (use only if the output tells you to do so)

   - `-m | --make-rule <rule>`: Specify the rule to be executed when using makefile tools (no directory or file specified)
     
   - `-h | --help`: Display help message
 
   - `--add-path`: adds memdetect executable to a $PATH of your choice


 All the optional flags will be added to the gcc command in writing order

### Examples:

#### Run with single file

    ./memdetect.sh ft_split.c
   
#### Run with multiple files

    ./memdetect.sh ft_split.c ft_strlen.c

#### Run with project folder

    ./memdetect.sh .

#### Run with options

    ./memdetect.sh shell/ -lreadline -L~/.brew/opt/readline/lib -I~/.brew/opt/readline/include -fail loop --filter-out rl_ -e examples

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

After your program exits a **leaks report** will be printed. 

### **WARNINGS ⚠️**:  
   - The report will still include the leaks freed by exit()

   - There's no wrapper for calloc and realloc functions

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
xedgit@pc:~ $ memdetect example.c -fail 3
```

    DYLD_INSERT_LIBRARIES=./fake_malloc.dylib ./malloc_debug:
    (MALLOC_WRAPPER 1) start -> main allocated 3 bytes at 0x7fa643c03590
    (MALLOC_WRAPPER 2) main -> strdup allocated 3 bytes at 0x7fa643c03850
    (MALLOC_FAIL)    main -> strdup malloc num 3 failed
    (FREE_WRAPPER)   start -> main free 0x7fa643c03850
    (MALLOC_REPORT)
            Malloc calls: 2
            Free calls: 1
            Free calls to 0x0: 0
    Leaks at exit:
    1)      From main of size 3 at address 0x7fa643c03590   Content: "ex"
    Total leaks: 1
