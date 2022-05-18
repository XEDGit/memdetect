#!/bin/zsh

ARGS=("$@")

ARGS_LEN=${#ARGS[@]}

RED="\e[31m"

DEF="\e[39m"

RE='^[0-9]+$'

GCC_FLAGS=""

OUT_ARGS=""

MALLOC_FAIL_INDEX=0

HELP_MSG="Usage: ./malloc_wrapper project_path --f filename || --d directory_path [[--h] [--fail malloc_to_fail_index] [--e folder_to_exclude_name] [--flags flag0 [flag...]] [--a arg0 [arg...]] ]\n"

I=1

# if [ $ARGS_LEN -lt 2 ]
# then
# 	printf "$HELP_MSG"
#     exit 1
# fi

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
				if [[ ${ARGS[$I]} = "--"* ]]
				then
					(( I = I - 1 ))
					break
				fi
				FILE_PATH+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
			PROJECT_PATH='.'
		;;
        "--e")
			EXCLUDE+="! -path '*${ARGS[$I + 1]}*' "
        ;;

		"--fail")
			NEW_VAL=${ARGS[$I + 1]}
			if ! [[ $NEW_VAL =~ $RE ]]
			then
				if [ $NEW_VAL = "all" ]
				then
					MALLOC_FAIL_LOOP=1
				else
					printf "Error: $arg argument is not a number."
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
				if [[ ${ARGS[$I]} = "--"* ]]
				then
					(( I = I - 1 ))
					break
				fi
				GCC_FLAGS+=" ${ARGS[$I]}"
				(( I = I + 1 ))
			done
		;;

		"--a")
			(( I = I + 1 ))
			while [[ $I -le $ARGS_LEN ]]
			do
				if [[ ${ARGS[$I]} = "--"* ]]
				then
					(( I = I - 1 ))
					break
				fi
				OUT_ARGS+=("${ARGS[$I]}")
				(( I = I + 1 ))
			done
		;;

        "--h")
			printf "$HELP_MSG"
            exit
        ;;
    esac
    (( I = I + 1 ))
done

if [ -z $FILE_PATH] && [ -z $PROJECT_PATH ]
then
	printf "Error: Missing --d or --f option.\n$HELP_MSG"
	exit 1
fi

if  [ -z $FILE_PATH] && ! [ -d $PROJECT_PATH ]
then
	echo "Error: project_path is not a folder\n"
	exit
fi

eval "cat << EOF > $PROJECT_PATH/fake_malloc.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <stdio.h>
#include <string.h>

#define RED \"\e[31m\"

#define DEF \"\e[39m\"

typedef struct s_addr {
	void	*address;
	char	*function;
	int		bytes;
}	t_addr;

static void		(*og_free)(void *);
static void		*(*og_malloc)(size_t);
static int 		free_count = 0;
static int		malloc_count = 0;
static int		addr_i = 0;
static t_addr	addresses[10000] = {0};

void __attribute__((destructor)) malloc_hook_report();

void malloc_hook_report()
{
	printf(RED \"(MALLOC_REPORT)\nmalloc calls: %d - free calls: %d\nLeaks:\n\" DEF, malloc_count, free_count);
	for (int i = 0; i < addr_i; i++)
	{
		if (addresses[i].address)
		{
			printf(\"Leak from %s of size %d at address %p\n\", addresses[i].function, addresses[i].bytes, addresses[i].address)
			og_free(addresses[i].function);
		}
	}
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
	str = &str[59];
	while (*str && *str != ' ')
		str++;
	*str = 0;
}

void	*malloc(size_t size)
{
	void		*ret;
	char		**stack;
	int			stack_size;
	static int	malloc_fail = 0;

	if (!og_malloc)
		if (!(og_malloc = dlsym(RTLD_NEXT, \"malloc\")))
			return (0);
	if (!og_free)
		if (!(og_free = dlsym(RTLD_NEXT, \"free\")))
			return (0);
	stack_size = malloc_hook_backtrace_readable(&stack);
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	malloc_count++;
	if (++malloc_fail == MALLOC_FAIL_INDEX)
	{
		printf(RED \"(MALLOC_FAIL) %s - %s malloc num %d failed\n\" DEF, &stack[3][59], &stack[2][59], malloc_fail);
		malloc_fail = 0;
		og_free(stack);
		return (0);
	}
	ret = og_malloc(size);
	if (addr_i == 10000)
		addr_i = 0;
	addresses[addr_i].function = strdup(&stack[2][59]);
	addresses[addr_i].bytes = size;
	addresses[addr_i].address = ret;
	addr_i++;
	printf(RED \"(MALLOC_WRAPPER) %s - %s allocated %zu bytes at %p\n\" DEF, &stack[3][59], &stack[2][59], size, ret);
	og_free(stack);
	return (ret);
}

void	free(void *tofree)
{
	char	**stack;
	void	(*og_free)(void *);

	if (!og_free)
		if (!(og_free = dlsym(RTLD_NEXT, \"free\")))
			return ;
	free_count++;
	malloc_hook_backtrace_readable(&stack);
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	printf(RED \"(FREE_WRAPPER) %s/%s free %p\n\" DEF, \
	&stack[3][59], &stack[2][59], tofree);
	if (addr_i == 10000)
		addr_i = 0;
	for (int i=0; i < addr_i; i++)
	{
		if (addresses[i].address == tofree)
		{
			og_free(addresses[i].function);
			addresses[i].function = 0;
			addresses[i].bytes = 0;
			addresses[i].address = 0;
		}
	}
	og_free(stack);
	og_free(tofree);
}

EOF"

if [ -z $FILE_PATH ]
then
	SRC=$(eval "find $PROJECT_PATH -name '*.c' $EXCLUDE" | tr '\n' ' ')
else
	SRC="$PROJECT_PATH/fake_malloc.c$FILE_PATH"
fi

if [ -z $MALLOC_FAIL_LOOP ]
then
	GCC_CMD="gcc $SRC -rdynamic -o malloc_debug -DMALLOC_FAIL_INDEX=$MALLOC_FAIL_INDEX$GCC_FLAGS"
	echo $RED$GCC_CMD$DEF
	eval $GCC_CMD
	if [[ $? == 0 ]]
	then
		rm "$PROJECT_PATH/fake_malloc.c"
	    printf "$RED" "Success$DEF\n"
	else
		rm "$PROJECT_PATH/fake_malloc.c"
	    exit
	fi
	printf "$RED./malloc_debug$OUT_ARGS:$DEF\n"
	./malloc_debug $OUT_ARGS
else
	COUNTER=0
	CONTINUE="\n"
	while [[ $COUNTER -ge 0 ]]
	do
		(( COUNTER = COUNTER + 1 ))
		printf "Press any key to run with --fail $COUNTER or 'q' to quit: "
		read -k1 CONTINUE
		if [ $CONTINUE = "q" ]
		then
			rm "$PROJECT_PATH/fake_malloc.c"
			printf "\nExiting\n"
			exit 0
		fi
		GCC_CMD="gcc $SRC -rdynamic -o malloc_debug -DMALLOC_FAIL_INDEX=$COUNTER$GCC_FLAGS"
		echo $RED$GCC_CMD$DEF
		eval $GCC_CMD
		if [[ $? == 0 ]]
		then
		    printf "$RED" "Success$DEF\n"
		else
			rm "$PROJECT_PATH/fake_malloc.c"
		    exit
		fi
		printf "$RED./malloc_debug$OUT_ARGS:$DEF\n"
		./malloc_debug $OUT_ARGS
	done
fi
