#!/bin/bash

COL="\e[34m"

COLB="\e[1;34m"

FAINT="\e[2;37m"

DEF="\e[0m"

ARGS=("$@")

ARGS_LEN=${#ARGS[@]}

EXTENSION=c

COMPILER=gcc

FLAGS=("-fl" "--flags" "-fail" "-d" "-dir" "--directory" "-f" "--files" "-e"   \
"--exclude" "-ie" "--include-external" "-il" "--include-libs" "--output"  \
"-fo" "--filter-out" "-fi" "--filter-in" "-lb" "-leaks-buff" "-p" "--preserve" \
"-nr" "--no-report" "-or" "--only-report" "-a" "--args" "-h" "--help" "--add-path" \
"-ix" "--include-xmalloc" "-u" "--update" "-+" "-++")

RE='^[0-9]+$'

EXCLUDE_FIND="! -path '*memdetect*' "

EXCLUDE_RES=""

GCC_FLAGS=""

OUT_ARGS=""

INCL_LIB=0

ADDR_SIZE=10000

ONLY_SOURCE=1

MALLOC_FAIL_INDEX=0

AS_COMM=""

AS_FUNC=""

AS_OG="og_"

INCL_XMALL="&& !strstr(stack[2], \"xmalloc\") && !strstr(stack[1], \"xmalloc\") && !strstr(stack[2], \"xrealloc\") && !strstr(stack[1], \"xrealloc\")"
SRC=""

HELP_MSG='
~~ MEMDETECT HELPER: ~~

SYNTAX:
{} = positional arguments (mandatory)
[] = optional arguments
<> = fields to be filled by the user
OR = only one of the arguments between OR can be specified, otherwise the first one to be specified is considered

USAGE:
./memdetect {<file0> [<file1>...] OR <directory path>} [<gcc flags>] [<memdetect flags>]

All the <gcc flags> will be added to the gcc command in writing order\n
Flags:

	Compiling:

		`-fl | --flags <flag0 ... flagn>`: Another way to specify flags to use when compiling with gcc
   
		`-e | --exclude <folder name>`: Specify a folder inside the `directorypath` which gets excluded from compiling

	Executing:
   
		`-a | --args <arg0> ... <argn>`: Specify arguments to run with the executable


	Fail malloc (Use one per command):

		`-fail <number>`: Specify which malloc call should fail (return 0), 1 will fail first malloc and so on

		`-fail <all>`: Adding this flag will fail all the malloc calls

		`-fail <loop> <start from>`: Your code will be compiled and ran in a loop, failing the 1st malloc call on the 1st execution, the 2nd on the 2nd execution and so on. If you specify a number after `loop` it will start by failing `start from` malloc and continue. **This flag is really useful for debugging**

	Output manipulation:

		`-o | --output` filename: Removed for compatibility reasons, to archieve the same effect use stdout redirection with the terminal (memdetect ... > outfile)

		`-il | --include-lib`: Adding this flag will include in the output the library name from where the first shown function have been called

		`-ie | --include-ext`: Adding this flag will include in the output the calls to malloc and free from outside your source files.  
   **Watch out, some external functions will create confilct and crash your program if you intercept them, try to filter them out with `-fo`**

		`-ix | --include-xmalloc`: Adding this flag will include in the output the calls to xmalloc and xrealloc

		`-or | --only-report`: Only display the leaks report at the program exit

		`-nr | --no-report`: Does not display the leaks report at the program exit

		`-fi | --filter-in <arg0> ... <argn>`: Show only results from memdetect output if substring `<arg>` is found inside the output line

		`-fo | --filter-out <arg0> ... <argn>`: Filter out results from memdetect output if substring `arg` is found inside the output line

	Output files:

		`-p | --preserve`: Adding this flag will mantain the executable output files

	Program settings:

 		`-+ | -++`: Use to run in C++ mode

		`-u | --update`: Only works if the executable is located into one of the PATH folders, updates the executable to the latest commit from github

		`-lb | --leaks-buff <size>`: Specify the size of the leaks report buffer, standard is 10000 (use only if the output tells you to do so)
     
		`-h | --help`: Display help message
 
		`--add-path`: adds memdetect executable to a $PATH of your choice

'

function cleanup()
{
	rm -f "$PROJECT_PATH/fake_malloc.c"

	rm -f "$PROJECT_PATH/fake_malloc.o"
	
	rm -f "$PROJECT_PATH/fake_malloc_destructor.c"

	rm -f "$PROJECT_PATH/fake_malloc_destructor.o"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/fake_malloc.dylib"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/malloc_debug"
}

function loop()
{
	
	(( COUNTER = COUNTER - 1 ))
	
	CONTINUE=""
	

	([ -n "$FILE_PATH" ] || [ "$EXTENSION" == "cpp" ]) && gcc -c fake_malloc.c -o "$PROJECT_PATH/fake_malloc.o"
	
	while [[ $COUNTER -ge 0 ]]
	do
		
		(( COUNTER = COUNTER + 1 ))
		
		printf "\e[1mPress any key to run with -fail %s or 'q' to quit:$DEF" "$COUNTER"
		
		stty raw -echo

		read -rn1 CONTINUE
		
		stty -raw echo

		{ [ "$CONTINUE" == "q" ] || [ "$CONTINUE" = $'\e' ]; } && break

		[ ! "$CONTINUE" = $'\n' ] && printf "\n"
		
		gcc fake_malloc.c -c -o "$PROJECT_PATH/fake_malloc.o" -DINCL_LIB=$INCL_LIB -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$COUNTER -ldl
		
		GCC_CMD="$COMPILER $SRC -rdynamic -o $PROJECT_PATH/malloc_debug -DINCL_LIB=$INCL_LIB -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=${COUNTER}$GCC_FLAGS"
		
		[ "$EXTENSION" == "cpp" ] && GCC_CMD+=" -ldl"

		printf "$COLB%s$DEF\n" "$GCC_CMD"
		
		sh -c "$GCC_CMD 2>&1" || (cleanup && exit 1)
		
		printf "$COLB%s/malloc_debug%s:$DEF\n" "$PROJECT_PATH" "$OUT_ARGS" 
		
		sh -c "$PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	done

	cleanup

	printf "\nExiting\n"

}

function loop_osx()
{
	
	(( COUNTER = COUNTER - 1 ))

	CONTINUE=""
	
	while [[ $COUNTER -ge 0 ]]
	do
		
		(( COUNTER = COUNTER + 1 ))
		
		printf "\e[1mPress any key to run with -fail %s or 'q' to quit:$DEF" "$COUNTER"
		
		stty raw -echo

		read -rn1 CONTINUE
		
		stty -raw echo

		{ [ "$CONTINUE" == "q" ] || [ "$CONTINUE" = $'\e' ]; } && break

		[ ! "$CONTINUE" = $'\n' ] && printf "\n"
		
		gcc -shared -fPIC "$PROJECT_PATH"/fake_malloc.c -o "$PROJECT_PATH"/fake_malloc.dylib -DINCL_LIB=$INCL_LIB -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$COUNTER || (cleanup && exit 1)
		
		gcc "$PROJECT_PATH"/fake_malloc_destructor.c -c -o "$PROJECT_PATH/fake_malloc_destructor.o"

		GCC_CMD="$COMPILER $SRC -rdynamic -o $PROJECT_PATH/malloc_debug$GCC_FLAGS"
		
		printf "$COLB%s$DEF\n" "$GCC_CMD"
		
		sh -c "$GCC_CMD 2>&1" || (cleanup && exit 1)

		printf "${COLB}DYLD_INSERT_LIBRARIES=%s/fake_malloc.dylib %s/malloc_debug%s:$DEF\n" "$PROJECT_PATH" "$PROJECT_PATH" "$OUT_ARGS"
		
		sh -c "DYLD_INSERT_LIBRARIES=$PROJECT_PATH/fake_malloc.dylib $PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	done

	cleanup

	printf "\nExiting\n"

}

function run()
{

	([ -n "$FILE_PATH" ] || [ "$EXTENSION" == "cpp" ]) && gcc -c fake_malloc.c -o "$PROJECT_PATH/fake_malloc.o" -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DINCL_LIB=$INCL_LIB -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX -ldl

	GCC_CMD="$COMPILER $SRC -rdynamic -o $PROJECT_PATH/malloc_debug$GCC_FLAGS -DINCL_LIB=$INCL_LIB -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX$GCC_FLAGS -ldl"

	[ "$EXTENSION" == "cpp" ] && GCC_CMD+=" -ldl"
	
	printf "$COLB%s$DEF\n" "$GCC_CMD"
	
	sh -c "$GCC_CMD 2>&1" || (cleanup && exit 1)

	printf "${COL}%s/malloc_debug%s:$DEF\n" "$PROJECT_PATH" "$OUT_ARGS"
	
	sh -c "$PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	cleanup

}

function run_osx()
{
	gcc -shared -fPIC "$PROJECT_PATH"/fake_malloc.c -o "$PROJECT_PATH"/fake_malloc.dylib -DONLY_SOURCE=$ONLY_SOURCE -DINCL_LIB=$INCL_LIB -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX || (cleanup && exit 1)

	gcc "$PROJECT_PATH"/fake_malloc_destructor.c -c -o "$PROJECT_PATH"/fake_malloc_destructor.o

	GCC_CMD="$COMPILER $SRC -rdynamic -o $PROJECT_PATH/malloc_debug$GCC_FLAGS"
	
	printf "$COLB%s$DEF\n" "$GCC_CMD"
	
	sh -c "$GCC_CMD 2>&1" || (cleanup && exit 1)

	printf "${COL}DYLD_INSERT_LIBRARIES=%s/fake_malloc.dylib %s/malloc_debug%s:$DEF\n" "$PROJECT_PATH" "$PROJECT_PATH" "$OUT_ARGS"
	
	sh -c "DYLD_INSERT_LIBRARIES=$PROJECT_PATH/fake_malloc.dylib $PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	cleanup
}

function check_update()
{
	PATH_TO_BIN=$(which memdetect) || return

	curl https://raw.githubusercontent.com/XEDGit/memdetect/master/memdetect.sh >tmp 2>/dev/null || return

	DIFF=$(diff tmp $PATH_TO_BIN)
	
	if [ "$DIFF" != "" ]
	then
		chmod +x tmp
		if [ -w $(dirname $PATH_TO_BIN) ]
		then
			mv tmp $PATH_TO_BIN && printf "${COLB}Updated memdetect, relaunch it!\n$DEF"
		else
			(sudo mv tmp $PATH_TO_BIN && printf "${COLB}Updated memdetect, relaunch it!\n$DEF") || (printf "Error gaining privileges\n" && rm tmp)
		fi
		exit 0
	else
		printf "No update found.\n"
		rm tmp
	fi
}

function add_to_path()
{

	PATH_ARR=$(echo "$PATH" | tr ':' '\n')

	CONT=0

	CONT2=0

	echo "In which path do you want to install it?"

	for VAL in $PATH_ARR
	do
		printf "\t$CONT) $VAL\n"
		(( CONT = CONT + 1 ))
	done

	printf "Select index: "

	read -r PATH_CHOICE

	{ [[ ! ("$PATH_CHOICE" =~ $RE) ]] || [[ "$PATH_CHOICE" -lt 0 ]] || [[ "$PATH_CHOICE" -gt $((CONT - 1)) ]]; } && echo "Index not in range" && exit 1

	for VAL in $PATH_ARR
	do
		[[ $CONT2 -eq $PATH_CHOICE ]] && PATH_CHOICE=$VAL && break
		(( CONT2 = CONT2 + 1 ))
	done

	[ ! -e "./memdetect.sh" ] && printf "Error: ./memdetect.sh not found\n" && exit 1

	[ ! -e "$PATH_CHOICE" ] && printf "Error: '$PATH_CHOICE' directory doesn't exists\n" && exit 1

	printf "${COLB}Adding memdetect to $PATH_CHOICE${DEF}\n"
	
	if [ -w "$PATH_CHOICE" ]
	then
		cp ./memdetect.sh "${PATH_CHOICE%/}"/memdetect
	else
		set -x
		sudo cp ./memdetect.sh "${PATH_CHOICE%/}"/memdetect
	fi

}

function check_flag()
{
	for FL in "${FLAGS[@]}"
	do
		[ "$1" = "$FL" ] && return 0
	done
	return 1
}

I=0

[[ $ARGS_LEN == 0 ]] && printf "No arguments specified, use -h or --help to display the help prompt\n" && exit 1

! [ -t 1 ] && COL="" && COLB="" && DEF="" && FAINT=""

if ! check_flag "${ARGS[$I]}"
then
	if [ -d "${ARGS[$I]}" ]
	then
		PROJECT_PATH=${ARGS[$I]%/}
		((I = I + 1))
	else
		while [[ $I -lt $ARGS_LEN ]]
		do
			[[ ${ARGS[$I]} == "-"* ]] && break
			[ ! -e "${ARGS[$I]}" ] && echo "Error: ${ARGS[$I]} not found" && exit 1
			FILE_PATH+=" ${ARGS[$I]}"
			(( I = I + 1 ))
		done
		PROJECT_PATH='.'
	fi
fi

if ! check_flag "${ARGS[$I]}"
then
	while [[ $I -lt $ARGS_LEN ]]
	do
		check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
		GCC_FLAGS+=" ${ARGS[$I]}"
		(( I = I + 1 ))
	done
	(( I = I + 1 ))
fi

while [[ $I -lt $ARGS_LEN ]]
do
    arg=${ARGS[$I]}
	case $arg in

        "-e" | "--exclude")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a memdetect flag\n" && exit 1
			(( I = I + 1 ))
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				EXCLUDE_FIND+="! -path '*${ARGS[$I]}*' "
				(( I = I + 1 ))
			done
        ;;

		"-fo" | "--filter-out")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a memdetect flag\n" && exit 1
			(( I = I + 1 ))
			II=0
			EXCLUDE_RES="&& ("
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				! [[ $II -eq  0 ]] && EXCLUDE_RES+=" &&"
				(( II = II + 1))
				EXCLUDE_RES+=" !strstr(stack[2], \"${ARGS[$I]}\") && !strstr(stack[3], \"${ARGS[$I]}\")"
				(( I = I + 1 ))
			done
			EXCLUDE_RES+=")"
		;;

		"-fi" | "--filter-in")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a memdetect flag\n" && exit 1
			(( I = I + 1 ))
			II=0
			EXCLUDE_RES="&& !("
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				! [[ $II -eq  0 ]] && EXCLUDE_RES+=" &&"
				(( II = II + 1))
				EXCLUDE_RES+=" !strstr(stack[2], \"${ARGS[$I]}\") && !strstr(stack[3], \"${ARGS[$I]}\")"
				(( I = I + 1 ))
			done
			EXCLUDE_RES+=")"
		;;

		"-ie" | "--include-ext")
			ONLY_SOURCE=0
		;;

		"-il" | "--include-lib")
			INCL_LIB=1
		;;

		"-ix" | "--include-xmalloc")
			INCL_XMALL=""
		;;

		"-p" | "--preserve")
			PRESERVE=1
		;;

		"-fail")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a memdetect flag\n" && exit 1
			NEW_VAL=${ARGS[$I + 1]}
			if ! [[ $NEW_VAL =~ $RE ]]
			then
				if [ "$NEW_VAL" = "loop" ]
				then
					MALLOC_FAIL_LOOP=1
					if [ -n "${ARGS[$I + 2]}" ] && ! check_flag "${ARGS[$I + 2]}" && [[ ${ARGS[$I + 2]} =~ $RE ]]
					then
						COUNTER=${ARGS[$I + 2]}
					else
						COUNTER=1
					fi
				elif [ "$NEW_VAL" = "all" ]
				then
					MALLOC_FAIL_INDEX=-1
				else
					printf "Error: the value of --fail '$arg' is not a number, 'all' or 'loop'\n"
					exit 1
				fi
			else
				MALLOC_FAIL_INDEX=$NEW_VAL
			fi
		;;

		"-+" | "-++")
			EXTENSION=cpp
			COMPILER=c++
		;;

        "-fl" | "--flags")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a memdetect flag\n" && exit 1
			(( I = I + 1 ))
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				GCC_FLAGS+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
		;;

		"-a" | "--args")
			check_flag "${ARGS[$I + 1]}" && printf "Error: %s flag value '%s' is a memdetect flag\n" "${ARGS[$I]}" "${ARGS[$I + 1]}" && exit 1
			(( I = I + 1 ))
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				OUT_ARGS+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
		;;

		"-lb" | "--leaks-buff")
			NEW_VAL=${ARGS[$I + 1]}
			(! [[ $NEW_VAL =~ $RE ]] || check_flag "$NEW_VAL") && printf "Error: the value of --leaks-buff '%s' is not a number\n" "$NEW_VAL" && exit 1
			ADDR_SIZE=$NEW_VAL
		;;

		"-nr" | "--no-report")
			NO_REPORT="// "
		;;

		"-or" | "--only-report")
			ONLY_REPORT="// "
		;;

		"--output")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a memdetect flag\n" && exit 1
			(( I = I + 1 ))
			if [ -f "${ARGS[$I]}" ]
			then
				printf "Overwrite existing file \"${ARGS[$I]}\"? [y/N]"
				read -rn1 OUTPUT_CHOICE
				if [ "$OUTPUT_CHOICE" = "y" ] || [ "$OUTPUT_CHOICE" = "Y" ]
				then
					printf "\n"
				 	rm -f "${ARGS[$I]}"
				else
					printf "\nExiting\n"
					exit 1
				fi
			fi
			touch "${ARGS[$I]}"
			[ ! -f "${ARGS[$I]}" ] && printf "Failed creating output file\n" && exit 1
			echo "Output file ready!"
			exec 1>"${ARGS[$I]}"
			exec 2>&1
			COLB=""
			COL=""
			DEF=""
		;;

        "-h" | "--help")
			printf "$HELP_MSG" | less
            exit
        ;;

		"-u" | "--update")
			printf "Checking for updates...\n"
			check_update
			exit
		;;

		"--add-path")
			add_to_path
			exit
		;;
    esac
    (( I = I + 1 ))
done

{ [ -z "$FILE_PATH" ] && [ -z "$PROJECT_PATH" ]; } && printf "Error: Missing path to project or file list.\n" && exit 1

{ [ -z "$FILE_PATH" ] && [ ! -d "$PROJECT_PATH" ]; } && echo "Error: $PROJECT_PATH is not a folder" && exit 1

if [[ "$OSTYPE" == "darwin"* ]]
then
	AS_COMM="//"
	AS_FUNC="fake_"
	AS_OG=""
	echo "extern void __attribute__((destructor)) malloc_hook_report();
extern void __attribute__((constructor)) malloc_hook_pid_detect();" > $PROJECT_PATH/fake_malloc_destructor.c
	([ -n "$FILE_PATH" ] || [ "$EXTENSION" == "cpp" ]) && SRC+="$PROJECT_PATH/fake_malloc_destructor.o "
elif ([ -n "$FILE_PATH" ] || [ "$EXTENSION" == "cpp" ])
then
	SRC+="$PROJECT_PATH/fake_malloc.o "
fi

eval "cat << EOF > $PROJECT_PATH/fake_malloc.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

#define COL \"$COL\"

#define COLB \"$COLB\"

#define FAINT \"$FAINT\"

#define DEF \"$DEF\"

typedef struct s_addr {
	void	*address;
	char	*function;
	int		bytes;
	int		index;
}	t_addr;

#ifdef __APPLE__
# define MAC_OS_SYSTEM 1
# define DYLD_INTERPOSE(_replacment,_replacee) \
   __attribute__((used)) static struct{ const void* replacment; const void* replacee; } _interpose_##_replacee \
            __attribute__ ((section (\"__DATA,__interpose\"))) = { (const void*)(unsigned long)&_replacment, (const void*)(unsigned long)&_replacee };
#else
# define MAC_OS_SYSTEM 0
#endif

${AS_COMM}static void		(*og_free)(void *);
${AS_COMM}static void		*(*og_malloc)(size_t);
static int 		free_count = 0;
static int		init_run = 0;
static int 		zero_free_count = 0;
static int		malloc_count = 0;
static int		addr_i = 0;
static int		addr_rep = 0;
static t_addr	addresses[ADDR_ARR_SIZE] = {0};
static pid_t	parent_pid = 0;

${NO_REPORT}void __attribute__((constructor)) malloc_hook_pid_detect();
${NO_REPORT}void __attribute__((destructor)) malloc_hook_report();

void malloc_hook_pid_detect()
{
	init_run = 1;
	if (!parent_pid)
		parent_pid = getpid();
	init_run = 0;
}

int	malloc_hook_check_content(unsigned char *str)
{
	while (*str && *str >= 32 && *str <= 126)
		str++;
	if (!*str)
		return (0);
	return (1);
}

void malloc_hook_report()
{
	int	tot_leaks;

	if (parent_pid != getpid())
		return ;
	tot_leaks = 0;
	init_run = 1;
	printf(COLB \"(MALLOC_REPORT)\" DEF \"\n\tMalloc calls: \" COL \"%d\" DEF \"\n\tFree calls: \" COL \"%d\" DEF \"\n\tFree calls to 0x0: \" COL \"%d\" DEF \"\n\" COLB \"Leaks at exit:\n\" DEF, malloc_count, free_count, zero_free_count);
	if (addr_rep)
		addr_i = ADDR_ARR_SIZE - 1;
	for (int i = 0; i <= addr_i; i++)
	{
		if (addresses[i].address)
		{
			if (!malloc_hook_check_content((unsigned char *)addresses[i].address))
				printf(COLB \"%d)\" DEF \"\tFrom \" COLB \"(M_W %d) %s\" DEF \" of size \" COL \"%d\" DEF \" at address \"COL \"%p\" DEF \"	Content: \" COL \"\\\"%s\\\"\n\" DEF, tot_leaks++, addresses[i].index, addresses[i].function, addresses[i].bytes, addresses[i].address, (char *)addresses[i].address);
			else
				printf(COLB \"%d)\" DEF \"\tFrom \" COLB \"(M_W %d) %s\" DEF \" of size \" COL \"%d\" DEF \" at address \"COL \"%p	Content unavailable\n\" DEF, tot_leaks++, addresses[i].index, addresses[i].function, addresses[i].bytes, addresses[i].address);
			${AS_OG}free(addresses[i].function);
		}
	}
	printf(COLB \"Total leaks: %d\nWARNING:\" DEF \" the leaks freed by exit() are still displayed in the report\n\" DEF, tot_leaks);
}

${AS_COMM}int init_malloc_hook()
${AS_COMM}{
${AS_COMM}	og_malloc = dlsym(RTLD_NEXT, \"malloc\");
${AS_COMM}    og_free = dlsym(RTLD_NEXT, \"free\");

${AS_COMM}    if (!og_malloc || !og_free)
${AS_COMM}        exit(1);
${AS_COMM}	return (0);
${AS_COMM}}

int	malloc_hook_backtrace_readable(char ***stack_readable)
{
	void	*stack[10];
	int		stack_size;

	stack_size = backtrace(stack, 10);
	*stack_readable = backtrace_symbols(stack, stack_size);
	return (stack_size);
}

void	malloc_hook_string_edit(char *str)
{
	char	ch;
	char	*start;
	char	*temp;

	ch = ' ';
	start = str;
	temp = str;
	if (!MAC_OS_SYSTEM)
	{
		char *lib_p = 0;

		ch = '+';
		while (*str && *(str - 1) != '(')
			if (*str++ == '/')
				lib_p = str;
		if ($INCL_LIB)
		{
			while (*lib_p && *lib_p != '(')
				*start++ = *lib_p++;
			*start++ = ' ';
			*start++ = '/';
			*start++ = ' ';
			temp = start;
		}
	}
	else
	{
		if ($INCL_LIB)
		{
			str++;
			while (*str == ' ')
				str++;
			while (*str != ' ')
				*start++ = *str++;
			*start++ = ' ';
			*start++ = '/';
			*start++ = ' ';
		}
		str = &temp[59];
	}
	while (*str && *str != ch)
		*start++ = *str++;
	if (start == temp)
	{
		*start++ = '?';
		*start++ = '?';
	}
	*start = 0;
}

void	*${AS_FUNC}malloc(size_t size)
{
	void		*ret;
	char		**stack;
	int			stack_size;
	static int	malloc_fail = 0;

	${AS_COMM}if (!og_malloc)
	${AS_COMM}	if (init_malloc_hook())
	${AS_COMM}		exit (1);
	if (init_run)
		return (${AS_OG}malloc(size));
	init_run = 1;
	stack_size = malloc_hook_backtrace_readable(&stack);
	if (ONLY_SOURCE && !(strstr(stack[2], \"malloc_debug\") || strstr(stack[3], \"malloc_debug\") || strstr(stack[4], \"malloc_debug\")))
	{
		${AS_OG}free(stack);
		init_run = 0;
		return (${AS_OG}malloc(size));
	}
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	if (stack[2][0] != '?' $EXCLUDE_RES $INCL_XMALL)
	{
		malloc_count++;
		if (++malloc_fail == MALLOC_FAIL_INDEX || MALLOC_FAIL_INDEX == -1)
		{
			printf(COLB \"(MALLOC_FAIL)\t %s -> %s malloc num %d failed\n\" DEF, stack[3], stack[2], malloc_fail);
			${AS_OG}free(stack);
			init_run = 0;
			return (0);
		}
		ret = ${AS_OG}malloc(size);
		addr_i++;
		if (addr_i == ADDR_ARR_SIZE)
		{
			addr_rep = 1;
			addr_i = 0;
		}
		while (addr_i < ADDR_ARR_SIZE - 1 && addresses[addr_i].address)
			addr_i++;
		if (addr_i == ADDR_ARR_SIZE - 1 && addresses[addr_i].address)
		{
			printf(COLB \"(MALLOC_ERROR)\t\" DEF \" Not enough buffer space, default is 10000 specify a bigger one with the --leaks-buff flag\n\");
			${AS_OG}free(stack);
			exit (1);
		}
		addresses[addr_i].function = strdup(stack[2]);
		addresses[addr_i].bytes = size;
		addresses[addr_i].index = malloc_count;
		addresses[addr_i].address = ret; 
		${ONLY_REPORT}printf(COLB \"(MALLOC_WRAPPER %d) \" FAINT \"%s -> %s allocated %zu bytes at %p\" DEF \"\n\", malloc_count, stack[3], stack[2], size, ret);
	}
	else
		ret = ${AS_OG}malloc(size);
	init_run = 0;
	${AS_OG}free(stack);
	return (ret);
}

void	${AS_FUNC}free(void *tofree)
{
	char	**stack;

	if (init_run)
	{
		${AS_OG}free(tofree);
		return ;
	}
	init_run = 1;
	malloc_hook_backtrace_readable(&stack);
	if (ONLY_SOURCE && !(strstr(stack[2], \"malloc_debug\") || strstr(stack[3], \"malloc_debug\") || strstr(stack[4], \"malloc_debug\")))
	{
		${AS_OG}free(stack);
		init_run = 0;
		return ;
	}
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	if (stack[2][0] != '?' $INCL_XMALL)
	{
		${ONLY_REPORT}if (1 $EXCLUDE_RES)
		${ONLY_REPORT}printf(COLB \"(FREE_WRAPPER)\t\" FAINT \" %s -> %s free %p\" DEF \"\n\" , stack[3], stack[2], tofree);
		if (tofree)
		{
			free_count++;
			for (int i=0; i <= addr_i; i++)
			{
				if (addresses[i].address == tofree)
				{
					${AS_OG}free(addresses[i].function);
					addresses[i].function = 0;
					addresses[i].bytes = 0;
					addresses[i].address = 0;
					addresses[i].index = 0;
				}
			}
		}
		else
		{
			zero_free_count++;
		}
	}
	init_run = 0;
	${AS_OG}free(stack);
	${AS_OG}free(tofree);
}

$([ -z "$AS_COMM" ] && echo "// ")DYLD_INTERPOSE(fake_malloc, malloc);
$([ -z "$AS_COMM" ] && echo "// ")DYLD_INTERPOSE(fake_free, free);

EOF"

if [ -z "$FILE_PATH" ]
then
	if [[ "$OSTYPE" == "darwin"* ]]
	then
		SRC+=$(eval "find $PROJECT_PATH -name '*.$EXTENSION' $EXCLUDE_FIND" | grep -v fake_malloc.c | tr '\n' ' ')
	else
		SRC+=$(eval "find $PROJECT_PATH -name '*.$EXTENSION' $EXCLUDE_FIND" | tr '\n' ' ')
	fi
else
	SRC+="$FILE_PATH"
fi

printf "$COLB================= memdetect by XEDGit ==================
$DEF"

if [ -z "$MALLOC_FAIL_LOOP" ]
then
	if [[ "$OSTYPE" == "darwin"* ]]
	then 
		run_osx
	else
		run
	fi
else
	if [[ "$OSTYPE" == "darwin"* ]]
	then 
		loop_osx
	else
		loop
	fi
fi

exit 0
