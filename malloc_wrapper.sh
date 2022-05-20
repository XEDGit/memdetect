#!/bin/bash

ARGS=("$@")

ARGS_LEN=${#ARGS[@]}

RED="\e[31m"

REDB="\e[1;31m"

DEF="\e[0m"

RE='^[0-9]+$'

GCC_FLAGS=""

OUT_ARGS=""

ADDR_SIZE=10000

EXCLUDE_RES="xxxx"

ONLY_SOURCE=1

MALLOC_FAIL_INDEX=0

HELP_MSG="Usage: ./malloc_wrapper project_path --f filename || --d directory_path [[--h] [--fail malloc_to_fail_index] [--e folder_to_exclude_name] [--flags flag0 [flag...]] [--a arg0 [arg...]] ]\n"

I=0

function add_to_path()
{

	PATH_ARR=$(echo $PATH | tr ':' '\n')

	CONT=0

	CONT2=0

	echo "In which path do you want to install it?"

	for VAL in $PATH_ARR
	do
		printf "\t$CONT) $VAL\n"
		(( CONT = CONT + 1 ))
	done

	printf "Select index: "

	read -n${#CONT} PATH_CHOICE

	printf "\n"

	([[ $PATH_CHOICE -lt 0 ]] || [[ $PATH_CHOICE -gt $(($CONT - 1)) ]] || [[ ! ($PATH_CHOICE =~ $RE) ]]) && echo "Index not in range" && exit 1

	for VAL in $PATH_ARR
	do
		[[ $CONT2 -eq $PATH_CHOICE ]] && PATH_CHOICE=$VAL && break
		(( CONT2 = CONT2 + 1 ))
	done

	[ ! -e "./malloc_wrapper.sh" ] && printf "Error: ./malloc_wrapper.sh not found\n" && exit 1

	[ ! -e $PATH_CHOICE ] && printf "Error: '$PATH_CHOICE' directory doesn't exists\n" && exit 1

	[ -w $PATH_CHOICE ] && cp ./malloc_wrapper.sh ${PATH_CHOICE%/}/malloc_wrapper || sudo cp ./malloc_wrapper.sh ${PATH_CHOICE%/}/malloc_wrapper

	printf "Done!\n"

}

printf "$REDB============== malloc_wrapper by: ===============
 __    __ ________ _______   ______  __   __     
|  \\  |  |        |       \\ /      \\|  \\ |  \\    
| \$\$  | \$| \$\$\$\$\$\$\$| \$\$\$\$\$\$\$|   \$\$\$\$\$\$\\\\\$\$_| \$\$_   
 \\\$\$\\/  \$| \$\$__   | \$\$  | \$| \$\$ __\\\$|  |   \$\$ \\  
  >\$\$  \$\$| \$\$  \\  | \$\$  | \$| \$\$|    | \$\$\\\$\$\$\$\$\$  
 /  \$\$\$\$\\| \$\$\$\$\$  | \$\$  | \$| \$\$ \\\$\$\$| \$\$ | \$\$ __ 
|  \$\$ \\\$\$| \$\$_____| \$\$__/ \$| \$\$__| \$| \$\$ | \$\$|  \\
| \$\$  | \$| \$\$     | \$\$    \$\$\\\$\$    \$| \$\$  \\\$\$  \$\$
 \\\$\$   \\\$\$\\\$\$\$\$\$\$\$\$\\\$\$\$\$\$\$\$  \\\$\$\$\$\$\$ \\\$\$   \\\$\$\$\$
 ================================================
 $DEF"

while [[ $I -le $ARGS_LEN ]]
do
    arg=${ARGS[$I]}
	case $arg in

		"--d")
			PROJECT_PATH=${ARGS[$I + 1]%/}
		;;
		
		"--f")
			(( I = I + 1 ))
			while [[ $I -le $ARGS_LEN ]]
			do
				[[ ${ARGS[$I]} = "--"* ]] && (( I = I - 1 )) && break
				[ ! -e "${ARGS[$I]}" ] && printf "Error: ${ARGS[$I]} not found\n" && exit 1
				FILE_PATH+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
			PROJECT_PATH='.'
		;;
        "--e")
			EXCLUDE+="! -path '*${ARGS[$I + 1]}*' "
        ;;

		"--filter")
			EXCLUDE_RES=${ARGS[$I + 1]}
		;;

		"--include-ext")
			ONLY_SOURCE=0
		;;

		"--fail")
			NEW_VAL=${ARGS[$I + 1]}
			if ! [[ $NEW_VAL =~ $RE ]]
			then
				if [ "$NEW_VAL" = "loop" ]
				then
					MALLOC_FAIL_LOOP=1
				elif [ "$NEW_VAL" = "all" ]
				then
					MALLOC_FAIL_INDEX=-1
				else
					printf "Error: the value of --fail '$arg' is not a number, 'all' or 'loop'."
					exit 1
				fi
			else
				MALLOC_FAIL_INDEX=$NEW_VAL
			fi
		;;

        "--flags")
			(( I = I + 1 ))
			while [[ $I -le $ARGS_LEN ]]
			do
				[[ ${ARGS[$I]} = "--"* ]] && (( I = I - 1 )) && break
				GCC_FLAGS+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
		;;

		"--a")
			(( I = I + 1 ))
			while [[ $I -le $ARGS_LEN ]]
			do
				[[ ${ARGS[$I]} = "--"* ]] && (( I = I - 1 )) && break
				OUT_ARGS+=("${ARGS[$I]}")
				(( I = I + 1 ))
			done
		;;

		"--leaks-buff")
			! [[ $NEW_VAL =~ $RE ]] && printf "Error: the value of --leaks-buff '$arg' is not a number" && exit 1
			ADDR_SIZE=$NEW_VAL
		;;

        "--h")
			printf "$HELP_MSG"
            exit
        ;;

		"--add-path")
			add_to_path
			exit
		;;
    esac
    (( I = I + 1 ))
done

[ -z $FILE_PATH ] && [ -z $PROJECT_PATH ]  && printf "Error: Missing --d or --f option.\n$HELP_MSG" && exit 1

[ -z $FILE_PATH ] && [ ! -d $PROJECT_PATH ] && echo "Error: $PROJECT_PATH is not a folder\n" && exit 1

eval "cat << EOF > $PROJECT_PATH/fake_malloc.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef __APPLE__
# define MAC_OS_SYSTEM 1
#else
# define MAC_OS_SYSTEM 0
#endif

#define RED \"\e[31m\"

#define REDB \"\e[1;31m\"

#define DEF \"\e[0m\"

typedef struct s_addr {
	void	*address;
	char	*function;
	int		bytes;
}	t_addr;

static void		(*og_free)(void *);
static void		*(*og_malloc)(size_t);
static int 		free_count = 0;
static int		init_run = 0;
static int 		zero_free_count = 0;
static int		malloc_count = 0;
static int		addr_i = 0;
static int		addr_rep = 0;
static t_addr	addresses[ADDR_ARR_SIZE] = {0};

void __attribute__((destructor)) malloc_hook_report();

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
			printf(REDB \"%d)\" DEF \"\tFrom \" RED \"%s\" DEF \" of size \" RED \"%d\" DEF \" at address \"RED \"%p\n\" DEF, ++tot_leaks, addresses[i].function, addresses[i].bytes, addresses[i].address);
			og_free(addresses[i].function);
		}
	}
	printf(REDB \"Total leaks: %d\n\" DEF, tot_leaks);
}

int init_malloc_hook()
{
	og_malloc = dlsym(RTLD_NEXT, \"malloc\");
    og_free = dlsym(RTLD_NEXT, \"free\");

    if (!og_malloc || !og_free)
        exit(1);
	return (0);
}

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
		ch = '+';
		while (*str && *(str - 1) != '(')
			str++;
	}
	else
		str = &str[59];
	while (*str && *str != ch)
		*start++ = *str++;
	if (start == temp)
	{
		*start++ = '?';
		*start++ = '?';
	}
	*start = 0;
}

void	*malloc(size_t size)
{
	void		*ret;
	char		**stack;
	int			stack_size;
	static int	malloc_fail = 0;

	if (!og_malloc)
		if (init_malloc_hook())
			exit (1);
	if (init_run)
		return (og_malloc(size));
	init_run = 1;
	stack_size = malloc_hook_backtrace_readable(&stack);
	if (!MAC_OS_SYSTEM && ONLY_SOURCE && stack[2][0] != '.')
	{
		og_free(stack);
		init_run = 0;
		return (og_malloc(size));
	}
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	if (stack[2][0] != '?' && !strstr(stack[2], EXCLUDE_RES) && !strstr(stack[3], EXCLUDE_RES))
	{
		if (++malloc_fail == MALLOC_FAIL_INDEX || MALLOC_FAIL_INDEX == -1)
		{
			printf(REDB \"(MALLOC_FAIL)\" DEF \" %s - %s malloc num %d failed\n\", stack[3], stack[2], malloc_fail);
			og_free(stack);
			init_run = 0;
			return (0);
		}
		malloc_count++;
		ret = og_malloc(size);
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
			printf(REDB \"(MALLOC_ERROR)\" DEF \" Not enough buffer space, default is 10000 specify a bigger one with the --leaks-buff flag\n\");
			og_free(stack);
			exit (1);
		}
		addresses[addr_i].function = strdup(stack[2]);
		addresses[addr_i].bytes = size;
		addresses[addr_i].address = ret;
		printf(REDB \"(MALLOC_WRAPPER)\" DEF \" %s - %s allocated %zu bytes at %p\n\", stack[3], stack[2], size, ret);
	}
	else
		ret = og_malloc(size);
	init_run = 0;
	og_free(stack);
	return (ret);
}

void	free(void *tofree)
{
	char	**stack;

	if (!og_free)
		exit(1);
	if (init_run)
	{
		og_free(tofree);
		return ;
	}
	init_run = 1;
	malloc_hook_backtrace_readable(&stack);
	if (!MAC_OS_SYSTEM && ONLY_SOURCE && stack[2][0] != '.')
	{
		og_free(stack);
		init_run = 0;
		return ;
	}
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	if (stack[2][0] != '?' && !strstr(stack[2], EXCLUDE_RES) && !strstr(stack[3], EXCLUDE_RES))
	{
		printf(REDB \"(FREE_WRAPPER)\" DEF \" %s - %s free %p\n\", stack[3], stack[2], tofree);
		if (tofree)
		{
			free_count++;
			for (int i=0; i <= addr_i; i++)
			{
				if (addresses[i].address == tofree)
				{
					og_free(addresses[i].function);
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
	og_free(stack);
	og_free(tofree);
}

EOF"

[ -z $FILE_PATH ] && SRC=$(eval "find $PROJECT_PATH -name '*.c' $EXCLUDE" | tr '\n' ' ') || SRC="$PROJECT_PATH/fake_malloc.c$FILE_PATH"

if [ -z $MALLOC_FAIL_LOOP ]
then
	
	GCC_CMD="gcc $SRC -rdynamic -o malloc_debug -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DEXCLUDE_RES='\"$EXCLUDE_RES\"' -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX$GCC_FLAGS"
	
	printf "$REDB$GCC_CMD$DEF\n"
	
	sh -c "$GCC_CMD 2>&1" 

	if [[ $? != 0 ]]
	then
		rm "$PROJECT_PATH/fake_malloc.c"
		exit 1
	fi

	printf "$RED./malloc_debug$OUT_ARGS:$DEF\n"
	
	sh -c "./malloc_debug $OUT_ARGS 2>&1"

	rm "$PROJECT_PATH/fake_malloc.c"

else
	
	COUNTER=0
	
	CONTINUE=""
	
	while [[ $COUNTER -ge 0 ]]
	do
		
		(( COUNTER = COUNTER + 1 ))
		
		printf "\e[1mPress any key to run with --fail $COUNTER or 'q' to quit: $DEF"
		
		read -rn1 CONTINUE
		
		[ "$CONTINUE" == "q" ] && rm "$PROJECT_PATH/fake_malloc.c" && printf "\nExiting\n" && exit 0

		[ ! $CONTINUE = $'\n' ] && printf "\n"
		
		GCC_CMD="gcc $SRC -rdynamic -o malloc_debug -DONLY_SOURCE=$ONLY_SOURCE -DADDR_ARR_SIZE=$ADDR_SIZE -DEXCLUDE_RES='\"$EXCLUDE_RES\"' -DMALLOC_FAIL_INDEX=$COUNTER$GCC_FLAGS"
		
		printf "$REDB$GCC_CMD$DEF\n"
		
		sh -c "$GCC_CMD 2>&1"

		if [[ $? != 0 ]]
		then
			continue
		fi
		
		printf "$REDB./malloc_debug$OUT_ARGS:$DEF\n"
		
		sh -c "./malloc_debug $OUT_ARGS 2>&1"

	done

	rm "$PROJECT_PATH/fake_malloc.c"

fi
exit 0