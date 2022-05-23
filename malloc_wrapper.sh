#!/bin/bash

RED="\e[31m"

REDB="\e[1;31m"

DEF="\e[0m"

printf "$REDB================= malloc_wrapper by: ==================
 _|      _|  _|_|_|_|  _|_|_|      _|_|_|  _|    _|      
   _|  _|    _|        _|    _|  _|            _|_|_|_|  
     _|      _|_|_|    _|    _|  _|  _|_|  _|    _|      
   _|  _|    _|        _|    _|  _|    _|  _|    _|      
 _|      _|  _|_|_|_|  _|_|_|      _|_|_|  _|      _|_|
=======================================================
$DEF"

ARGS=("$@")

ARGS_LEN=${#ARGS[@]}

FLAGS=("-fl" "--flags" "-fail" "-d" "-dir" "--directory" "-f" "--files" "-e" "--exclude" "-ie" "--include-external" "-il" "--include-libs" \
	   "-fo" "--filter-out" "-fi" "--filter-in" "-lb" "-leaks-buff" "-p" "--preserve" "-nr" "--no-report" "-a" "--args" "-h" "--help" "--add-path" "-ix" "--include-xmalloc")

RE='^[0-9]+$'

EXCLUDE_FIND="! -path '*malloc_wrapper*' "

EXCLUDE_RES=""

GCC_FLAGS=""

OUT_ARGS=""

INCL_LIB=0

ADDR_SIZE=10000

EXCLUDE_RES=""

ONLY_SOURCE=1

MALLOC_FAIL_INDEX=0

AS_COMM=""

AS_FUNC=""

AS_OG="og_"

INCL_XMALL="&& !strstr(stack[2], \"xmalloc\") && !strstr(stack[1], \"xmalloc\") && !strstr(stack[2], \"xrealloc\") && !strstr(stack[1], \"xrealloc\")"

SRC=""

HELP_MSG="Usage: ./malloc_wrapper {<file0> [<file1>...] | <directory_path>} [<gcc_flags>] [[-h] | [--add-path] | [-nr] [-ie] [-ix] [-p] [-fail <to_fail>] [-e <folder_to_exclude>] [-lb <size>] [-fi <filter0> [<filter1...>]] [-fl <gcc_flag0> [<gcc_flag1>...]] [-a <out_arg0> [<out_arg1>...]]]\n"

function loop()
{
	
	(( COUNTER = COUNTER - 1 ))
	
	CONTINUE=""
	
	while [[ $COUNTER -ge 0 ]]
	do
		
		(( COUNTER = COUNTER + 1 ))
		
		printf "\e[1mPress any key to run with -fail %s or 'q' to quit:$DEF" "$COUNTER"
		
		read -rn1 CONTINUE
		
		[ "$CONTINUE" == "q" ] && rm -f "$PROJECT_PATH/fake_malloc.c" && printf "\nExiting\n" && exit 0

		[ ! "$CONTINUE" = $'\n' ] && printf "\n"
		
		GCC_CMD="gcc $SRC -rdynamic -o $PROJECT_PATH/malloc_debug -INCL_LIB=$INCL_LIB -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$COUNTER$GCC_FLAGS -ldl"
		
		printf "$REDB%s$DEF\n" "$GCC_CMD"
		
		sh -c "$GCC_CMD 2>&1"

		if [[ $? != 0 ]]
		then
			continue
		fi
		
		echo "$REDB$PROJECT_PATH/malloc_debug$OUT_ARGS:$DEF"
		
		sh -c "$PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	done

	rm -f "$PROJECT_PATH/fake_malloc.c"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/malloc_debug"

}

function loop_osx()
{
	
	(( COUNTER = COUNTER - 1 ))

	CONTINUE=""
	
	while [[ $COUNTER -ge 0 ]]
	do
		
		(( COUNTER = COUNTER + 1 ))
		
		printf "\e[1mPress any key to run with -fail %s or 'q' to quit:$DEF" "$COUNTER"
		
		read -rn1 CONTINUE
		
		if [ "$CONTINUE" == "q" ]
		then
			break
		fi

		[ ! "$CONTINUE" = $'\n' ] && printf "\n"
		
		gcc -shared -fPIC "$PROJECT_PATH"/fake_malloc.c -o "$PROJECT_PATH"/fake_malloc.dylib -DINCL_LIB=$INCL_LIB -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$COUNTER

		if [[ $? != 0 ]]
		then
			continue
		fi
		
		GCC_CMD="gcc $SRC -rdynamic -o $PROJECT_PATH/malloc_debug$GCC_FLAGS"
		
		printf "$REDB%s$DEF\n" "$GCC_CMD"
		
		sh -c "$GCC_CMD 2>&1" 

		if [[ $? != 0 ]]
		then
			continue
		fi

		echo "${RED}DYLD_INSERT_LIBRARIES=$PROJECT_PATH/fake_malloc.dylib $PROJECT_PATH/malloc_debug$OUT_ARGS:$DEF"
		
		sh -c "DYLD_INSERT_LIBRARIES=$PROJECT_PATH/fake_malloc.dylib $PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	done

	rm -f "$PROJECT_PATH/fake_malloc.c"
	
	rm -f "$PROJECT_PATH/fake_malloc_destructor.c"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/fake_malloc.dylib"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/malloc_debug"

	printf "\nExiting\n"

}

function run()
{
	GCC_CMD="gcc $SRC -rdynamic -o $PROJECT_PATH/malloc_debug -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DINCL_LIB=$INCL_LIB -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX$GCC_FLAGS -ldl"
	
	printf "$REDB%s$DEF\n" "$GCC_CMD"
	
	sh -c "$GCC_CMD 2>&1" 

	if [[ $? != 0 ]]
	then
		rm -f "$PROJECT_PATH/fake_malloc.c"
		exit 1
	fi

	printf "${RED}%s/malloc_debug%s:$DEF\n" "$PROJECT_PATH" "$OUT_ARGS"
	
	sh -c "$PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	rm -f "$PROJECT_PATH/fake_malloc.c"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/malloc_debug"

}

function run_osx()
{
	gcc -shared -fPIC "$PROJECT_PATH"/fake_malloc.c -o "$PROJECT_PATH"/fake_malloc.dylib -DONLY_SOURCE=$ONLY_SOURCE -DINCL_LIB=$INCL_LIB -DADDR_ARR_SIZE=$ADDR_SIZE -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX

	if [[ $? != 0 ]]
	then
		rm -f "$PROJECT_PATH/fake_malloc.c"
		rm -f "$PROJECT_PATH/fake_malloc_destructor.c"
		exit 1
	fi

	GCC_CMD="gcc $SRC -rdynamic -o $PROJECT_PATH/malloc_debug$GCC_FLAGS"
	
	printf "$REDB%s$DEF\n" "$GCC_CMD"
	
	sh -c "$GCC_CMD 2>&1" 

	if [[ $? != 0 ]]
	then
		rm -f "$PROJECT_PATH/fake_malloc.c"
		rm -f "$PROJECT_PATH/fake_malloc_destructor.c"
		exit 1
	fi

	printf "${RED}DYLD_INSERT_LIBRARIES=%s/fake_malloc.dylib %s/malloc_debug%s:$DEF\n" "$PROJECT_PATH" "$PROJECT_PATH" "$OUT_ARGS"
	
	sh -c "DYLD_INSERT_LIBRARIES=$PROJECT_PATH/fake_malloc.dylib $PROJECT_PATH/malloc_debug$OUT_ARGS 2>&1"

	rm -f "$PROJECT_PATH/fake_malloc.c"
	
	rm -f "$PROJECT_PATH/fake_malloc_destructor.c"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/fake_malloc.dylib"

	[ -z "$PRESERVE" ] && rm -f "$PROJECT_PATH/malloc_debug"

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

	read -rn${#CONT} PATH_CHOICE

	printf "\n"

	{ [[ $PATH_CHOICE -lt 0 ]] || [[ $PATH_CHOICE -gt $((CONT - 1)) ]] || [[ ! ($PATH_CHOICE =~ $RE) ]]; } && echo "Index not in range" && exit 1

	for VAL in $PATH_ARR
	do
		[[ $CONT2 -eq $PATH_CHOICE ]] && PATH_CHOICE=$VAL && break
		(( CONT2 = CONT2 + 1 ))
	done

	[ ! -e "./malloc_wrapper.sh" ] && printf "Error: ./malloc_wrapper.sh not found\n" && exit 1

	[ ! -e "$PATH_CHOICE" ] && printf "Error: '$PATH_CHOICE' directory doesn't exists\n" && exit 1

	if [ -w "$PATH_CHOICE" ]
	then
		cp ./malloc_wrapper.sh "${PATH_CHOICE%/}"/malloc_wrapper
	else
		sudo cp ./malloc_wrapper.sh "${PATH_CHOICE%/}"/malloc_wrapper
	fi

	printf "Done!\n"

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

[[ $ARGS_LEN == 0 ]] && echo "$HELP_MSG" && exit 1

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
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a malloc_wrapper flag\n" && exit 1
			(( I = I + 1 ))
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				EXCLUDE_FIND+="! -path '*${ARGS[$I]}*' "
				(( I = I + 1 ))
			done
        ;;

		"-fo" | "--filter-out")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a malloc_wrapper flag\n" && exit 1
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
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a malloc_wrapper flag\n" && exit 1
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
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a malloc_wrapper flag\n" && exit 1
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
						echo "DIOPORCO"
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

        "-fl" | "--flags")
			check_flag "${ARGS[$I + 1]}" && printf "Error: ${ARGS[$I]} flag value '${ARGS[$I + 1]}' is a malloc_wrapper flag\n" && exit 1
			(( I = I + 1 ))
			while [[ $I -lt $ARGS_LEN ]]
			do
				check_flag "${ARGS[$I]}" && (( I = I - 1 )) && break
				GCC_FLAGS+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
		;;

		"-a" | "--args")
			check_flag "${ARGS[$I + 1]}" && printf "Error: %s flag value '%s' is a malloc_wrapper flag\n" "${ARGS[$I]}" "${ARGS[$I + 1]}" && exit 1
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

        "-h" | "--help")
			echo "$HELP_MSG"
            exit
        ;;

		"-nr" | "--no-report")
			NO_REPORT="// "
		;;

		"--add-path")
			add_to_path
			exit
		;;
    esac
    (( I = I + 1 ))
done

{ [ -z "$FILE_PATH" ] && [ -z "$PROJECT_PATH" ]; } && printf "Error: Missing path to project or file list.\n%s" "$HELP_MSG" && exit 1

{ [ -z "$FILE_PATH" ] && [ ! -d "$PROJECT_PATH" ]; } && echo "Error: $PROJECT_PATH is not a folder" && exit 1

if [[ "$OSTYPE" == "darwin"* ]]
then
	AS_COMM="//"
	AS_FUNC="fake_"
	AS_OG=""
	echo "extern void __attribute__((destructor)) malloc_hook_report();" > $PROJECT_PATH/fake_malloc_destructor.c
	[ -n "$FILE_PATH" ] && SRC+="$PROJECT_PATH/fake_malloc_destructor.c "
elif [ -n "$FILE_PATH" ]
then
	SRC+="$PROJECT_PATH/fake_malloc.c "
fi

eval "cat << EOF > $PROJECT_PATH/fake_malloc.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define RED \"\e[31m\"

#define REDB \"\e[1;31m\"

#define DEF \"\e[0m\"

typedef struct s_addr {
	void	*address;
	char	*function;
	int		bytes;
}	t_addr;

#ifdef __APPLE__
# define MAC_OS_SYSTEM 1
#define DYLD_INTERPOSE(_replacment,_replacee) \
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

${NO_REPORT}void __attribute__((destructor)) malloc_hook_report();

int	malloc_hook_check_content(unsigned char *str)
{
	while (*str && *str >= 0 && *str <= 128)
		str++;
	if (!*str)
		return (0);
	return (1);
}

void malloc_hook_report()
{
	int	tot_leaks;

	tot_leaks = 0;
	init_run = 1;
	printf(REDB \"(MALLOC_REPORT)\" DEF \"\n\tMalloc calls: \" RED \"%d\" DEF \"\n\tFree calls: \" RED \"%d\" DEF \"\n\tFree calls to 0x0: \" RED \"%d\" DEF \"\n\" REDB \"Leaks at exit:\n\" DEF, malloc_count, free_count, zero_free_count);
	if (addr_rep)
		addr_i = ADDR_ARR_SIZE - 1;
	for (int i = 0; i <= addr_i; i++)
	{
		if (addresses[i].address)
		{
			if (!malloc_hook_check_content((unsigned char *)addresses[i].address))
				printf(REDB \"%d)\" DEF \"\tFrom \" RED \"%s\" DEF \" of size \" RED \"%d\" DEF \" at address \"RED \"%p\" DEF \"	Content: \" RED \"\\\"%s\\\"\n\" DEF, ++tot_leaks, addresses[i].function, addresses[i].bytes, addresses[i].address, (char *)addresses[i].address);
			else
				printf(REDB \"%d)\" DEF \"\tFrom \" RED \"%s\" DEF \" of size \" RED \"%d\" DEF \" at address \"RED \"%p	Content unavailable\n\" DEF, ++tot_leaks, addresses[i].function, addresses[i].bytes, addresses[i].address);
			${AS_OG}free(addresses[i].function);
		}
	}
	printf(REDB \"Total leaks: %d\nWARNING:\" DEF \" the leaks freed by exit() are still displayed in the report\n\" DEF, tot_leaks);
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

void	malloc_hook_string_edit(char *str, int lib)
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
		if (INCL_LIB && lib)
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
		if (INCL_LIB && lib)
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
	malloc_hook_string_edit(stack[2], 0);
	malloc_hook_string_edit(stack[3], 1);
	if (stack[2][0] != '?' $EXCLUDE_RES $INCL_XMALL)
	{
		if (++malloc_fail == MALLOC_FAIL_INDEX || MALLOC_FAIL_INDEX == -1)
		{
			printf(REDB \"(MALLOC_FAIL)\t\" DEF \" %s -> %s malloc num %d failed\n\", stack[3], stack[2], malloc_fail);
			${AS_OG}free(stack);
			init_run = 0;
			return (0);
		}
		malloc_count++;
		ret = ${AS_OG}malloc(size);
		addr_i++;
		if (addr_i == ADDR_ARR_SIZE)
		{
			addr_rep = 1;
			addr_i = 0;
		}
		while (addr_i < ADDR_ARR_SIZE - 1 && addresses[addr_i].address)
			addr_i++;
		if (addr_i == ADDR_ARR_SIZE - 1)
		{
			printf(REDB \"(MALLOC_ERROR)\t\" DEF \" Not enough buffer space, default is 10000 specify a bigger one with the --leaks-buff flag\n\");
			${AS_OG}free(stack);
			exit (1);
		}
		addresses[addr_i].function = strdup(stack[2]);
		addresses[addr_i].bytes = size;
		addresses[addr_i].address = ret;
		printf(REDB \"(MALLOC_WRAPPER) \" DEF \"%s -> %s allocated %zu bytes at %p\n\", stack[3], stack[2], size, ret);
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
	malloc_hook_string_edit(stack[2], 0);
	malloc_hook_string_edit(stack[3], 1);
	if (stack[2][0] != '?' $EXCLUDE_RES $INCL_XMALL)
	{
		printf(REDB \"(FREE_WRAPPER)\t\" DEF \" %s -> %s free %p\n\", stack[3], stack[2], tofree);
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
				}
			}
		}
		else
			zero_free_count++;
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
		SRC+=$(eval "find $PROJECT_PATH -name '*.c' $EXCLUDE_FIND" | grep -v fake_malloc.c | tr '\n' ' ')
	else
		 SRC+=$(eval "find $PROJECT_PATH -name '*.c' $EXCLUDE_FIND" | tr '\n' ' ')
	fi
else
	SRC+="$FILE_PATH"
fi

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
